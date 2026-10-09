#requires -Version 7.0
<#
Testes do modo anonimizado do relatório FinOps (seam 1 da spec): o script roda de verdade
pelo ponto de entrada público, com a fonte Arquivo e -Anonimizar, e o teste confere só o que
sai dele: os arquivos da pasta de saída e o resumo na tela.

Os dados ficam numa pasta temporária: uma cópia de testes/dados/ com testes/dados-anonimizado/
por cima. Lá, FIN-01 tem nomes bem distintos (todos começam com "zz"), dois discos no mesmo
grupo de recursos e colunas de detalhe com nome, ID do Azure, GUID e valor em reais; FIN-02 tem
um IP público IPv4 e um IPv6 na coluna ip.

Nenhum comando do Azure é executado.

Rodar: pwsh -NoProfile -Command "Invoke-Pester -Path testes/relatorio.anonimizado.Tests.ps1 -Output Detailed"
#>

BeforeAll {
    # Os ajudantes comuns: Invoke-Relatorio (que devolve o que o script escreveu na tela, para
    # conferir que o resumo também não vaza), Get-Achados, Get-Html...
    . (Join-Path $PSScriptRoot 'Comum.ps1')

    # Aqui a subscription não é a de zeros, para provar que o GUID dela também some.
    $script:Sub = 'f1e2d3c4-b5a6-4789-8abc-def012345678'

    # Os dados de todas as regras, com os da anonimização por cima. Invoke-Relatorio usa esta pasta.
    $script:Dados = New-CopiaDosDados 'dados'
    Copy-Item -Path (Join-Path $PSScriptRoot 'dados-anonimizado/*.json') -Destination $script:Dados -Force

    # Os nomes originais: name, resourceGroup e subscriptionId de todas as linhas de todos os JSON
    # de dados, os IPs (ip e ipPrivado), a subscription do parâmetro, o GUID de detalhe e o snapshot
    # citado no ID. Só as respostas das regras (FIN-*.json): o precos.json é a tabela de preços, sem nomes.
    $script:Originais = @(
        foreach ($arquivo in Get-ChildItem -Path $script:Dados -Filter 'FIN-*.json') {
            foreach ($linha in @((Get-Content -Raw -Path $arquivo.FullName | ConvertFrom-Json).data)) {
                foreach ($coluna in 'name', 'resourceGroup', 'subscriptionId', 'ip', 'ipPrivado') {
                    if ($linha.PSObject.Properties[$coluna] -and $linha.$coluna) { [string]$linha.$coluna }
                }
            }
        }
        $script:Sub
        '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d'
        'zzsnap-backup-confidencial'
    ) | Sort-Object -Unique

    # Cada nome original que aparece num texto, sem diferenciar maiúsculas.
    function Find-Originais {
        param([string]$Texto)
        foreach ($original in $script:Originais) {
            if ($Texto.IndexOf($original, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $original }
        }
    }
}

Describe 'Relatório FinOps no modo anonimizado' {

    Context 'Com -Anonimizar' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-anonimizada'
            $tela = Invoke-Relatorio -Saida $saida -Parametros @{ Anonimizar = $true }
            $achados = @(Get-Achados $saida | Where-Object Regra -eq 'FIN-01')
            $html = Get-Html $saida
            # Os discos se reconhecem pelo tamanho, que não é nome e não muda.
            $alfa = $achados | Where-Object { $_.Detalhes.tamanhoGB -eq 512 }
            $beta = $achados | Where-Object { $_.Detalhes.tamanhoGB -eq 256 }
            $gama = $achados | Where-Object { $_.Detalhes.tamanhoGB -eq 128 }
        }

        It 'cada disco vira um rótulo com o prefixo da regra' {
            ($achados.Recurso | Sort-Object) | Should -Be @('disco-01', 'disco-02', 'disco-03')
        }

        It 'o mesmo grupo de recursos vira o mesmo rótulo, e grupos diferentes, rótulos diferentes' {
            $alfa.GrupoDeRecursos | Should -Match '^rg-\d\d$'
            $gama.GrupoDeRecursos | Should -Match '^rg-\d\d$'
            $beta.GrupoDeRecursos | Should -Be $alfa.GrupoDeRecursos
            $gama.GrupoDeRecursos | Should -Not -Be $alfa.GrupoDeRecursos
        }

        It 'a subscription vira sub-01' {
            $achados.Subscription | Sort-Object -Unique | Should -Be 'sub-01'
        }

        It 'um detalhe igual a um nome original vira o rótulo desse nome' {
            $beta.Detalhes.copiaDe | Should -Be $alfa.Recurso
        }

        It 'um detalhe com ID do Azure, GUID ou nome original no meio do texto fica oculto' {
            $alfa.Detalhes.origem | Should -Be '<oculto>'
            $alfa.Detalhes.donoId | Should -Be '<oculto>'
            $gama.Detalhes.observacao | Should -Be '<oculto>'
        }

        It 'um IP público nos detalhes, IPv4 ou IPv6, fica oculto' {
            $ips = @(Get-Achados $saida | Where-Object Regra -eq 'FIN-02')
            $ips | Should -HaveCount 2
            ($ips.Detalhes.versao | Sort-Object) | Should -Be @('IPv4', 'IPv6')
            foreach ($ip in $ips) { $ip.Detalhes.ip | Should -Be '<oculto>' }
        }

        It 'os outros detalhes continuam como estão' {
            $alfa.Detalhes.sku | Should -Be 'Premium_LRS'
            $alfa.Detalhes.tamanhoGB | Should -Be 512
            $alfa.Local | Should -Be 'brazilsouth'
        }

        It 'nenhum arquivo da pasta de saída contém um nome original' {
            $arquivos = @(Get-ChildItem -Path $saida -Recurse -File)
            $arquivos.Name | Should -Contain 'achados.json'
            $arquivos.Name | Should -Contain 'relatorio-finops.html'
            $vazamentos = foreach ($arquivo in $arquivos) {
                $texto = Get-Content -Raw -Encoding UTF8 -Path $arquivo.FullName
                foreach ($original in Find-Originais $texto) { "$($arquivo.Name): $original" }
            }
            $vazamentos | Should -BeNullOrEmpty
        }

        It 'o resumo na tela avisa o modo e também não mostra nome original' {
            $tela | Should -BeLike '*FIN-01*'
            $tela | Should -BeLike '*Modo anonimizado*'
            Find-Originais $tela | Should -BeNullOrEmpty
        }

        It 'o HTML mostra a subscription como sub-01' {
            $html | Should -BeLike '*<code>sub-01</code>*'
        }

        It 'os valores em reais são arredondados para a dezena mais próxima' {
            $alfa.Detalhes.custoMensalBRL | Should -Be 120
            $beta.Detalhes.custoMensalBRL | Should -Be 130
            $gama.Detalhes.custoMensalBRL | Should -Be 90
        }

        It 'o HTML mostra o selo "Modo anonimizado"' {
            $html | Should -Match '<[^>]*class="selo-anonimizado"[^>]*>\s*Modo anonimizado'
        }
    }

    Context 'Com -Anonimizar, num ambiente sem achados' {
        It 'grava achados.json como uma lista vazia e o HTML com "Nenhum achado"' {
            $saida = Join-Path $TestDrive 'saida-anonimizada-vazia'

            Invoke-Relatorio -PastaDados $script:DadosSemAchados -Saida $saida -Parametros @{ Anonimizar = $true } | Out-Null

            (Get-Content -Raw -Path (Join-Path $saida 'achados.json')).Trim() | Should -Be '[]'
            $html = Get-Html $saida
            $html | Should -BeLike '*Nenhum achado*'
            $html | Should -BeLike '*<code>sub-01</code>*'
        }
    }

    Context 'Regra sem o campo Rotulo' {
        It 'o recurso vira recurso-01, recurso-02...' {
            # Uma cópia do script com um catálogo de uma regra só, sem Rotulo.
            $copia = New-ScriptComCatalogo @'
@{ Id = 'FIN-01'; Titulo = 'Regra sem rótulo'; Severidade = 'Baixa'; Kql = 'resources'; Economia = 'nao-sei' }
'@
            $saida = Join-Path $TestDrive 'saida-sem-rotulo'

            Invoke-Relatorio -Script $copia -Saida $saida -Parametros @{ Anonimizar = $true } | Out-Null

            ((Get-Achados $saida).Recurso | Sort-Object) | Should -Be @('recurso-01', 'recurso-02', 'recurso-03')
        }
    }

    Context 'Sem -Anonimizar, com os mesmos dados' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-normal'
            Invoke-Relatorio -Saida $saida | Out-Null
            $textoAchados = Get-Content -Raw -Encoding UTF8 -Path (Join-Path $saida 'achados.json')
            $html = Get-Html $saida
        }

        It 'os nomes originais aparecem no achados.json e no HTML' {
            foreach ($nome in 'zzdisco-sigiloso-alfa', 'zzdisco-sigiloso-beta', 'zzdisco-sigiloso-gama',
                'zzrg-cliente-secreto', 'zzrg-projeto-ultrasecreto', $script:Sub) {
                $textoAchados | Should -BeLike "*$nome*"
                $html | Should -BeLike "*$nome*"
            }
        }

        It 'os valores em reais ficam exatos' {
            $alfa = Get-Achados $saida | Where-Object { $_.Detalhes.tamanhoGB -eq 512 }
            $alfa.Detalhes.custoMensalBRL | Should -Be 123.45
        }

        It 'o HTML não mostra o selo do modo anonimizado' {
            $html | Should -Not -BeLike '*Modo anonimizado*'
        }
    }
}
