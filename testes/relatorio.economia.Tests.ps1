#requires -Version 7.0
<#
Testes da economia estimada do relatório FinOps (seam 1 da spec): o script roda de verdade
pelo ponto de entrada público, com a fonte Arquivo, e o teste confere só o que sai dele:
achados.json, relatorio-finops.html e o resumo na tela.

Com a fonte Arquivo, os preços vêm de testes/dados/precos.json, uma tabela de preços fictícia
no formato da resposta da Retail Prices API (Items[]). Os valores são inventados e redondos,
para que a conta de cada caso dê para fazer de cabeça. Nenhum teste chama a rede nem o Azure.

Rodar: pwsh -NoProfile -Command "Invoke-Pester -Path testes/relatorio.economia.Tests.ps1 -Output Detailed"
#>

BeforeAll {
    # Os caminhos padrão e os ajudantes comuns: Invoke-Relatorio, Get-Achados, Get-Html,
    # Get-TextoVisivel, Get-LinhaDoRecurso, New-CopiaDosDados...
    . (Join-Path $PSScriptRoot 'Comum.ps1')

    # Troca colunas da linha de um recurso na resposta fictícia de uma regra.
    function Set-Colunas {
        param([string]$Pasta, [string]$Regra, [string]$Recurso, [hashtable]$Colunas)
        $arquivo = Join-Path $Pasta "$Regra.json"
        $resposta = Get-Content -Raw -Path $arquivo | ConvertFrom-Json
        $linha = $resposta.data | Where-Object name -eq $Recurso
        foreach ($coluna in $Colunas.Keys) { $linha.$coluna = $Colunas[$coluna] }
        $resposta | ConvertTo-Json -Depth 5 | Set-Content -Path $arquivo -Encoding utf8
    }

    # Mexe nos itens da tabela de preços: o bloco recebe a lista e devolve a lista nova.
    function Edit-Precos {
        param([string]$Pasta, [scriptblock]$Mudanca)
        $arquivo = Join-Path $Pasta 'precos.json'
        $tabela = Get-Content -Raw -Path $arquivo | ConvertFrom-Json
        $tabela.Items = @(& $Mudanca @($tabela.Items))
        $tabela | ConvertTo-Json -Depth 5 | Set-Content -Path $arquivo -Encoding utf8
    }
}

Describe 'Relatório FinOps: economia estimada e "não sei"' {

    Context 'Com os dados fictícios e a tabela de preços fictícia' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-com-precos'
            $tela = Invoke-Relatorio -Saida $saida
            $achados = Get-Achados $saida
        }

        It 'FIN-07 usa a economia que o próprio Advisor informa' {
            $achado = Get-Achado $achados 'vm-ficticia-servidor-de-arquivos'
            $achado.Economia | Should -Be 412.5
            $achado.EconomiaStatus | Should -Be 'estimada'
            (Get-Achado $achados 'banco-ficticio-relatorios').Economia | Should -Be 158.9
        }

        It 'FIN-01 usa o preço mensal do disco, no tier que comporta o tamanho dele' {
            # 64 GB StandardSSD_LRS em eastus vira E6 (R$ 30,00); 128 GB Standard_LRS vira S10 (R$ 70,00);
            # 256 GB Premium_LRS vira P15 (R$ 340,00). Os preços estão em testes/dados/precos.json.
            (Get-Achado $achados 'disco-copia-antiga-do-banco').Economia | Should -Be 30
            (Get-Achado $achados 'disco-esquecido-vm-teste').Economia | Should -Be 70
            $sobra = Get-Achado $achados 'disco-sobra-da-migracao'
            $sobra.Economia | Should -Be 340
            $sobra.EconomiaStatus | Should -Be 'estimada'
        }

        It 'FIN-02 leva o preço por hora do IP para o mês, com 730 horas' {
            # R$ 0,03 por hora em brazilsouth e R$ 0,025 em eastus.
            (Get-Achado $achados 'ip-ficticio-site-desativado').Economia | Should -Be 21.9
            (Get-Achado $achados 'ip-ficticio-sobra-do-teste').Economia | Should -Be 18.25
        }

        It 'FIN-04 cobra cada instância do plano, com o preço do sistema operacional dele' {
            # S1 Windows a R$ 0,60 por hora, 2 instâncias: 0,60 x 730 x 2. P1v3 Linux a R$ 1,10, 1 instância.
            (Get-Achado $achados 'plano-ficticio-homologacao').Economia | Should -Be 876
            (Get-Achado $achados 'plano-ficticio-site-antigo').Economia | Should -Be 803
        }

        It '<Regra> fica com "não sei", sem valor nenhum, e diz por quê' -ForEach @(
            # A VM desligada: a KQL soma os GB dos discos, mas não traz o tier de cada um.
            @{ Regra = 'FIN-03' }
            # O snapshot, incremental ou não: a cobrança é pelo espaço usado, que a KQL não traz.
            @{ Regra = 'FIN-05' }
            # O Log Analytics: o custo depende do volume guardado e ingerido.
            @{ Regra = 'FIN-06' }
        ) {
            $daRegra = @($achados | Where-Object Regra -eq $Regra)
            $daRegra | Should -HaveCount 2
            foreach ($achado in $daRegra) {
                $achado.Economia | Should -BeNullOrEmpty
                $achado.EconomiaStatus | Should -Be 'nao-sei'
                $achado.EconomiaMotivo | Should -Not -BeNullOrEmpty
            }
        }

        It 'nenhum achado mostra economia 0: ou tem um valor positivo, ou fica com "não sei"' {
            foreach ($achado in $achados) {
                if ($achado.EconomiaStatus -eq 'estimada') { $achado.Economia | Should -BeGreaterThan 0 }
                else { $achado.EconomiaStatus | Should -Be 'nao-sei'; $achado.Economia | Should -BeNullOrEmpty }
            }
        }

        It 'o topo do HTML mostra a economia estimada por mês e, à parte, quantos achados ficaram com "não sei"' {
            # Estimados: discos 440,00 + IPs 40,15 + planos 1.679,00 + Advisor 571,40 = 2.730,55.
            # "Não sei": 2 de FIN-03, 2 de FIN-05 e 2 de FIN-06, mais os 9 das regras bônus: 2 de FIN-08, 2 de FIN-09, 2 de FIN-10 e 3 de FIN-11.
            $texto = Get-TextoVisivel (Get-Html $saida)
            $texto | Should -BeLike '*Economia estimada: R$ 2.730,55/mês*'
            $texto | Should -BeLike '*15 achados sem estimativa (não sei)*'
        }

        It 'a tabela de cada regra tem a coluna "Economia/mês", com o valor em reais ou "não sei"' {
            $html = Get-Html $saida
            $html | Should -BeLike '*<th class="num">Economia/mês</th>*'
            Get-LinhaDoRecurso $html 'disco-sobra-da-migracao' | Should -BeLike '*R$ 340,00*'
            Get-LinhaDoRecurso $html 'plano-ficticio-homologacao' | Should -BeLike '*R$ 876,00*'
            Get-LinhaDoRecurso $html 'ip-ficticio-sobra-do-teste' | Should -BeLike '*R$ 18,25*'
            Get-LinhaDoRecurso $html 'vm-ficticia-teste-de-carga' | Should -BeLike '*não sei*'
            Get-LinhaDoRecurso $html 'vm-ficticia-teste-de-carga' | Should -Not -BeLike '*R$*'
        }

        It 'achados.json traz a mesma conta: a soma do que foi estimado e a contagem do "não sei"' {
            ($achados | Where-Object EconomiaStatus -eq 'estimada' | Measure-Object -Property Economia -Sum).Sum | Should -Be 2730.55
            @($achados | Where-Object EconomiaStatus -eq 'nao-sei') | Should -HaveCount 15
        }

        It 'o resumo na tela também mostra a economia estimada e o "não sei"' {
            $tela | Should -BeLike '*Economia estimada: R$ 2.730,55/mês*'
            $tela | Should -BeLike '*15 achados sem estimativa (não sei)*'
        }
    }

    Context 'Quando a tabela de preços não tem o medidor' {
        BeforeAll {
            # Sem nenhum item do P15, o disco de 256 GB Premium_LRS fica sem preço.
            $dados = New-CopiaDosDados 'dados-sem-p15'
            Edit-Precos $dados { param($itens) $itens | Where-Object skuName -ne 'P15 LRS' }
            $saida = Join-Path $TestDrive 'saida-sem-p15'
            Invoke-Relatorio -PastaDados $dados -Saida $saida | Out-Null
            $achados = Get-Achados $saida
        }

        It 'o disco fica com "não sei", sem valor, e o motivo cita o medidor' {
            $sobra = Get-Achado $achados 'disco-sobra-da-migracao'
            $sobra.Economia | Should -BeNullOrEmpty
            $sobra.EconomiaStatus | Should -Be 'nao-sei'
            $sobra.EconomiaMotivo | Should -BeLike '*P15 LRS Disk*'
        }

        It 'o total estimado perde só esse disco, e ele passa para a contagem do "não sei"' {
            # 2.730,55 - 340,00 = 2.390,55; o "não sei" vai de 15 para 16.
            $texto = Get-TextoVisivel (Get-Html $saida)
            $texto | Should -BeLike '*Economia estimada: R$ 2.390,55/mês*'
            $texto | Should -BeLike '*16 achados sem estimativa (não sei)*'
        }
    }

    Context 'Com -Anonimizar' {
        BeforeAll {
            # Duas recomendações do Advisor: uma de R$ 3,20, que a dezena levaria a 0, e uma de R$ 123,45.
            $dados = New-CopiaDosDados 'dados-anonimizar'
            Set-Colunas $dados 'FIN-07' 'vm-ficticia-servidor-de-arquivos' @{ economiaAdvisor = 3.2 }
            Set-Colunas $dados 'FIN-07' 'banco-ficticio-relatorios' @{ economiaAdvisor = 123.45 }
            $saida = Join-Path $TestDrive 'saida-anonimizada'
            Invoke-Relatorio -PastaDados $dados -Saida $saida -Parametros @{ Anonimizar = $true } | Out-Null
            $achados = Get-Achados $saida
            # No modo anonimizado o recurso vira rótulo; as recomendações se reconhecem pelo impacto.
            $pequena = $achados | Where-Object { $_.Regra -eq 'FIN-07' -and $_.Detalhes.impacto -eq 'High' }
            $media = $achados | Where-Object { $_.Regra -eq 'FIN-07' -and $_.Detalhes.impacto -eq 'Medium' }
        }

        It 'arredonda a economia para a dezena, com piso de R$ 10: um valor positivo nunca vira 0' {
            $pequena.Economia | Should -Be 10
            $pequena.EconomiaStatus | Should -Be 'estimada'
            $pequena.Detalhes.economiaAdvisor | Should -Be 10
            $media.Economia | Should -Be 120
        }

        It '"não sei" continua "não sei"' {
            foreach ($achado in @($achados | Where-Object Regra -in 'FIN-03', 'FIN-05', 'FIN-06')) {
                $achado.EconomiaStatus | Should -Be 'nao-sei'
                $achado.Economia | Should -BeNullOrEmpty
            }
        }

        It 'o total é a soma dos valores já arredondados' {
            # Advisor 10 + 120; discos 30 + 70 + 340; IPs 20 + 20 (21,90 e 18,25); planos 880 + 800 (876 e 803).
            $texto = Get-TextoVisivel (Get-Html $saida)
            $texto | Should -BeLike '*Economia estimada: R$ 2.290,00/mês*'
            $texto | Should -BeLike '*15 achados sem estimativa (não sei)*'
        }
    }

    Context 'Sem a tabela de preços na pasta de dados' {
        BeforeAll {
            $dados = New-CopiaDosDados 'dados-sem-tabela'
            Remove-Item -Path (Join-Path $dados 'precos.json')
            $saida = Join-Path $TestDrive 'saida-sem-tabela'
            $tela = Invoke-Relatorio -PastaDados $dados -Saida $saida
            $achados = Get-Achados $saida
        }

        It 'os achados de preço de tabela ficam com "não sei", e a tela avisa que faltou a tabela' {
            foreach ($regra in 'FIN-01', 'FIN-02', 'FIN-04') {
                foreach ($achado in @($achados | Where-Object Regra -eq $regra)) {
                    $achado.EconomiaStatus | Should -Be 'nao-sei'
                    $achado.Economia | Should -BeNullOrEmpty
                }
            }
            $tela | Should -BeLike '*tabela de preços*precos.json*'
        }

        It 'o Advisor continua estimado, porque não depende da tabela' {
            (Get-Achado $achados 'vm-ficticia-servidor-de-arquivos').Economia | Should -Be 412.5
            Get-TextoVisivel (Get-Html $saida) | Should -BeLike '*Economia estimada: R$ 571,40/mês*'
        }
    }

    Context 'Com -TabelaDePrecos' {
        It 'usa os preços do arquivo passado, no lugar do precos.json da pasta de dados' {
            $outra = Join-Path $TestDrive 'outra-tabela.json'
            $tabela = Get-Content -Raw -Path (Join-Path $script:Dados 'precos.json') | ConvertFrom-Json
            foreach ($item in $tabela.Items) { if ($item.skuName -eq 'P15 LRS') { $item.retailPrice = 300.0 } }
            $tabela | ConvertTo-Json -Depth 5 | Set-Content -Path $outra -Encoding utf8
            $saida = Join-Path $TestDrive 'saida-outra-tabela'

            Invoke-Relatorio -Saida $saida -Parametros @{ TabelaDePrecos = $outra } | Out-Null

            (Get-Achado (Get-Achados $saida) 'disco-sobra-da-migracao').Economia | Should -Be 300
        }

        It 'com um arquivo que não existe, para dizendo qual é, e não grava nada' {
            $saida = Join-Path $TestDrive 'saida-tabela-inexistente'
            $inexistente = Join-Path $TestDrive 'nao-existe.json'

            { Invoke-Relatorio -Saida $saida -Parametros @{ TabelaDePrecos = $inexistente } } |
                Should -Throw '*nao-existe.json*-TabelaDePrecos*'

            $saida | Should -Not -Exist
        }
    }

    Context 'Catálogo com a forma de economia errada' {
        It 'com <Caso>, para dizendo qual regra corrigir, e não grava nada' -ForEach @(
            @{ Caso = 'uma forma que o script não conhece'; Economia = "@{ Forma = 'preco-de-tabla' }" }
            @{ Caso = "'preco-de-tabela' sem o Medidor"; Economia = "@{ Forma = 'preco-de-tabela' }" }
            @{ Caso = "'advisor' sem a coluna da moeda"; Economia = "@{ Forma = 'advisor'; Coluna = 'economiaAdvisor' }" }
            @{ Caso = 'um DePara sem Valores nem Faixas'; Economia = "@{ Forma = 'preco-de-tabela'; DePara = @{ letra = @{ Coluna = 'sku' } }; Medidor = @{ skuName = '{letra}' } }" }
            @{ Caso = 'um MotivoSeNao de uma coluna que não está no SoQuando'; Economia = "@{ Forma = 'preco-de-tabela'; SoQuando = @{ sku = 'Premium_LRS' }; MotivoSeNao = @{ tamanhoGB = 'Outro tamanho.' }; Medidor = @{ skuName = '{sku}' } }" }
            @{ Caso = 'um MotivoSeNao sem texto'; Economia = "@{ Forma = 'preco-de-tabela'; SoQuando = @{ sku = 'Premium_LRS' }; MotivoSeNao = @{ sku = '' }; Medidor = @{ skuName = '{sku}' } }" }
        ) {
            $copia = New-ScriptComCatalogo "@{ Id = 'FIN-01'; Titulo = 'Regra de teste'; Severidade = 'Baixa'; Kql = 'resources'; Economia = $Economia }"
            $saida = Join-Path $TestDrive "saida-catalogo-$([guid]::NewGuid().ToString('N'))"

            { Invoke-Relatorio -Script $copia -Saida $saida } | Should -Throw '*FIN-01*Economia*'

            $saida | Should -Not -Exist
        }
    }

    Context 'Quando o preço da tabela não é confiável' {
        It 'com <Caso>, o disco fica com "não sei"' -ForEach @(
            @{ Caso = 'dois preços diferentes para o mesmo medidor'; Mudanca = {
                    param($itens) $itens
                    $copia = ($itens | Where-Object { $_.meterName -eq 'P15 LRS Disk' -and $_.productName -eq 'Premium SSD Managed Disks' }) | ConvertTo-Json | ConvertFrom-Json
                    $copia.retailPrice = 999.0; $copia
                } }
            @{ Caso = 'preço zero'; Mudanca = {
                    param($itens) foreach ($item in $itens) { if ($item.skuName -eq 'P15 LRS') { $item.retailPrice = 0.0 }; $item }
                } }
            @{ Caso = 'preço em outra moeda'; Mudanca = {
                    param($itens) foreach ($item in $itens) { if ($item.skuName -eq 'P15 LRS') { $item.currencyCode = 'USD' }; $item }
                } }
            @{ Caso = 'preço por GB, sem a quantidade de GB na regra'; Mudanca = {
                    param($itens) foreach ($item in $itens) { if ($item.skuName -eq 'P15 LRS') { $item.unitOfMeasure = '1 GB/Month' }; $item }
                } }
            @{ Caso = 'um item sem os campos de faixa e de tipo, num arquivo feito à mão'; Mudanca = {
                    param($itens) foreach ($item in $itens) {
                        if ($item.skuName -eq 'P15 LRS') { $item.PSObject.Properties.Remove('tierMinimumUnits'); $item.PSObject.Properties.Remove('type') }
                        $item
                    }
                } }
            @{ Caso = 'preço em faixas de consumo'; Mudanca = {
                    param($itens) $itens
                    $faixa = ($itens | Where-Object { $_.meterName -eq 'P15 LRS Disk' -and $_.productName -eq 'Premium SSD Managed Disks' }) | ConvertTo-Json | ConvertFrom-Json
                    $faixa.tierMinimumUnits = 100.0; $faixa.retailPrice = 300.0; $faixa
                } }
        ) {
            $dados = New-CopiaDosDados "dados-preco-$([guid]::NewGuid().ToString('N'))"
            Edit-Precos $dados $Mudanca
            $saida = Join-Path $TestDrive "saida-preco-$([guid]::NewGuid().ToString('N'))"

            Invoke-Relatorio -PastaDados $dados -Saida $saida | Out-Null

            $sobra = Get-Achado (Get-Achados $saida) 'disco-sobra-da-migracao'
            $sobra.Economia | Should -BeNullOrEmpty
            $sobra.EconomiaStatus | Should -Be 'nao-sei'
        }
    }

    Context 'Os nomes de medidor do App Service, conferidos na Retail Prices API real em 09/10' {
        It 'FIN-04 estima o plano <Caso>' -ForEach @(
            # O plano Basic Linux é o único em que o medidor não termina em " App": é só "B1".
            # O B1 em Windows é "B1 App". Preço fictício: R$ 0,10 por hora, 1 instância.
            @{ Caso = 'Basic B1 Linux, cujo medidor se chama só B1'; Colunas = @{ sku = 'B1'; camada = 'Basic'; so = 'Linux' }; Valor = 73 }
            # O P0v3 a API escreve sem espaço (P0v3), ao contrário do P1 v3. R$ 0,80 por hora.
            @{ Caso = 'P0v3 Windows, que a API escreve sem espaço'; Colunas = @{ sku = 'P0v3'; camada = 'PremiumV3'; so = 'Windows' }; Valor = 584 }
        ) {
            $dados = New-CopiaDosDados "dados-plano-$([guid]::NewGuid().ToString('N'))"
            Set-Colunas $dados 'FIN-04' 'plano-ficticio-site-antigo' $Colunas
            $saida = Join-Path $TestDrive "saida-plano-$([guid]::NewGuid().ToString('N'))"

            Invoke-Relatorio -PastaDados $dados -Saida $saida | Out-Null

            $plano = Get-Achado (Get-Achados $saida) 'plano-ficticio-site-antigo'
            $plano.EconomiaMotivo | Should -BeNullOrEmpty
            $plano.Economia | Should -Be $Valor
            $plano.EconomiaStatus | Should -Be 'estimada'
        }

        It 'o plano que a tabela de preços não tem fica com "não sei", e o motivo cita o produto e o SKU' {
            $dados = New-CopiaDosDados 'dados-plano-sem-preco'
            Set-Colunas $dados 'FIN-04' 'plano-ficticio-site-antigo' @{ sku = 'B2'; camada = 'Basic'; so = 'Linux' }
            $saida = Join-Path $TestDrive 'saida-plano-sem-preco'

            Invoke-Relatorio -PastaDados $dados -Saida $saida | Out-Null

            $plano = Get-Achado (Get-Achados $saida) 'plano-ficticio-site-antigo'
            $plano.EconomiaStatus | Should -Be 'nao-sei'
            $plano.EconomiaMotivo | Should -BeLike '*não tem esse medidor (Azure App Service Basic Plan - Linux, B2)*'
        }
    }

    Context 'Quando o Advisor informa a economia em outra moeda' {
        BeforeAll {
            # No ensaio de 09/10, uma recomendação do Advisor veio com a economia em outra moeda.
            $dados = New-CopiaDosDados 'dados-advisor-em-dolar'
            Set-Colunas $dados 'FIN-07' 'vm-ficticia-servidor-de-arquivos' @{ economiaAdvisor = 12.34; moeda = 'USD' }
            $saida = Join-Path $TestDrive 'saida-advisor-em-dolar'
            Invoke-Relatorio -PastaDados $dados -Saida $saida | Out-Null
            $achado = Get-Achado (Get-Achados $saida) 'vm-ficticia-servidor-de-arquivos'
        }

        It 'o achado fica com "não sei", porque o relatório não converte moeda, e mostra o valor e a moeda que o Advisor informou' {
            $achado.Economia | Should -BeNullOrEmpty
            $achado.EconomiaStatus | Should -Be 'nao-sei'
            $achado.EconomiaMotivo | Should -BeLike '*USD 12,34 informados pelo Advisor*não converte moeda*'
            Get-LinhaDoRecurso (Get-Html $saida) 'vm-ficticia-servidor-de-arquivos' | Should -BeLike '*não sei*USD 12,34 informados pelo Advisor*'
        }

        It 'o valor em outra moeda fica fora do total em R$' {
            # 2.730,55 - 412,50 = 2.318,05; o "não sei" vai de 15 para 16.
            $texto = Get-TextoVisivel (Get-Html $saida)
            $texto | Should -BeLike '*Economia estimada: R$ 2.318,05/mês*'
            $texto | Should -BeLike '*16 achados sem estimativa (não sei)*'
        }

        It 'no modo anonimizado, o valor informado também vai para a dezena' {
            $saidaAnonima = Join-Path $TestDrive 'saida-advisor-em-dolar-anonimizada'
            Invoke-Relatorio -PastaDados $dados -Saida $saidaAnonima -Parametros @{ Anonimizar = $true } | Out-Null

            $anonimo = Get-Achados $saidaAnonima | Where-Object { $_.Regra -eq 'FIN-07' -and $_.Detalhes.impacto -eq 'High' }
            $anonimo.EconomiaMotivo | Should -BeLike '*USD 10,00 informados pelo Advisor*'
            $anonimo.EconomiaMotivo | Should -Not -BeLike '*12,34*'
        }

        It 'sem a moeda, o achado fica com "não sei" e diz que o Advisor não informou a moeda' {
            $semMoeda = New-CopiaDosDados 'dados-advisor-sem-moeda'
            Set-Colunas $semMoeda 'FIN-07' 'vm-ficticia-servidor-de-arquivos' @{ economiaAdvisor = 12.34; moeda = '' }
            $saidaSemMoeda = Join-Path $TestDrive 'saida-advisor-sem-moeda'
            Invoke-Relatorio -PastaDados $semMoeda -Saida $saidaSemMoeda | Out-Null

            $semMoedaAchado = Get-Achado (Get-Achados $saidaSemMoeda) 'vm-ficticia-servidor-de-arquivos'
            $semMoedaAchado.EconomiaStatus | Should -Be 'nao-sei'
            $semMoedaAchado.EconomiaMotivo | Should -BeLike '*12,34*sem dizer a moeda*'
        }
    }

    Context 'Quando a KQL devolve o booleano como número ou como texto' {
        # No ensaio de 09/10, o Resource Graph devolveu a expressão booleana nuncaAnexado como 1 ou 0,
        # e não como true ou false. Um arquivo feito à mão pode trazer "true" ou "false".
        It 'o disco com nuncaAnexado = <Valor> está sendo cobrado, e a economia sai com preço' -ForEach @(
            @{ Valor = 0 }
            @{ Valor = '0' }
            @{ Valor = 'false' }
            @{ Valor = 'False' }
            @{ Valor = $false }
        ) {
            $dados = New-CopiaDosDados "dados-booleano-$([guid]::NewGuid().ToString('N'))"
            Set-Colunas $dados 'FIN-01' 'disco-sobra-da-migracao' @{ nuncaAnexado = $Valor }
            $saida = Join-Path $TestDrive "saida-booleano-$([guid]::NewGuid().ToString('N'))"

            Invoke-Relatorio -PastaDados $dados -Saida $saida | Out-Null

            $sobra = Get-Achado (Get-Achados $saida) 'disco-sobra-da-migracao'
            $sobra.Economia | Should -Be 340
            $sobra.EconomiaStatus | Should -Be 'estimada'
        }

        It 'o disco com nuncaAnexado = <Valor> foi criado vazio e nunca anexado: "não sei", e o motivo diz que o Azure ainda não cobra' -ForEach @(
            @{ Valor = 1 }
            @{ Valor = '1' }
            @{ Valor = 'true' }
            @{ Valor = $true }
        ) {
            $dados = New-CopiaDosDados "dados-nunca-anexado-$([guid]::NewGuid().ToString('N'))"
            Set-Colunas $dados 'FIN-01' 'disco-sobra-da-migracao' @{ nuncaAnexado = $Valor }
            $saida = Join-Path $TestDrive "saida-nunca-anexado-$([guid]::NewGuid().ToString('N'))"

            Invoke-Relatorio -PastaDados $dados -Saida $saida | Out-Null

            $sobra = Get-Achado (Get-Achados $saida) 'disco-sobra-da-migracao'
            $sobra.Economia | Should -BeNullOrEmpty
            $sobra.EconomiaStatus | Should -Be 'nao-sei'
            $sobra.EconomiaMotivo | Should -BeLike '*criado vazio e nunca*anexado*não cobra*'
            $sobra.EconomiaMotivo | Should -Not -BeLike '*ambíguo*'
        }

        It 'o disco com nuncaAnexado = <Valor>, que não é booleano, fica com "não sei" por medidor ambíguo' -ForEach @(
            @{ Valor = $null }
            @{ Valor = '' }
            @{ Valor = 'talvez' }
            @{ Valor = 2 }
        ) {
            $dados = New-CopiaDosDados "dados-nao-booleano-$([guid]::NewGuid().ToString('N'))"
            Set-Colunas $dados 'FIN-01' 'disco-sobra-da-migracao' @{ nuncaAnexado = $Valor }
            $saida = Join-Path $TestDrive "saida-nao-booleano-$([guid]::NewGuid().ToString('N'))"

            Invoke-Relatorio -PastaDados $dados -Saida $saida | Out-Null

            $sobra = Get-Achado (Get-Achados $saida) 'disco-sobra-da-migracao'
            $sobra.EconomiaStatus | Should -Be 'nao-sei'
            $sobra.EconomiaMotivo | Should -BeLike 'Medidor ambíguo*nuncaAnexado*'
        }
    }

    Context 'Quando o medidor é ambíguo' {
        It '<Caso>: fica com "não sei"' -ForEach @(
            @{ Caso = 'disco Premium SSD v2, cobrado por GB, IOPS e vazão'; Regra = 'FIN-01'; Recurso = 'disco-sobra-da-migracao'; Colunas = @{ sku = 'PremiumV2_LRS' } }
            @{ Caso = 'disco HDD de 8 GB, que cairia num S2 que não existe'; Regra = 'FIN-01'; Recurso = 'disco-sobra-da-migracao'; Colunas = @{ sku = 'Standard_LRS'; tamanhoGB = 8 } }
            @{ Caso = 'disco maior que o maior tier'; Regra = 'FIN-01'; Recurso = 'disco-sobra-da-migracao'; Colunas = @{ tamanhoGB = 40000 } }
            @{ Caso = 'IP dinâmico, que sem associação pode nem cobrar'; Regra = 'FIN-02'; Recurso = 'ip-ficticio-site-desativado'; Colunas = @{ sku = 'Basic'; alocacao = 'Dynamic' } }
            @{ Caso = 'IP da camada Global, que tem outro medidor'; Regra = 'FIN-02'; Recurso = 'ip-ficticio-site-desativado'; Colunas = @{ camada = 'Global' } }
            @{ Caso = 'plano de contêiner Windows'; Regra = 'FIN-04'; Recurso = 'plano-ficticio-homologacao'; Colunas = @{ so = 'Windows Container' } }
            @{ Caso = 'plano Isolated, de App Service Environment'; Regra = 'FIN-04'; Recurso = 'plano-ficticio-homologacao'; Colunas = @{ camada = 'IsolatedV2'; sku = 'I1v2' } }
            @{ Caso = 'plano sem a quantidade de instâncias'; Regra = 'FIN-04'; Recurso = 'plano-ficticio-homologacao'; Colunas = @{ instancias = $null } }
            @{ Caso = 'recomendação do Advisor em dólar'; Regra = 'FIN-07'; Recurso = 'vm-ficticia-servidor-de-arquivos'; Colunas = @{ moeda = 'USD' } }
            @{ Caso = 'recomendação do Advisor sem o valor'; Regra = 'FIN-07'; Recurso = 'vm-ficticia-servidor-de-arquivos'; Colunas = @{ economiaAdvisor = $null } }
        ) {
            $dados = New-CopiaDosDados "dados-ambiguo-$([guid]::NewGuid().ToString('N'))"
            Set-Colunas $dados $Regra $Recurso $Colunas
            $saida = Join-Path $TestDrive "saida-ambiguo-$([guid]::NewGuid().ToString('N'))"

            Invoke-Relatorio -PastaDados $dados -Saida $saida | Out-Null

            $achado = Get-Achado (Get-Achados $saida) $Recurso
            $achado.Economia | Should -BeNullOrEmpty
            $achado.EconomiaStatus | Should -Be 'nao-sei'
            $achado.EconomiaMotivo | Should -Not -BeNullOrEmpty
        }
    }
}
