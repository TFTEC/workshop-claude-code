#requires -Version 7.0
<#
Testes da fonte Azure do relatório FinOps, sem Azure nenhum.

O script roda pelo ponto de entrada público, com -Fonte Azure, e o az que ele encontra no PATH
é o az falso (testes/az-falso/az.ps1), que devolve respostas enlatadas e registra cada chamada
num log. Os testes conferem o que sai do script (achados.json e as mensagens de erro) e o que ele
pediu ao az, que é a fronteira com o Azure: só comandos de leitura, com escopo na subscription.

Como o az falso entra: no BeforeAll, o teste gera numa pasta temporária um lançador chamado
az.cmd (Windows) ou az (macOS e Linux), que chama az-falso/az.ps1 com o pwsh, e põe só essa pasta
na frente do PATH durante cada execução. Antes de rodar, confere que o az do PATH é o falso; se
não for, aborta, para nunca falar com o Azure real.

Rodar: pwsh -NoProfile -Command "Invoke-Pester -Path testes/relatorio.azure.Tests.ps1 -Output Detailed"
#>

Describe 'Relatório FinOps com a fonte Azure (az falso)' {

    BeforeAll {
        # Os caminhos padrão ($script:Relatorio, $script:Dados, $script:Sub) e os ajudantes comuns,
        # como Get-Achados e Invoke-Relatorio (a fonte Arquivo, para comparar com a fonte Azure).
        . (Join-Path $PSScriptRoot 'Comum.ps1')
        $script:AzFalso = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'az-falso/az.ps1'))
        $script:Paginado = Join-Path $PSScriptRoot 'az-falso/paginado'
        $script:Truncado = Join-Path $PSScriptRoot 'az-falso/truncado'
        $script:ComandosDeLeitura = 'account show', 'extension show', 'graph query'
        # A única exceção: a consulta de custo do bônus (-CustoReal), um POST de leitura.
        $script:ConsultaDeCusto = '^https://management\.azure\.com/subscriptions/[^/]+/providers/Microsoft\.CostManagement/query\?api-version=[\w.-]+$'

        # O lançador do az falso, sozinho numa pasta, para ir na frente do PATH.
        $script:PastaDoAz = Join-Path $TestDrive 'az-no-path'
        New-Item -ItemType Directory -Path $script:PastaDoAz | Out-Null
        if ($IsWindows) {
            Set-Content -Path (Join-Path $script:PastaDoAz 'az.cmd') -Encoding ascii `
                -Value "@pwsh -NoProfile -NonInteractive -File ""$script:AzFalso"" %*"
        } else {
            $lancador = Join-Path $script:PastaDoAz 'az'
            Set-Content -Path $lancador -Encoding ascii `
                -Value "#!/bin/sh`nexec pwsh -NoProfile -NonInteractive -File '$script:AzFalso' `"`$@`""
            chmod +x $lancador
        }
        # Uma pasta vazia, para o caso de quem não tem o Azure CLI.
        $script:PastaSemAz = Join-Path $TestDrive 'path-sem-az'
        New-Item -ItemType Directory -Path $script:PastaSemAz | Out-Null

        $script:PathOriginal = $env:PATH
        $script:VariaveisOriginais = @{}
        foreach ($nome in 'AZ_FALSO_LOG', 'AZ_FALSO_DADOS', 'AZ_FALSO_CENARIO') {
            $script:VariaveisOriginais[$nome] = [Environment]::GetEnvironmentVariable($nome)
        }

        # Roda o relatório com -Fonte Azure e o az falso no PATH e devolve o que ele escreveu na tela
        # (o resumo e os avisos). Guarda o log das chamadas em $script:UltimoLog e, em toda execução,
        # confere que o script só chamou comandos de leitura.
        # Os preços vêm da tabela fictícia (-TabelaDePrecos), para não chamar a Retail Prices API;
        # com -TabelaDePrecos '', o script chama a API, e o teste precisa de um Mock de Invoke-RestMethod.
        function Invoke-RelatorioAzure {
            param(
                [string]$Saida,
                [string]$Dados = $script:Paginado,
                [string]$Cenario = 'normal',
                [string]$SubscriptionId = $script:Sub,
                [switch]$SemAzureCli,
                [string]$TabelaDePrecos = (Join-Path $script:Dados 'precos.json')
            )
            $precos = if ($TabelaDePrecos) { @{ TabelaDePrecos = $TabelaDePrecos } } else { @{} }
            $script:UltimoLog = Join-Path $TestDrive "az-$([guid]::NewGuid()).log"
            $env:AZ_FALSO_LOG = $script:UltimoLog
            $env:AZ_FALSO_DADOS = $Dados
            $env:AZ_FALSO_CENARIO = $Cenario
            $env:PATH = if ($SemAzureCli) { $script:PastaSemAz } else { "$script:PastaDoAz$([System.IO.Path]::PathSeparator)$script:PathOriginal" }
            try {
                if (-not $SemAzureCli) {
                    $az = (Get-Command az -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
                    if ($az -notlike "$script:PastaDoAz*") { throw "O az do PATH não é o falso ($az). Teste abortado para não falar com o Azure real." }
                }
                & $script:Relatorio -SubscriptionId $SubscriptionId -Fonte Azure -Saida $Saida @precos 6>&1 3>&1 | Out-String
            } finally {
                $env:PATH = $script:PathOriginal
                $fora = @(Get-ChamadasAoAz | Where-Object { -not (Test-ChamadaDeLeitura $_) })
                if ($fora) { throw "O relatório chamou comando fora da lista de leitura: az $($fora[0] -join ' ')" }
            }
        }

        # Uma chamada ao az que o relatório pode fazer: um dos comandos de leitura ou, só no custo
        # real, o POST da consulta de custo do Cost Management. Nenhum outro az rest passa.
        function Test-ChamadaDeLeitura {
            param([string[]]$Chamada)
            if ($script:ComandosDeLeitura -contains (($Chamada | Select-Object -First 2) -join ' ')) { return $true }
            $Chamada[0] -eq 'rest' -and (Get-Argumento $Chamada '--method') -eq 'post' -and (Get-Argumento $Chamada '--url') -match $script:ConsultaDeCusto
        }

        # As chamadas que o az falso recebeu na última execução; cada uma é a lista de argumentos.
        function Get-ChamadasAoAz {
            if (-not (Test-Path -LiteralPath $script:UltimoLog)) { return }
            foreach ($linha in Get-Content -LiteralPath $script:UltimoLog -Encoding utf8) {
                , @(($linha | ConvertFrom-Json).args)
            }
        }

        function Get-ConsultasAoGraph {
            @(Get-ChamadasAoAz) | Where-Object { $_[0] -eq 'graph' -and $_[1] -eq 'query' }
        }

        # O valor que vem depois de um parâmetro numa chamada ao az.
        function Get-Argumento {
            param([string[]]$Chamada, [string]$Nome)
            $i = [array]::IndexOf($Chamada, $Nome)
            if ($i -ge 0 -and $i + 1 -lt $Chamada.Count) { $Chamada[$i + 1] } else { $null }
        }
    }

    AfterAll {
        $env:PATH = $script:PathOriginal
        foreach ($nome in $script:VariaveisOriginais.Keys) {
            [Environment]::SetEnvironmentVariable($nome, $script:VariaveisOriginais[$nome])
        }
    }

    Context 'FIN-01 com a resposta em duas páginas (skip token na primeira)' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-paginada'
            Invoke-RelatorioAzure -Saida $saida
            $achados = Get-Achados $saida
            $consultas = @(Get-ConsultasAoGraph)
        }

        It 'junta as linhas das duas páginas: um achado para cada disco solto' {
            # O catálogo tem outras regras; este cenário verifica a paginação de FIN-01.
            $doFin01 = @($achados | Where-Object Regra -eq 'FIN-01')
            $doFin01 | Should -HaveCount 3
            ($doFin01.Recurso | Sort-Object) | Should -Be @('disco-copia-antiga-do-banco', 'disco-esquecido-vm-teste', 'disco-sobra-da-migracao')
        }

        It 'grava o mesmo achados.json que a fonte Arquivo grava com os mesmos dados' {
            # As duas páginas juntas têm as mesmas linhas de testes/dados/FIN-01.json.
            $saidaArquivo = Join-Path $TestDrive 'saida-arquivo'
            Invoke-Relatorio -Saida $saidaArquivo | Out-Null

            $doAzure = Get-Content -Raw -Path (Join-Path $saida 'achados.json')
            $doArquivo = Get-Content -Raw -Path (Join-Path $saidaArquivo 'achados.json')
            $doAzure | Should -BeExactly $doArquivo
        }

        It 'consulta só a subscription-alvo, pede 1.000 linhas por página em JSON e busca a segunda página com o skip token' {
            # Toda consulta, de qualquer regra, fica na subscription-alvo.
            foreach ($consulta in $consultas) {
                Get-Argumento $consulta '--subscriptions' | Should -Be $script:Sub
                Get-Argumento $consulta '--first' | Should -Be '1000'
                Get-Argumento $consulta '-o' | Should -Be 'json'
            }
            # A paginação é a de FIN-01: a primeira página sem skip token e a segunda com ele.
            $doFin01 = @($consultas | Where-Object { (Get-Argumento $_ '-q') -match "=~ 'Unattached'" })
            $doFin01 | Should -HaveCount 2
            $doFin01[0] | Should -Not -Contain '--skip-token'
            Get-Argumento $doFin01[1] '--skip-token' | Should -Be 'pagina-2'
        }

        It 'só chama comandos de leitura do az: account show, extension show, graph query e, no custo real, o POST da consulta de custo' {
            $chamadas = @(Get-ChamadasAoAz)
            $chamadas | Should -Not -BeNullOrEmpty
            foreach ($chamada in $chamadas) {
                Test-ChamadaDeLeitura $chamada | Should -BeTrue -Because "az $($chamada -join ' ') não é leitura"
            }
        }
    }

    Context 'Preços com a fonte Azure: a Retail Prices API, com um Mock de Invoke-RestMethod' {
        BeforeAll {
            # Uma Retail Prices API falsa, sem rede: devolve os itens de testes/dados/precos.json que
            # batem com o $filter, um item por página, e o NextPageLink da página seguinte.
            # O estado dela fica numa variável global porque o corpo do Mock roda no escopo do script
            # do relatório, onde o $script: é o do relatório, e não o deste teste.
            # Recusas: quantos pedidos ela recusa com 429 (Too Many Requests) antes de responder;
            # RetryAfter: os segundos do cabeçalho Retry-After da recusa, ou $null para não mandar.
            $global:ApiDePrecosFalsa = @{ Itens = @(); Pedidos = (New-Object System.Collections.Generic.List[string]); Recusas = 0; RetryAfter = $null }
            Mock Invoke-RestMethod {
                $endereco = $Uri.OriginalString
                $global:ApiDePrecosFalsa.Pedidos.Add("$Method $endereco")
                if ($endereco -notlike 'https://prices.azure.com/api/retail/prices?*') { throw "API falsa: endereço inesperado: $endereco" }
                if ($global:ApiDePrecosFalsa.Recusas -gt 0) {
                    $global:ApiDePrecosFalsa.Recusas--
                    # O erro que o Invoke-RestMethod do PowerShell 7 lança com a resposta 429.
                    $resposta = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]429)
                    if ($null -ne $global:ApiDePrecosFalsa.RetryAfter) {
                        $resposta.Headers.RetryAfter = [System.Net.Http.Headers.RetryConditionHeaderValue]::new([timespan]::FromSeconds($global:ApiDePrecosFalsa.RetryAfter))
                    }
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Response status code does not indicate success: 429 (Too Many Requests).', $resposta)
                }
                $parametros = @{}
                foreach ($par in $endereco.Split('?', 2)[1].Split('&')) {
                    $nomeEValor = $par.Split('=', 2)
                    $parametros[[uri]::UnescapeDataString($nomeEValor[0])] = [uri]::UnescapeDataString($nomeEValor[1])
                }
                $itens = @($global:ApiDePrecosFalsa.Itens)
                foreach ($condicao in $parametros['$filter'] -split ' and ') {
                    if ($condicao -notmatch "^(\w+) eq '(.*)'$") { throw "API falsa: filtro que ela não entende: $condicao" }
                    $campo = if ($Matches[1] -eq 'priceType') { 'type' } else { $Matches[1] }
                    $valor = $Matches[2].Replace("''", "'")
                    $itens = @($itens | Where-Object { [string]$_.$campo -ceq $valor })
                }
                $pulo = if ($parametros['$skip']) { [int]$parametros['$skip'] } else { 0 }
                $proxima = if ($pulo + 1 -lt $itens.Count) { ($endereco -replace '&\$skip=\d+$', '') + "&`$skip=$($pulo + 1)" } else { $null }
                [pscustomobject]@{ BillingCurrency = 'BRL'; Items = @($itens | Select-Object -Skip $pulo -First 1); NextPageLink = $proxima }
            }

            # Os pedidos de preço de um medidor (sem contar as páginas seguintes).
            function Get-PedidosDoMedidor {
                param([string]$MeterName, [string]$Regiao)
                @($global:ApiDePrecosFalsa.Pedidos | Where-Object {
                        $filtro = [uri]::UnescapeDataString($_)
                        $filtro -like "*meterName eq '$MeterName'*" -and $filtro -like "*armRegionName eq '$Regiao'*" -and $filtro -notlike '*$skip=*'
                    })
            }

            # A espera antes de uma nova tentativa não dorme de verdade: o teste só confere quanto
            # o relatório pediu para esperar.
            Mock Start-Sleep { }
        }

        BeforeEach {
            $global:ApiDePrecosFalsa.Itens = @((Get-Content -Raw -Path (Join-Path $script:Dados 'precos.json') | ConvertFrom-Json).Items)
            $global:ApiDePrecosFalsa.Pedidos.Clear()
            $global:ApiDePrecosFalsa.Recusas = 0
            $global:ApiDePrecosFalsa.RetryAfter = $null
        }

        AfterAll {
            Remove-Variable -Name ApiDePrecosFalsa -Scope Global -ErrorAction SilentlyContinue
        }

        It 'sem -TabelaDePrecos, pede os preços à Retail Prices API, só com GET e em reais, e chega na mesma economia da tabela fictícia' {
            $saida = Join-Path $TestDrive 'saida-precos-da-api'
            Invoke-RelatorioAzure -Saida $saida -TabelaDePrecos ''
            $saidaArquivo = Join-Path $TestDrive 'saida-precos-do-arquivo'
            Invoke-Relatorio -Saida $saidaArquivo | Out-Null

            $global:ApiDePrecosFalsa.Pedidos | Should -Not -BeNullOrEmpty
            foreach ($pedido in $global:ApiDePrecosFalsa.Pedidos) {
                $pedido | Should -BeLike "GET https://prices.azure.com/api/retail/prices?currencyCode='BRL'&*"
                [uri]::UnescapeDataString($pedido) | Should -BeLike "*priceType eq 'Consumption'*"
            }
            Get-Content -Raw -Path (Join-Path $saida 'achados.json') | Should -BeExactly (Get-Content -Raw -Path (Join-Path $saidaArquivo 'achados.json'))
        }

        It 'junta as páginas do NextPageLink: um segundo preço do medidor, na página 2, deixa o disco com "não sei"' {
            $segundo = ($global:ApiDePrecosFalsa.Itens | Where-Object { $_.meterName -eq 'P15 LRS Disk' -and $_.productName -eq 'Premium SSD Managed Disks' }) | ConvertTo-Json | ConvertFrom-Json
            $segundo.retailPrice = 999.0
            $global:ApiDePrecosFalsa.Itens += $segundo
            $saida = Join-Path $TestDrive 'saida-precos-em-duas-paginas'

            Invoke-RelatorioAzure -Saida $saida -TabelaDePrecos ''

            @(Get-PedidosDoMedidor 'P15 LRS Disk' 'brazilsouth') | Should -HaveCount 1
            @($global:ApiDePrecosFalsa.Pedidos | Where-Object { $_ -like '*$skip=1' }) | Should -Not -BeNullOrEmpty
            (Get-Achados $saida | Where-Object Recurso -eq 'disco-sobra-da-migracao').EconomiaStatus | Should -Be 'nao-sei'
        }

        It 'pede cada medidor uma vez só por execução, mesmo com vários achados do mesmo medidor' {
            # Uma cópia das respostas enlatadas com um terceiro IP, do mesmo medidor do primeiro.
            $dados = Join-Path $TestDrive 'paginado-com-ip-repetido'
            New-Item -ItemType Directory -Path $dados | Out-Null
            Copy-Item -Path (Join-Path $script:Paginado '*.json') -Destination $dados
            $resposta = Get-Content -Raw -Path (Join-Path $dados 'FIN-02.json') | ConvertFrom-Json
            $repetido = $resposta.data[0] | ConvertTo-Json | ConvertFrom-Json
            $repetido.name = 'ip-ficticio-mais-um'
            $resposta.data += $repetido
            $resposta.count = 3; $resposta.total_records = 3
            $resposta | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $dados 'FIN-02.json') -Encoding utf8
            $saida = Join-Path $TestDrive 'saida-ip-repetido'

            Invoke-RelatorioAzure -Saida $saida -Dados $dados -TabelaDePrecos ''

            @(Get-PedidosDoMedidor 'Standard IPv4 Static Public IP' 'brazilsouth') | Should -HaveCount 1
            @(Get-Achados $saida | Where-Object { $_.Regra -eq 'FIN-02' -and $_.Local -eq 'brazilsouth' }).Economia | Should -Be @(21.9, 21.9)
        }

        Context 'Quando a Retail Prices API responde 429 (Too Many Requests), como no ensaio de 09/10' {
            BeforeAll {
                # Os mesmos achados, com os preços da tabela fictícia lida do arquivo, para comparar.
                $saidaArquivo = Join-Path $TestDrive 'saida-429-arquivo'
                Invoke-Relatorio -Saida $saidaArquivo | Out-Null
                $achadosDoArquivo = Get-Content -Raw -Path (Join-Path $saidaArquivo 'achados.json')
            }

            It 'espera o que o Retry-After pede e tenta de novo: os preços saem iguais aos da tabela' {
                $global:ApiDePrecosFalsa.Recusas = 1
                $global:ApiDePrecosFalsa.RetryAfter = 7
                $saida = Join-Path $TestDrive 'saida-429-retry-after'

                Invoke-RelatorioAzure -Saida $saida -TabelaDePrecos '' | Out-Null

                Get-Content -Raw -Path (Join-Path $saida 'achados.json') | Should -BeExactly $achadosDoArquivo
                Should -Invoke Start-Sleep -Times 1 -Exactly
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 7 }
            }

            It 'sem Retry-After, espera cada vez mais: 5 s e, na recusa seguinte, 10 s' {
                $global:ApiDePrecosFalsa.Recusas = 2
                $saida = Join-Path $TestDrive 'saida-429-sem-retry-after'

                Invoke-RelatorioAzure -Saida $saida -TabelaDePrecos '' | Out-Null

                Get-Content -Raw -Path (Join-Path $saida 'achados.json') | Should -BeExactly $achadosDoArquivo
                Should -Invoke Start-Sleep -Times 2 -Exactly
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 5 }
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 10 }
            }

            It 'um Retry-After maior que 60 s vira a espera máxima, de 60 s' {
                $global:ApiDePrecosFalsa.Recusas = 1
                $global:ApiDePrecosFalsa.RetryAfter = 600
                $saida = Join-Path $TestDrive 'saida-429-retry-after-longo'

                Invoke-RelatorioAzure -Saida $saida -TabelaDePrecos '' | Out-Null

                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 60 }
            }

            It 'com 429 nas 3 tentativas, desiste: preço de tabela vira "não sei", a tela avisa uma vez, e nenhum outro preço é pedido' {
                $global:ApiDePrecosFalsa.Recusas = 99
                $saida = Join-Path $TestDrive 'saida-429-sempre'

                $tela = Invoke-RelatorioAzure -Saida $saida -TabelaDePrecos ''

                # 3 tentativas do primeiro medidor; os outros nem são pedidos.
                $global:ApiDePrecosFalsa.Pedidos | Should -HaveCount 3
                $achados = Get-Achados $saida
                foreach ($achado in @($achados | Where-Object Regra -in 'FIN-01', 'FIN-02', 'FIN-04')) {
                    $achado.EconomiaStatus | Should -Be 'nao-sei'
                    $achado.Economia | Should -BeNullOrEmpty
                }
                # O Advisor não depende da tabela de preços.
                ($achados | Where-Object Recurso -eq 'vm-ficticia-servidor-de-arquivos').Economia | Should -Be 412.5
                ([regex]::Matches($tela, 'Não consegui ler a tabela de preços')).Count | Should -Be 1
                $tela | Should -BeLike '*429*3 tentativas*'
            }
        }
    }

    Context 'Pré-checagens: param antes de rodar as regras, dizendo o que falta' {

        It 'sem o Azure CLI, diz para instalá-lo' {
            $saida = Join-Path $TestDrive 'saida-sem-cli'

            { Invoke-RelatorioAzure -Saida $saida -SemAzureCli } | Should -Throw '*Azure CLI*instal*'

            $saida | Should -Not -Exist
        }

        It 'sem a extensão resource-graph, diz o comando que a instala' {
            $saida = Join-Path $TestDrive 'saida-sem-extensao'

            { Invoke-RelatorioAzure -Saida $saida -Cenario sem-extensao } | Should -Throw '*resource-graph*az extension add --name resource-graph*'

            @(Get-ConsultasAoGraph) | Should -HaveCount 0
            $saida | Should -Not -Exist
        }

        It 'sem login no Azure CLI, diz para rodar az login' {
            $saida = Join-Path $TestDrive 'saida-sem-login'

            { Invoke-RelatorioAzure -Saida $saida -Cenario sem-login } | Should -Throw '*não está logado*az login*'

            @(Get-ConsultasAoGraph) | Should -HaveCount 0
            $saida | Should -Not -Exist
        }

        It 'com uma subscription que o login não enxerga, diz para conferir o ID e o papel Reader' {
            $saida = Join-Path $TestDrive 'saida-outra-subscription'
            # Não é um GUID de propósito: a varredura antes de publicar só aceita o GUID todo de zeros.
            $outra = 'subscription-que-o-login-nao-enxerga'

            { Invoke-RelatorioAzure -Saida $saida -SubscriptionId $outra } | Should -Throw "*$outra*Reader*"

            @(Get-ConsultasAoGraph) | Should -HaveCount 0
            $saida | Should -Not -Exist
        }
    }

    Context 'Erros no meio da execução' {

        It 'um erro do az graph query vira uma mensagem com o nome da regra e o motivo, sem o JSON bruto' {
            $saida = Join-Path $TestDrive 'saida-erro-na-consulta'

            $erro = { Invoke-RelatorioAzure -Saida $saida -Cenario erro-na-consulta } | Should -Throw -PassThru

            $mensagem = $erro.Exception.Message
            $mensagem | Should -BeLike '*FIN-01*'
            $mensagem | Should -BeLike "*Unknown function: 'todatetimex'*"
            $mensagem | Should -Not -Match '[{}]'
            $saida | Should -Not -Exist
        }

        It 'uma resposta pela metade, sem skip token, faz o relatório parar em vez de entregar parte dos achados' {
            # Acontece quando a KQL usa limit, take ou sample: o Azure corta e não manda o skip token.
            $saida = Join-Path $TestDrive 'saida-truncada'

            { Invoke-RelatorioAzure -Saida $saida -Dados $script:Truncado } | Should -Throw '*FIN-01*2 de 3*'

            $saida | Should -Not -Exist
        }
    }
}
