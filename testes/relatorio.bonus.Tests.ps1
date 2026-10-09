#requires -Version 7.0
<#
Testes dos bônus do relatório FinOps (ticket 10), pelo ponto de entrada público. O teste confere
só o que sai do script: achados.json, relatorio-finops.html e o que ele escreve na tela.

- As regras bônus (FIN-08 a FIN-11) rodam com a fonte Arquivo. Como nas regras do núcleo,
  testes/dados/FIN-xx.json é a resposta da KQL que dispara a regra, e testes/dados-sem-achados/
  traz a resposta vazia, que é o caso "não dispara".

Nenhum comando do Azure é executado.

Rodar: pwsh -NoProfile -Command "Invoke-Pester -Path testes/relatorio.bonus.Tests.ps1 -Output Detailed"
#>

BeforeDiscovery {
    # O que cada regra bônus deve apontar com os dados fictícios de testes/dados/.
    # Motivo: o que o "não sei" de cada regra precisa dizer.
    $regrasBonus = @(
        @{
            Id = 'FIN-08'; Titulo = 'Load Balancer sem pool de back-end ou sem regras'; Severidade = 'Média'
            Recursos = @('lb-ficticio-sem-pool', 'lb-ficticio-sem-regras'); Motivo = '*regras*'
        }
        @{
            Id = 'FIN-09'; Titulo = 'Application Gateway sem listener, regra ou pool de back-end'; Severidade = 'Alta'
            Recursos = @('appgw-ficticio-sem-listener', 'appgw-ficticio-sem-pool'); Motivo = '*camada*'
        }
        @{
            # A NIC não tem custo: o "não sei" diz isso, em vez de mostrar 0.
            Id = 'FIN-10'; Titulo = 'Interface de rede (NIC) que não está ligada a nenhuma VM'; Severidade = 'Baixa'
            Recursos = @('nic-ficticia-com-ip-publico', 'nic-ficticia-sobra-da-vm-apagada'); Motivo = '*NIC*não é cobrada*'
        }
        @{
            # Um achado por tipo de recurso: o "recurso" do achado é o tipo.
            Id = 'FIN-11'; Titulo = 'Recursos sem as tags de custo (CostCenter, Owner, Environment), por tipo'; Severidade = 'Baixa'
            Recursos = @('microsoft.keyvault/vaults', 'microsoft.network/networksecuritygroups', 'microsoft.storage/storageaccounts')
            Motivo = '*não é desperdício por si só*'
        }
    )
}

BeforeAll {
    # Os caminhos padrão e os ajudantes comuns: Invoke-Relatorio (que devolve o que o script
    # escreveu na tela, o resumo e os avisos), Get-Achados, Get-Html, Get-BlocoDaRegra,
    # Get-TextoVisivel, Get-LinhaDoRecurso, New-CopiaDosDados...
    . (Join-Path $PSScriptRoot 'Comum.ps1')

    # Mexe na resposta fictícia do Cost Management: o bloco recebe as linhas e devolve as linhas novas.
    function Edit-CustoReal {
        param([string]$Pasta, [scriptblock]$Mudanca)
        $arquivo = Join-Path $Pasta 'custo-real.json'
        $resposta = Get-Content -Raw -Path $arquivo | ConvertFrom-Json
        $resposta.properties.rows = @(& $Mudanca @($resposta.properties.rows))
        $resposta | ConvertTo-Json -Depth 10 | Set-Content -Path $arquivo -Encoding utf8
    }

    # Quantas vezes um trecho aparece num texto.
    function Measure-Ocorrencias {
        param([string]$Texto, [string]$Trecho)
        ([regex]::Matches($Texto, [regex]::Escape($Trecho))).Count
    }

    # Os nomes originais dos dados fictícios: name, resourceGroup, subscriptionId e id de todas as
    # linhas de todas as regras. No modo anonimizado, nenhum deles pode sair do script.
    $script:Originais = @(
        foreach ($arquivo in Get-ChildItem -Path $script:Dados -Filter 'FIN-*.json') {
            foreach ($linha in @((Get-Content -Raw -Path $arquivo.FullName | ConvertFrom-Json).data)) {
                foreach ($coluna in 'name', 'resourceGroup', 'subscriptionId', 'id') {
                    if ($linha.PSObject.Properties[$coluna] -and $linha.$coluna) { [string]$linha.$coluna }
                }
            }
        }
    ) | Sort-Object -Unique

    # Cada nome original que aparece num texto, sem diferenciar maiúsculas.
    function Find-Originais {
        param([string]$Texto, [string[]]$Mais = @())
        foreach ($original in @($script:Originais) + $Mais) {
            if ($Texto.IndexOf($original, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $original }
        }
    }

    # Os nomes originais que aparecem em algum arquivo da pasta de saída.
    function Find-VazamentosNaSaida {
        param([string]$Saida, [string[]]$Mais = @())
        foreach ($arquivo in Get-ChildItem -Path $Saida -Recurse -File) {
            $texto = Get-Content -Raw -Encoding UTF8 -Path $arquivo.FullName
            foreach ($original in Find-Originais $texto $Mais) { "$($arquivo.Name): $original" }
        }
    }
}

Describe 'Relatório FinOps: regras bônus' {

    Context 'Com os dados fictícios, em que toda regra bônus dispara' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-bonus'
            Invoke-Relatorio -Saida $saida | Out-Null
            $achados = Get-Achados $saida
            $html = Get-Html $saida
        }

        It '<Id> aponta cada recurso que veio na resposta da KQL, com o título e a severidade da regra' -ForEach $regrasBonus {
            $daRegra = @($achados | Where-Object Regra -eq $Id)
            @($daRegra.Recurso | Sort-Object) | Should -Be @($Recursos | Sort-Object)
            foreach ($achado in $daRegra) {
                $achado.Titulo | Should -Be $Titulo
                $achado.Severidade | Should -Be $Severidade
                $achado.Subscription | Should -Be $script:Sub
            }
        }

        It 'o HTML tem um bloco de <Id> com o título, a contagem e cada recurso apontado' -ForEach $regrasBonus {
            $bloco = Get-BlocoDaRegra $html $Id
            $bloco | Should -Not -BeNullOrEmpty
            $bloco | Should -BeLike "*$Titulo*"
            $bloco | Should -BeLike "*$($Recursos.Count) achados*"
            foreach ($recurso in $Recursos) { $bloco | Should -BeLike "*$recurso*" }
        }

        It '<Id> fica com "não sei", nunca com 0, e diz por quê' -ForEach $regrasBonus {
            foreach ($achado in @($achados | Where-Object Regra -eq $Id)) {
                $achado.Economia | Should -BeNullOrEmpty
                $achado.EconomiaStatus | Should -Be 'nao-sei'
                $achado.EconomiaMotivo | Should -BeLike $Motivo
            }
        }

        It 'FIN-08 mostra nos detalhes quantos pools e quantas regras o Load Balancer tem' {
            $semPool = $achados | Where-Object Recurso -eq 'lb-ficticio-sem-pool'
            $semPool.Detalhes.pools | Should -Be 0
            $semPool.Detalhes.regras | Should -Be 2
            $semRegras = $achados | Where-Object Recurso -eq 'lb-ficticio-sem-regras'
            $semRegras.Detalhes.pools | Should -Be 1
            $semRegras.Detalhes.regras | Should -Be 0
        }

        It 'FIN-09 mostra nos detalhes a camada, o estado e quantos listeners, regras e pools o App Gateway tem' {
            $semListener = $achados | Where-Object Recurso -eq 'appgw-ficticio-sem-listener'
            $semListener.Detalhes.camada | Should -Be 'Standard_v2'
            $semListener.Detalhes.estado | Should -Be 'Running'
            $semListener.Detalhes.listeners | Should -Be 0
            $semListener.Detalhes.regras | Should -Be 0
            $semListener.Detalhes.pools | Should -Be 1
            ($achados | Where-Object Recurso -eq 'appgw-ficticio-sem-pool').Detalhes.pools | Should -Be 0
        }

        It 'FIN-10 mostra nos detalhes o IP privado e se a NIC segura um IP público, que cobra à parte' {
            $comIp = $achados | Where-Object Recurso -eq 'nic-ficticia-com-ip-publico'
            $comIp.Detalhes.ipPrivado | Should -Be '10.0.2.5'
            $comIp.Detalhes.temIpPublico | Should -BeTrue
            $comIp.EconomiaMotivo | Should -BeLike '*IP público*'
            ($achados | Where-Object Recurso -eq 'nic-ficticia-sobra-da-vm-apagada').Detalhes.temIpPublico | Should -BeFalse
        }

        It 'FIN-11 agrupa por tipo de recurso: um achado por tipo, com quantos recursos têm problema e quais tags faltam' {
            $contas = $achados | Where-Object { $_.Regra -eq 'FIN-11' -and $_.Recurso -eq 'microsoft.storage/storageaccounts' }
            @($contas) | Should -HaveCount 1
            $contas.Detalhes.recursos | Should -Be 4
            $contas.Detalhes.semCostCenter | Should -Be 4
            $contas.Detalhes.semOwner | Should -Be 2
            $contas.Detalhes.semEnvironment | Should -Be 0
            $contas.Detalhes.tagsQueFaltam | Should -Be 'CostCenter, Owner'
            # O tipo vale para a subscription toda: o achado não tem grupo de recursos.
            $contas.GrupoDeRecursos | Should -BeNullOrEmpty
        }

        It 'FIN-11 separa a tag escrita com outra grafia (costcenter no lugar de CostCenter): ela não conta como falta' {
            # Os grupos de segurança têm as três tags, mas um deles com a chave em minúsculas.
            $nsg = $achados | Where-Object { $_.Regra -eq 'FIN-11' -and $_.Recurso -eq 'microsoft.network/networksecuritygroups' }
            $nsg.Detalhes.outraGrafia | Should -Be 1
            $nsg.Detalhes.semCostCenter | Should -Be 0
            $nsg.Detalhes.tagsQueFaltam | Should -Be 'nenhuma'
        }
    }

    Context 'O ID do recurso, que casa o achado com o custo real' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-ids'
            Invoke-Relatorio -Saida $saida | Out-Null
            $achados = Get-Achados $saida
        }

        It 'o achado de <Regra> traz o ID do recurso que a KQL projeta, fora dos detalhes' -ForEach @(
            @{ Regra = 'FIN-01'; Recurso = 'disco-sobra-da-migracao'; Id = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ficticio-loja-online/providers/Microsoft.Compute/disks/disco-sobra-da-migracao' }
            @{ Regra = 'FIN-08'; Recurso = 'lb-ficticio-sem-pool'; Id = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ficticio-loja-online/providers/Microsoft.Network/loadBalancers/lb-ficticio-sem-pool' }
        ) {
            $achado = $achados | Where-Object { $_.Regra -eq $Regra -and $_.Recurso -eq $Recurso }
            $achado.IdDoRecurso | Should -BeExactly $Id
            $achado.Detalhes.PSObject.Properties.Name | Should -Not -Contain 'id'
        }

        It 'toda regra com um recurso por linha projeta o ID; FIN-11, que agrupa por tipo, não tem ID' {
            foreach ($achado in @($achados | Where-Object Regra -ne 'FIN-11')) {
                $achado.IdDoRecurso | Should -Match '^/subscriptions/' -Because "o achado $($achado.Recurso) de $($achado.Regra) precisa do ID"
            }
            foreach ($achado in @($achados | Where-Object Regra -eq 'FIN-11')) { $achado.IdDoRecurso | Should -BeNullOrEmpty }
        }

        It 'no modo anonimizado, o ID do recurso fica oculto' {
            $saidaAnonima = Join-Path $TestDrive 'saida-ids-anonimizada'
            Invoke-Relatorio -Saida $saidaAnonima -Parametros @{ Anonimizar = $true } | Out-Null

            $comId = @(Get-Achados $saidaAnonima | Where-Object Regra -ne 'FIN-11')
            $comId | Should -Not -BeNullOrEmpty
            foreach ($achado in $comId) { $achado.IdDoRecurso | Should -Be '<oculto>' }
            Get-Content -Raw -Path (Join-Path $saidaAnonima 'achados.json') | Should -Not -BeLike '*/subscriptions/*'
        }
    }

    Context 'Com a resposta vazia de cada regra bônus' {
        It 'o HTML mostra <Id> verificada, com "Nenhum achado"' -ForEach $regrasBonus {
            $saida = Join-Path $TestDrive "saida-bonus-vazia-$Id"
            Invoke-Relatorio -PastaDados $script:DadosSemAchados -Saida $saida | Out-Null

            (Get-Content -Raw -Path (Join-Path $saida 'achados.json')).Trim() | Should -Be '[]'
            $bloco = Get-BlocoDaRegra (Get-Html $saida) $Id
            $bloco | Should -BeLike "*$Titulo*"
            $bloco | Should -BeLike '*Nenhum achado*'
        }
    }
}

Describe 'Relatório FinOps: custo real dos últimos 30 dias (-CustoReal)' {

    Context 'Com a fonte Arquivo, o custo vem de custo-real.json, a resposta fictícia do Cost Management' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-custo-real'
            $tela = Invoke-Relatorio -Saida $saida -Parametros @{ CustoReal = $true }
            $achados = Get-Achados $saida
            $html = Get-Html $saida
        }

        It 'troca a economia de <Recurso> pelo custo real dos últimos 30 dias e marca a origem' -ForEach @(
            # O Cost Management devolve o ID em minúsculas, e o achado casa mesmo assim.
            @{ Recurso = 'disco-sobra-da-migracao'; Valor = 312.4 }     # era R$ 340,00 de preço de tabela
            @{ Recurso = 'lb-ficticio-sem-pool'; Valor = 95.12 }        # era "não sei"; 95,1249 vira 95,12
            @{ Recurso = 'appgw-ficticio-sem-pool'; Valor = 1830.55 }   # era "não sei"
            @{ Recurso = 'snapshot-ficticio-backup-manual'; Valor = 27.9 }  # era "não sei"
        ) {
            $achado = Get-Achado $achados $Recurso
            $achado.Economia | Should -Be $Valor
            $achado.EconomiaStatus | Should -Be 'estimada'
            $achado.EconomiaOrigem | Should -Be 'custo-real'
            $achado.EconomiaMotivo | Should -BeNullOrEmpty
        }

        It 'sem custo no Cost Management, ou com custo 0, o achado fica como estava: nunca mostra 0' {
            $semCusto = Get-Achado $achados 'disco-esquecido-vm-teste'
            $semCusto.Economia | Should -Be 70
            $semCusto.EconomiaOrigem | Should -Be 'preco-de-tabela'
            $custoZero = Get-Achado $achados 'ip-ficticio-sobra-do-teste'
            $custoZero.Economia | Should -Be 18.25
            $custoZero.EconomiaOrigem | Should -Be 'preco-de-tabela'
            $semNada = Get-Achado $achados 'lb-ficticio-sem-regras'
            $semNada.EconomiaStatus | Should -Be 'nao-sei'
            $semNada.Economia | Should -BeNullOrEmpty
        }

        It '<Recurso> (<Regra>) fica como estava, porque o custo do recurso não é a economia dessa regra' -ForEach @(
            # VM desligada: os discos são recursos à parte, e a VM desalocada quase não custa.
            @{ Regra = 'FIN-03'; Recurso = 'vm-ficticia-teste-de-carga'; Status = 'nao-sei'; Origem = $null; Valor = $null }
            # Log Analytics: o custo do workspace não é o que se economiza mudando a retenção.
            @{ Regra = 'FIN-06'; Recurso = 'log-ficticio-central'; Status = 'nao-sei'; Origem = $null; Valor = $null }
            # Advisor: a economia da recomendação é uma parte do custo, e o próprio Advisor diz qual.
            @{ Regra = 'FIN-07'; Recurso = 'vm-ficticia-servidor-de-arquivos'; Status = 'estimada'; Origem = 'advisor'; Valor = 412.5 }
        ) {
            $achado = Get-Achado $achados $Recurso
            $achado.EconomiaStatus | Should -Be $Status
            $achado.EconomiaOrigem | Should -Be $Origem
            $achado.Economia | Should -Be $Valor
        }

        It 'o HTML marca a origem de cada valor: custo real, preço de tabela ou Advisor' {
            Get-LinhaDoRecurso $html 'disco-sobra-da-migracao' | Should -BeLike '*R$ 312,40*custo real*'
            Get-LinhaDoRecurso $html 'disco-esquecido-vm-teste' | Should -BeLike '*R$ 70,00*preço de tabela*'
            Get-LinhaDoRecurso $html 'vm-ficticia-servidor-de-arquivos' | Should -BeLike '*R$ 412,50*Advisor*'
        }

        It 'o topo soma o custo real com o resto e conta o "não sei" que sobrou' {
            # 2.730,55 - 340,00 + 312,40 (disco) + 95,12 (LB) + 1.830,55 (App Gateway) + 27,90 (snapshot) = 4.656,52.
            # O "não sei" vai de 15 para 12: o LB, o App Gateway e o snapshot ganharam o custo real.
            $texto = Get-TextoVisivel $html
            $texto | Should -BeLike '*Economia estimada: R$ 4.656,52/mês*'
            $texto | Should -BeLike '*12 achados sem estimativa (não sei)*'
        }

        It 'o HTML e a tela dizem que o custo real foi lido, e de onde' {
            Get-TextoVisivel $html | Should -BeLike '*Custo real*custo-real.json*'
            $tela | Should -BeLike '*Custo real: 4 achados*'
        }
    }

    Context 'Sem -CustoReal' {
        It 'nada muda: nenhum achado usa o custo real, mesmo com custo-real.json na pasta de dados' {
            $saida = Join-Path $TestDrive 'saida-sem-custo-real'
            $tela = Invoke-Relatorio -Saida $saida
            $achados = Get-Achados $saida

            @($achados | Where-Object EconomiaOrigem -eq 'custo-real') | Should -HaveCount 0
            $disco = Get-Achado $achados 'disco-sobra-da-migracao'
            $disco.Economia | Should -Be 340
            $disco.EconomiaOrigem | Should -Be 'preco-de-tabela'
            Get-TextoVisivel (Get-Html $saida) | Should -Not -BeLike '*custo real*'
            $tela | Should -Not -BeLike '*custo real*'
        }
    }

    Context 'Com a fonte Arquivo e sem custo-real.json na pasta de dados' {
        It 'segue com o preço de tabela ou "não sei" e avisa uma vez que não leu o custo real' {
            $dados = New-CopiaDosDados 'dados-sem-custo-real'
            Remove-Item -Path (Join-Path $dados 'custo-real.json')
            $saida = Join-Path $TestDrive 'saida-sem-arquivo-de-custo'

            $tela = Invoke-Relatorio -PastaDados $dados -Saida $saida -Parametros @{ CustoReal = $true }

            $achados = Get-Achados $saida
            @($achados | Where-Object EconomiaOrigem -eq 'custo-real') | Should -HaveCount 0
            (Get-Achado $achados 'disco-sobra-da-migracao').Economia | Should -Be 340
            Measure-Ocorrencias $tela 'Não li o custo real' | Should -Be 1
            $tela | Should -BeLike '*custo-real.json*'
        }
    }

    Context 'Com -CustoReal e -Anonimizar' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-custo-real-anonimizada'
            $tela = Invoke-Relatorio -Saida $saida -Parametros @{ CustoReal = $true; Anonimizar = $true }
            $achados = Get-Achados $saida
        }

        It 'nenhum arquivo da pasta de saída nem a tela mostram um nome ou um ID original' {
            Find-VazamentosNaSaida $saida | Should -BeNullOrEmpty
            Find-Originais $tela | Should -BeNullOrEmpty
        }

        It 'o custo real também vai para a dezena, e o ID do recurso fica oculto' {
            # O disco de 256 GB custou R$ 312,40 nos 30 dias: na dezena, R$ 310.
            $disco = $achados | Where-Object { $_.Regra -eq 'FIN-01' -and $_.Detalhes.tamanhoGB -eq 256 }
            $disco.Economia | Should -Be 310
            $disco.EconomiaOrigem | Should -Be 'custo-real'
            $disco.IdDoRecurso | Should -Be '<oculto>'
        }
    }

    Context 'Catálogo com o campo CustoReal errado' {
        It 'com CustoReal = <Valor>, para dizendo qual regra corrigir, e não grava nada' -ForEach @(
            @{ Valor = "'sim'" }
            @{ Valor = '1' }
        ) {
            $copia = New-ScriptComCatalogo "@{ Id = 'FIN-01'; Titulo = 'Regra de teste'; Severidade = 'Baixa'; Kql = 'resources'; Economia = @{ Forma = 'nao-sei'; Motivo = 'teste'; CustoReal = $Valor } }"
            $saida = Join-Path $TestDrive "saida-catalogo-$([guid]::NewGuid().ToString('N'))"

            { Invoke-Relatorio -Script $copia -Saida $saida } | Should -Throw '*FIN-01*CustoReal*'

            $saida | Should -Not -Exist
        }
    }

    Context 'Com o custo em outra moeda' {
        It 'não converte: os achados ficam como estavam, e a tela avisa uma vez' {
            $dados = New-CopiaDosDados 'dados-custo-em-dolar'
            Edit-CustoReal $dados { param($linhas) foreach ($linha in $linhas) { $linha[2] = 'USD'; , $linha } }
            $saida = Join-Path $TestDrive 'saida-custo-em-dolar'

            $tela = Invoke-Relatorio -PastaDados $dados -Saida $saida -Parametros @{ CustoReal = $true }

            $achados = Get-Achados $saida
            @($achados | Where-Object EconomiaOrigem -eq 'custo-real') | Should -HaveCount 0
            (Get-Achado $achados 'disco-sobra-da-migracao').Economia | Should -Be 340
            Measure-Ocorrencias $tela 'não converte moeda' | Should -Be 1
            $tela | Should -BeLike '*USD*'
        }
    }

    Context 'Com a fonte Azure (az falso no PATH, sem Azure nenhum)' {
        BeforeAll {
            # O mesmo esquema de testes/relatorio.azure.Tests.ps1: um lançador do az falso numa pasta
            # temporária, na frente do PATH só durante cada execução.
            $script:AzFalso = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'az-falso/az.ps1'))
            $script:Paginado = Join-Path $PSScriptRoot 'az-falso/paginado'
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
            $script:PathOriginal = $env:PATH
            $script:VariaveisOriginais = @{}
            foreach ($nome in 'AZ_FALSO_LOG', 'AZ_FALSO_DADOS', 'AZ_FALSO_CENARIO') {
                $script:VariaveisOriginais[$nome] = [Environment]::GetEnvironmentVariable($nome)
            }
            $script:ConsultaDeCusto = '^https://management\.azure\.com/subscriptions/[^/]+/providers/Microsoft\.CostManagement/query\?api-version=[\w.-]+$'

            # O que o relatório pode pedir ao az: os três comandos de leitura e, só no custo real,
            # o POST da consulta de custo do Cost Management. Nada mais.
            function Test-ChamadaDeLeitura {
                param([string[]]$Chamada)
                if ((($Chamada | Select-Object -First 2) -join ' ') -in 'account show', 'extension show', 'graph query') { return $true }
                $Chamada[0] -eq 'rest' -and (Get-Argumento $Chamada '--method') -eq 'post' -and (Get-Argumento $Chamada '--url') -match $script:ConsultaDeCusto
            }

            # Roda o relatório com -Fonte Azure e o az falso; devolve o que ele escreveu na tela.
            # Em toda execução, confere que o script só chamou o que pode.
            function Invoke-RelatorioAzure {
                param([string]$Saida, [string]$Dados = $script:Paginado, [string]$Cenario = 'normal', [hashtable]$Parametros = @{})
                $script:UltimoLog = Join-Path $TestDrive "az-$([guid]::NewGuid().ToString('N')).log"
                $env:AZ_FALSO_LOG = $script:UltimoLog
                $env:AZ_FALSO_DADOS = $Dados
                $env:AZ_FALSO_CENARIO = $Cenario
                $env:PATH = "$script:PastaDoAz$([System.IO.Path]::PathSeparator)$script:PathOriginal"
                try {
                    $az = (Get-Command az -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
                    if ($az -notlike "$script:PastaDoAz*") { throw "O az do PATH não é o falso ($az). Teste abortado para não falar com o Azure real." }
                    & $script:Relatorio -SubscriptionId $script:Sub -Fonte Azure -Saida $Saida -TabelaDePrecos (Join-Path $script:Dados 'precos.json') @Parametros 6>&1 3>&1 | Out-String
                } finally {
                    $env:PATH = $script:PathOriginal
                    $fora = @(Get-ChamadasAoAz | Where-Object { -not (Test-ChamadaDeLeitura $_) })
                    if ($fora) { throw "O relatório chamou comando fora da lista de leitura: az $($fora[0] -join ' ')" }
                }
            }

            # As chamadas que o az falso recebeu na última execução; cada uma é a lista de argumentos.
            function Get-ChamadasAoAz {
                foreach ($registro in Get-RegistrosDoAz) { , @($registro.args) }
            }

            # O log inteiro: cada linha traz args e, na consulta de custo, body (o corpo enviado).
            function Get-RegistrosDoAz {
                if (-not (Test-Path -LiteralPath $script:UltimoLog)) { return }
                foreach ($linha in Get-Content -LiteralPath $script:UltimoLog -Encoding utf8) { $linha | ConvertFrom-Json }
            }

            function Get-ConsultasDeCusto {
                @(Get-RegistrosDoAz | Where-Object { $_.args[0] -eq 'rest' })
            }

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

        Context 'Com -CustoReal e a permissão de ler custo' {
            BeforeAll {
                $saida = Join-Path $TestDrive 'saida-azure-custo-real'
                $tela = Invoke-RelatorioAzure -Saida $saida -Parametros @{ CustoReal = $true }
                $consultas = @(Get-ConsultasDeCusto)
            }

            It 'faz um POST na consulta de custo do Cost Management da subscription-alvo, com o corpo num arquivo' {
                $consultas | Should -HaveCount 1
                $chamada = @($consultas[0].args)
                Get-Argumento $chamada '--method' | Should -Be 'post'
                Get-Argumento $chamada '--url' | Should -Match $script:ConsultaDeCusto
                Get-Argumento $chamada '--url' | Should -BeLike "https://management.azure.com/subscriptions/$script:Sub/*"
                Get-Argumento $chamada '--body' | Should -BeLike '@*'
            }

            It 'o corpo pede o custo real (ActualCost) dos últimos 30 dias, somado por recurso' {
                $corpo = $consultas[0].body | ConvertFrom-Json
                $corpo.type | Should -Be 'ActualCost'
                $corpo.timeframe | Should -Be 'Custom'
                $corpo.dataset.granularity | Should -Be 'None'
                $corpo.dataset.aggregation.totalCost.function | Should -Be 'Sum'
                @($corpo.dataset.grouping) | Should -HaveCount 1
                $corpo.dataset.grouping[0].type | Should -Be 'Dimension'
                $corpo.dataset.grouping[0].name | Should -Be 'ResourceId'
                # Os 30 dias completos antes de hoje, em UTC: do primeiro segundo ao último.
                $de = ([datetime]$corpo.timePeriod.from).ToUniversalTime()
                $ate = ([datetime]$corpo.timePeriod.to).ToUniversalTime()
                $de.TimeOfDay | Should -Be ([timespan]::Zero)
                ($ate - $de) | Should -Be ([timespan]::FromDays(30) - [timespan]::FromSeconds(1))
                $ate | Should -BeLessThan ([datetime]::UtcNow.Date)
                $ate | Should -BeGreaterThan ([datetime]::UtcNow.Date.AddDays(-1))
            }

            It 'grava o mesmo achados.json que a fonte Arquivo com -CustoReal, com os mesmos dados' {
                $saidaArquivo = Join-Path $TestDrive 'saida-arquivo-custo-real'
                Invoke-Relatorio -Saida $saidaArquivo -Parametros @{ CustoReal = $true } | Out-Null

                Get-Content -Raw -Path (Join-Path $saida 'achados.json') | Should -BeExactly (Get-Content -Raw -Path (Join-Path $saidaArquivo 'achados.json'))
                (Get-Achado (Get-Achados $saida) 'lb-ficticio-sem-pool').EconomiaOrigem | Should -Be 'custo-real'
            }

            It 'o HTML diz que o custo real veio do Cost Management e de qual período' {
                Get-TextoVisivel (Get-Html $saida) | Should -Match 'Custo real\s*Cost Management, de \d\d/\d\d/\d{4} a \d\d/\d\d/\d{4}'
            }
        }

        Context 'Com o resultado do Cost Management em duas páginas' {
            It 'junta as páginas pelo nextLink, pedindo a segunda com o skip token, e chega nos mesmos achados' {
                # Uma cópia das respostas enlatadas com o custo dividido em duas páginas.
                $dados = New-CopiaDosDados 'paginado-custo-em-duas-paginas' -De $script:Paginado
                $resposta = Get-Content -Raw -Path (Join-Path $dados 'custo-real.json') | ConvertFrom-Json
                $linhas = @($resposta.properties.rows)
                $segunda = $resposta | ConvertTo-Json -Depth 10 | ConvertFrom-Json
                $resposta.properties.rows = @($linhas | Select-Object -First 3)
                $resposta.properties.nextLink = "https://management.azure.com/subscriptions/$script:Sub/providers/Microsoft.CostManagement/query?api-version=2025-03-01&`$skiptoken=pagina-2"
                $segunda.properties.rows = @($linhas | Select-Object -Skip 3)
                $resposta | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $dados 'custo-real.json') -Encoding utf8
                $segunda | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $dados 'custo-real.pagina-2.json') -Encoding utf8
                $saida = Join-Path $TestDrive 'saida-custo-em-duas-paginas'

                Invoke-RelatorioAzure -Saida $saida -Dados $dados -Parametros @{ CustoReal = $true } | Out-Null

                $consultas = @(Get-ConsultasDeCusto)
                $consultas | Should -HaveCount 2
                @($consultas[0].args) | Should -Not -Contain '--url-parameters'
                Get-Argumento @($consultas[1].args) '--url-parameters' | Should -Be '$skiptoken=pagina-2'
                $achados = Get-Achados $saida
                # A primeira página traz o disco; a segunda, o snapshot.
                (Get-Achado $achados 'disco-sobra-da-migracao').Economia | Should -Be 312.4
                (Get-Achado $achados 'snapshot-ficticio-backup-manual').Economia | Should -Be 27.9
            }
        }

        Context 'Sem permissão de ler custo (sem o papel Cost Management Reader)' {
            BeforeAll {
                $saida = Join-Path $TestDrive 'saida-sem-permissao-de-custo'
                $tela = Invoke-RelatorioAzure -Saida $saida -Cenario sem-permissao-de-custo -Parametros @{ CustoReal = $true }
            }

            It 'segue em frente: grava os mesmos achados que sem -CustoReal, com o preço de tabela ou "não sei"' {
                $saidaSemCusto = Join-Path $TestDrive 'saida-azure-sem-custo-real'
                Invoke-RelatorioAzure -Saida $saidaSemCusto | Out-Null

                Get-Content -Raw -Path (Join-Path $saida 'achados.json') | Should -BeExactly (Get-Content -Raw -Path (Join-Path $saidaSemCusto 'achados.json'))
            }

            It 'avisa uma vez que não leu o custo real e diz qual papel falta' {
                Measure-Ocorrencias $tela 'Não li o custo real' | Should -Be 1
                $tela | Should -BeLike '*Cost Management Reader*'
            }

            It 'o HTML também diz que o custo real não foi lido' {
                Get-TextoVisivel (Get-Html $saida) | Should -BeLike '*Custo real*Não li o custo real*'
            }

            It 'no modo anonimizado, nem o aviso mostra a subscription, o e-mail ou o ID que vêm no erro do Azure' {
                $saidaAnonima = Join-Path $TestDrive 'saida-sem-permissao-anonimizada'
                $telaAnonima = Invoke-RelatorioAzure -Saida $saidaAnonima -Cenario sem-permissao-de-custo -Parametros @{ CustoReal = $true; Anonimizar = $true }

                $telaAnonima | Should -BeLike '*Não li o custo real*'
                Find-Originais $telaAnonima 'aluno@exemplo.com' | Should -BeNullOrEmpty
                Find-VazamentosNaSaida $saidaAnonima 'aluno@exemplo.com' | Should -BeNullOrEmpty
            }
        }

        Context 'Com o Cost Management respondendo 429 (Too Many Requests), como no ensaio de 09/10' {
            BeforeAll {
                # A espera antes de uma nova tentativa não dorme de verdade: o teste só confere
                # quanto o relatório pediu para esperar.
                Mock Start-Sleep { }
            }

            It 'espera e tenta de novo: com 429 e depois a resposta, o custo real entra como sem o 429' {
                $saida = Join-Path $TestDrive 'saida-custo-429-uma-vez'

                $tela = Invoke-RelatorioAzure -Saida $saida -Cenario custo-429-uma-vez -Parametros @{ CustoReal = $true }

                @(Get-ConsultasDeCusto) | Should -HaveCount 2
                $disco = Get-Achado (Get-Achados $saida) 'disco-sobra-da-migracao'
                $disco.Economia | Should -Be 312.4
                $disco.EconomiaOrigem | Should -Be 'custo-real'
                $tela | Should -Not -BeLike '*Não li o custo real*'
                Should -Invoke Start-Sleep -Times 1 -Exactly
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 5 }
            }

            It 'com 429 nas 3 tentativas, espera cada vez mais, segue sem o custo real e avisa uma vez por quê' {
                $saida = Join-Path $TestDrive 'saida-custo-429-sempre'

                $tela = Invoke-RelatorioAzure -Saida $saida -Cenario custo-429-sempre -Parametros @{ CustoReal = $true }

                @(Get-ConsultasDeCusto) | Should -HaveCount 3
                @(Get-Achados $saida | Where-Object EconomiaOrigem -eq 'custo-real') | Should -HaveCount 0
                (Get-Achado (Get-Achados $saida) 'disco-sobra-da-migracao').Economia | Should -Be 340
                Measure-Ocorrencias $tela 'Não li o custo real' | Should -Be 1
                $tela | Should -BeLike '*Não li o custo real*429*3 tentativas*'
                Should -Invoke Start-Sleep -Times 2 -Exactly
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 5 }
                Should -Invoke Start-Sleep -Times 1 -Exactly -ParameterFilter { $Seconds -eq 10 }
            }
        }

        Context 'O az falso, que faz o papel do Azure CLI' {
            It 'recusa <Caso>, como qualquer comando fora da lista de leitura' -ForEach @(
                @{ Caso = 'um GET na consulta de custo'; Argumentos = @('rest', '--method', 'get', '--url', 'https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.CostManagement/query?api-version=2025-03-01') }
                @{ Caso = 'um POST em outro caminho do Cost Management (rodar um export)'; Argumentos = @('rest', '--method', 'post', '--url', 'https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.CostManagement/exports/exportacao/run?api-version=2025-03-01') }
                @{ Caso = 'um PUT num recurso'; Argumentos = @('rest', '--method', 'put', '--url', 'https://management.azure.com/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ficticio-laboratorio?api-version=2021-04-01') }
                @{ Caso = 'um comando de escrita'; Argumentos = @('disk', 'delete', '--ids', '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-ficticio-laboratorio/providers/Microsoft.Compute/disks/disco-sobra-da-migracao') }
            ) {
                $env:AZ_FALSO_LOG = Join-Path $TestDrive "az-recusa-$([guid]::NewGuid().ToString('N')).log"
                $env:AZ_FALSO_DADOS = $script:Paginado
                $env:AZ_FALSO_CENARIO = 'normal'

                $null = & pwsh -NoProfile -NonInteractive -File $script:AzFalso @Argumentos 2>&1

                $LASTEXITCODE | Should -Be 99
            }
        }

        Context 'Sem -CustoReal' {
            It 'não faz nenhuma chamada ao Cost Management' {
                $saida = Join-Path $TestDrive 'saida-azure-sem-switch'
                Invoke-RelatorioAzure -Saida $saida | Out-Null

                @(Get-ChamadasAoAz) | Should -Not -BeNullOrEmpty
                @(Get-ConsultasDeCusto) | Should -HaveCount 0
                @(Get-ChamadasAoAz | Where-Object { ($_ -join ' ') -match 'CostManagement' }) | Should -HaveCount 0
            }
        }
    }
}
