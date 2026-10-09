#requires -Version 7.0
<#
Testes do relatório FinOps (seam 1 da spec): o script roda de verdade pelo ponto de entrada
público, com a fonte Arquivo, e o teste confere só o que sai dele: achados.json,
relatorio-finops.html e as mensagens de erro.

Os JSON em testes/dados/ são a resposta que o Azure daria à KQL de cada regra, no mesmo
formato de `az graph query -o json`. Quem filtra é a KQL; o script não refaz o filtro.
Por isso o caso "não dispara" é a resposta vazia em testes/dados-sem-achados/: é o que
o Azure devolve quando todos os discos estão anexados. Ver relatorio/README.md.

Nenhum comando do Azure é executado.

Rodar: pwsh -NoProfile -Command "Invoke-Pester -Path testes/relatorio.Tests.ps1 -Output Detailed"
#>

BeforeAll {
    # Os caminhos padrão e os ajudantes comuns: Invoke-Relatorio, Get-Achados, Get-Html...
    . (Join-Path $PSScriptRoot 'Comum.ps1')
}

Describe 'Relatório FinOps com a fonte Arquivo' {

    Context 'FIN-01: disco não anexado, com discos soltos na resposta' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-com-achados'
            Invoke-Relatorio -Saida $saida
            $achados = @(Get-Achados $saida | Where-Object Regra -eq 'FIN-01')
            $html = Get-Html $saida
        }

        It 'grava em achados.json um achado para cada disco solto' {
            $achados | Should -HaveCount 3
            ($achados.Recurso | Sort-Object) | Should -Be @('disco-copia-antiga-do-banco', 'disco-esquecido-vm-teste', 'disco-sobra-da-migracao')
        }

        It 'cada achado traz regra, título, severidade, recurso, grupo de recursos, subscription e local' {
            $achado = $achados | Where-Object Recurso -eq 'disco-esquecido-vm-teste'
            $achado.Regra | Should -Be 'FIN-01'
            $achado.Titulo | Should -Be 'Disco que não está ligado a nenhuma VM'
            $achado.Severidade | Should -Be 'Alta'
            $achado.GrupoDeRecursos | Should -Be 'rg-ficticio-laboratorio'
            $achado.Subscription | Should -Be '00000000-0000-0000-0000-000000000000'
            $achado.Local | Should -Be 'brazilsouth'
        }

        It 'as outras colunas da KQL viram detalhes do achado' {
            $achado = $achados | Where-Object Recurso -eq 'disco-esquecido-vm-teste'
            $achado.Detalhes.sku | Should -Be 'Standard_LRS'
            $achado.Detalhes.tamanhoGB | Should -Be 128
        }

        It 'grava relatorio-finops.html com o título, a subscription e cada disco solto' {
            $html | Should -BeLike '*Relatório FinOps*'
            $html | Should -BeLike '*00000000-0000-0000-0000-000000000000*'
            $html | Should -BeLike '*FIN-01*'
            $html | Should -BeLike '*Disco que não está ligado a nenhuma VM*'
            foreach ($disco in 'disco-copia-antiga-do-banco', 'disco-esquecido-vm-teste', 'disco-sobra-da-migracao') {
                $html | Should -BeLike "*$disco*"
            }
            $html | Should -BeLike '*rg-ficticio-loja-online*'
        }

        It 'o HTML é autocontido: sem CDN, sem folha de estilo nem script de fora' {
            $html | Should -Not -Match '<link\b'
            $html | Should -Not -Match '\b(src|href)\s*=\s*["'']?\s*(https?:)?//'
            $html | Should -Not -Match '@import|url\(\s*["'']?\s*(https?:)?//'
            $html | Should -Match '<style>'
        }
    }

    Context 'FIN-01: disco não anexado, num ambiente com todos os discos anexados' {
        # A KQL só devolve disco com diskState Unattached; com todos anexados, a resposta vem vazia.
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-sem-achados'
            Invoke-Relatorio -PastaDados $script:DadosSemAchados -Saida $saida
            $textoAchados = Get-Content -Raw -Path (Join-Path $saida 'achados.json')
            $html = Get-Html $saida
        }

        It 'grava achados.json como uma lista vazia' {
            $textoAchados.Trim() | Should -Be '[]'
        }

        It 'o HTML mostra a regra verificada, sem nenhum achado' {
            $html | Should -BeLike '*FIN-01*'
            $html | Should -BeLike '*Nenhum achado*'
        }
    }

    Context 'Caracteres especiais nos dados' {
        It 'o HTML escapa os valores, para que nenhum nome vire código na página' {
            # Copia os dados fictícios e troca a resposta de FIN-01 por uma com caracteres de HTML.
            $dados = New-CopiaDosDados 'dados-especiais'
            @{
                count = 1; skip_token = $null; total_records = 1
                data  = @(@{
                        name = 'disco-<script>alert(1)</script>'; resourceGroup = 'rg-teste&cia'
                        subscriptionId = $script:Sub; location = 'brazilsouth'; sku = '"Premium" <LRS>'
                    })
            } | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $dados 'FIN-01.json') -Encoding utf8
            $saida = Join-Path $TestDrive 'saida-especiais'

            Invoke-Relatorio -PastaDados $dados -Saida $saida

            $html = Get-Html $saida
            $html | Should -BeLike '*disco-&lt;script&gt;alert(1)&lt;/script&gt;*'
            $html | Should -BeLike '*rg-teste&amp;cia*'
            $html | Should -BeLike '*&quot;Premium&quot; &lt;LRS&gt;*'
            $html | Should -Not -BeLike '*<script>*'
        }
    }

    Context 'Pasta de dados sem o JSON de uma regra' {
        It 'para dizendo qual arquivo falta, em vez de dizer que não há desperdício' {
            $vazia = Join-Path $TestDrive 'dados-faltando'
            New-Item -ItemType Directory -Path $vazia | Out-Null
            $saida = Join-Path $TestDrive 'saida-faltando'

            { Invoke-Relatorio -PastaDados $vazia -Saida $saida } | Should -Throw '*FIN-01.json*-PastaDados*'

            $saida | Should -Not -Exist
        }
    }

    # A fonte Azure é testada à parte, em testes/relatorio.azure.Tests.ps1, com um az falso no PATH.

    Context 'Pasta de saída' {
        It 'cria a pasta de saída quando ela ainda não existe' {
            $saida = Join-Path $TestDrive 'nao/existe/ainda'
            Test-Path $saida | Should -BeFalse

            Invoke-Relatorio -Saida $saida

            Join-Path $saida 'achados.json' | Should -Exist
        }
    }
}
