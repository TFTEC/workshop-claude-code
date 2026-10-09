#requires -Version 7.0
<#
Testes das 7 regras do núcleo do relatório FinOps (seam 1 da spec): o script roda de verdade
pelo ponto de entrada público, com a fonte Arquivo, e o teste confere só o que sai dele:
achados.json e relatorio-finops.html.

Cada regra tem dois JSON, no formato de `az graph query -o json`:
- testes/dados/FIN-xx.json: a resposta da KQL com recursos que disparam a regra;
- testes/dados-sem-achados/FIN-xx.json: a resposta vazia, que é o caso "não dispara".
Quem filtra é a KQL; o filtro só é validado no ensaio, contra o Azure real.

Nenhum comando do Azure é executado.

Rodar: pwsh -NoProfile -Command "Invoke-Pester -Path testes/relatorio.regras.Tests.ps1 -Output Detailed"
#>

BeforeDiscovery {
    # O que cada regra deve apontar com os dados fictícios de testes/dados/.
    $regrasDoNucleo = @(
        @{
            Id = 'FIN-01'; Titulo = 'Disco que não está ligado a nenhuma VM'; Severidade = 'Alta'
            Recursos = @('disco-copia-antiga-do-banco', 'disco-esquecido-vm-teste', 'disco-sobra-da-migracao')
        }
        @{
            Id = 'FIN-02'; Titulo = 'IP público que não está ligado a nada'; Severidade = 'Média'
            Recursos = @('ip-ficticio-site-desativado', 'ip-ficticio-sobra-do-teste')
        }
        @{
            Id = 'FIN-03'; Titulo = 'VM desligada que continua pagando pelos discos'; Severidade = 'Média'
            Recursos = @('vm-ficticia-relatorios-mensais', 'vm-ficticia-teste-de-carga')
        }
        @{
            Id = 'FIN-04'; Titulo = 'Plano do App Service pago e sem nenhum app'; Severidade = 'Alta'
            Recursos = @('plano-ficticio-homologacao', 'plano-ficticio-site-antigo')
        }
        @{
            # Sem -DiasSnapshot, o limiar é o padrão: 30 dias.
            Id = 'FIN-05'; Titulo = 'Snapshot com mais de 30 dias'; Severidade = 'Baixa'
            Recursos = @('snapshot-ficticio-antes-da-atualizacao', 'snapshot-ficticio-backup-manual')
        }
        @{
            Id = 'FIN-06'; Titulo = 'Log Analytics guardando dados por mais de 90 dias ou sem limite diário'; Severidade = 'Média'
            Recursos = @('log-ficticio-central', 'log-ficticio-laboratorio')
        }
        @{
            Id = 'FIN-07'; Titulo = 'Economia que o Azure Advisor já recomenda'; Severidade = 'Média'
            Recursos = @('vm-ficticia-servidor-de-arquivos', 'banco-ficticio-relatorios')
        }
    )
}

BeforeAll {
    # Os caminhos padrão e os ajudantes comuns: Invoke-Relatorio (com -Parametros para os
    # parâmetros extras, como @{ DiasSnapshot = 45 }), Get-Achados, Get-Html, Get-BlocoDaRegra...
    . (Join-Path $PSScriptRoot 'Comum.ps1')
}

Describe 'Relatório FinOps: as 7 regras do núcleo' {

    Context 'Com os dados fictícios, em que toda regra dispara' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-com-achados'
            Invoke-Relatorio -Saida $saida
            $achados = Get-Achados $saida
            $html = Get-Html $saida
        }

        It '<Id> aponta cada recurso que veio na resposta da KQL' -ForEach $regrasDoNucleo {
            $daRegra = @($achados | Where-Object Regra -eq $Id)
            @($daRegra.Recurso | Sort-Object) | Should -Be @($Recursos | Sort-Object)
        }

        It 'cada achado de <Id> traz o título, a severidade, o grupo de recursos e a subscription' -ForEach $regrasDoNucleo {
            $daRegra = @($achados | Where-Object Regra -eq $Id)
            $daRegra | Should -Not -BeNullOrEmpty
            foreach ($achado in $daRegra) {
                $achado.Titulo | Should -Be $Titulo
                $achado.Severidade | Should -Be $Severidade
                $achado.GrupoDeRecursos | Should -BeLike 'rg-ficticio-*'
                $achado.Subscription | Should -Be '00000000-0000-0000-0000-000000000000'
            }
        }

        It 'o HTML tem um bloco de <Id> com o título, a contagem e cada recurso apontado' -ForEach $regrasDoNucleo {
            $bloco = Get-BlocoDaRegra $html $Id
            $bloco | Should -Not -BeNullOrEmpty
            $bloco | Should -BeLike "*$Titulo*"
            $bloco | Should -BeLike "*$($Recursos.Count) achado*"
            foreach ($recurso in $Recursos) { $bloco | Should -BeLike "*$recurso*" }
            $bloco | Should -BeLike '*Ver a KQL desta regra*'
        }

        It 'FIN-07 guarda nos detalhes a economia que o próprio Advisor informa, com a moeda' {
            $achado = $achados | Where-Object { $_.Regra -eq 'FIN-07' -and $_.Recurso -eq 'vm-ficticia-servidor-de-arquivos' }
            $achado.Detalhes.economiaAdvisor | Should -Be 412.5
            $achado.Detalhes.moeda | Should -Be 'BRL'
        }
    }

    Context 'Com a resposta vazia de cada regra' {
        BeforeAll {
            $saida = Join-Path $TestDrive 'saida-sem-achados'
            Invoke-Relatorio -PastaDados $script:DadosSemAchados -Saida $saida
            $textoAchados = Get-Content -Raw -Path (Join-Path $saida 'achados.json')
            $html = Get-Html $saida
        }

        It 'grava achados.json como uma lista vazia' {
            $textoAchados.Trim() | Should -Be '[]'
        }

        It 'o HTML mostra <Id> verificada, com "Nenhum achado"' -ForEach $regrasDoNucleo {
            $bloco = Get-BlocoDaRegra $html $Id
            $bloco | Should -Not -BeNullOrEmpty
            $bloco | Should -BeLike "*$Titulo*"
            $bloco | Should -BeLike '*Nenhum achado*'
        }
    }

    Context 'Limiar de dias do snapshot (FIN-05)' {
        It 'sem -DiasSnapshot, a KQL de FIN-05 exibida no HTML usa 30 dias' {
            $saida = Join-Path $TestDrive 'saida-snapshot-padrao'
            Invoke-Relatorio -Saida $saida

            $bloco = Get-BlocoDaRegra (Get-Html $saida) 'FIN-05'
            $bloco | Should -BeLike '*ago(30d)*'
            $bloco | Should -BeLike '*Snapshot com mais de 30 dias*'
        }

        It 'com -DiasSnapshot 45, a KQL de FIN-05 exibida no HTML usa 45 dias, e o título acompanha' {
            $saida = Join-Path $TestDrive 'saida-snapshot-45'
            Invoke-Relatorio -Saida $saida -Parametros @{ DiasSnapshot = 45 }

            $bloco = Get-BlocoDaRegra (Get-Html $saida) 'FIN-05'
            $bloco | Should -BeLike '*ago(45d)*'
            $bloco | Should -Not -BeLike '*ago(30d)*'
            $bloco | Should -BeLike '*Snapshot com mais de 45 dias*'
            @(Get-Achados $saida | Where-Object Regra -eq 'FIN-05').Titulo | Should -Be @('Snapshot com mais de 45 dias', 'Snapshot com mais de 45 dias')
        }

        It 'recusa -DiasSnapshot <Dias>, que apontaria todo snapshot, e não grava nada' -ForEach @(
            @{ Dias = 0 }
            @{ Dias = -5 }
        ) {
            $saida = Join-Path $TestDrive "saida-snapshot-invalido-$Dias"

            { Invoke-Relatorio -Saida $saida -Parametros @{ DiasSnapshot = $Dias } } | Should -Throw '*DiasSnapshot*'

            $saida | Should -Not -Exist
        }
    }
}
