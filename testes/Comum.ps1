<#
Ajudantes comuns dos testes do relatório FinOps. Cada arquivo de teste carrega este arquivo por
dot-source, no começo do BeforeAll:

    . (Join-Path $PSScriptRoot 'Comum.ps1')

Ele define os caminhos padrão ($script:Relatorio, $script:Dados, $script:DadosSemAchados) e a
subscription fictícia ($script:Sub), e as funções que rodam o relatório pelo ponto de entrada
público e leem o que ele grava. Um arquivo que precise de outros dados troca a variável depois do
dot-source: o do modo anonimizado usa outra subscription e uma pasta de dados temporária.

Não é um arquivo de teste: o Pester só roda os *.Tests.ps1.
#>

$script:Relatorio = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../relatorio/Invoke-RelatorioFinOps.ps1'))
$script:Dados = Join-Path $PSScriptRoot 'dados'
$script:DadosSemAchados = Join-Path $PSScriptRoot 'dados-sem-achados'
$script:Sub = '00000000-0000-0000-0000-000000000000'

# Roda o relatório com a fonte Arquivo e devolve o que ele escreveu na tela: o resumo (Write-Host)
# e os avisos (Write-Warning). -Parametros leva os parâmetros extras, como @{ DiasSnapshot = 45 }
# ou @{ Anonimizar = $true }; -Script, uma cópia do script com um catálogo de teste.
function Invoke-Relatorio {
    param(
        [string]$PastaDados = $script:Dados,
        [string]$Saida,
        [hashtable]$Parametros = @{},
        [string]$Script = $script:Relatorio
    )
    & $Script -SubscriptionId $script:Sub -Fonte Arquivo -PastaDados $PastaDados -Saida $Saida @Parametros 6>&1 3>&1 | Out-String
}

# Os achados que o relatório gravou em achados.json.
function Get-Achados {
    param([string]$Saida)
    @(Get-Content -Raw -Path (Join-Path $Saida 'achados.json') | ConvertFrom-Json)
}

# O achado de um recurso, pelo nome.
function Get-Achado {
    param($Achados, [string]$Recurso)
    $Achados | Where-Object Recurso -eq $Recurso
}

# O HTML que o relatório gravou.
function Get-Html {
    param([string]$Saida)
    Get-Content -Raw -Encoding UTF8 -Path (Join-Path $Saida 'relatorio-finops.html')
}

# O texto que a pessoa lê no navegador: sem as tags e com os espaços juntados.
function Get-TextoVisivel {
    param([string]$Html)
    $semEstilo = [regex]::Replace($Html, '(?s)<style>.*?</style>', ' ')
    ([regex]::Replace($semEstilo, '<[^>]+>', '') -replace '\s+', ' ').Trim()
}

# O texto visível da linha da tabela de achados de um recurso.
function Get-LinhaDoRecurso {
    param([string]$Html, [string]$Recurso)
    $linha = [regex]::Match($Html, "(?s)<tr>(?:(?!</tr>).)*>$([regex]::Escape($Recurso))<(?:(?!</tr>).)*</tr>")
    if ($linha.Success) { Get-TextoVisivel $linha.Value } else { $null }
}

# O bloco de uma regra no HTML: a seção com o id da regra, do cabeçalho até a KQL.
function Get-BlocoDaRegra {
    param([string]$Html, [string]$Id)
    $bloco = [regex]::Match($Html, "(?s)<section\b[^>]*\bid=""$Id""[^>]*>.*?</section>")
    if ($bloco.Success) { $bloco.Value } else { $null }
}

# Uma cópia dos dados fictícios (com a tabela de preços) numa pasta temporária, para o teste mexer.
function New-CopiaDosDados {
    param([string]$Nome, [string]$De = $script:Dados)
    $pasta = Join-Path $TestDrive $Nome
    New-Item -ItemType Directory -Path $pasta | Out-Null
    Copy-Item -Path (Join-Path $De '*.json') -Destination $pasta
    $pasta
}

# Uma cópia do script numa pasta temporária, com um catálogo de uma regra só: o texto do .psd1 da
# regra FIN-01. Devolve o caminho do script copiado, para Invoke-Relatorio -Script.
function New-ScriptComCatalogo {
    param([string]$Regra)
    $pasta = Join-Path $TestDrive "catalogo-$([guid]::NewGuid().ToString('N'))/relatorio"
    New-Item -ItemType Directory -Path (Join-Path $pasta 'regras') -Force | Out-Null
    Copy-Item -Path $script:Relatorio -Destination $pasta
    Set-Content -Path (Join-Path $pasta 'regras/FIN-01.psd1') -Encoding utf8BOM -Value $Regra
    Join-Path $pasta 'Invoke-RelatorioFinOps.ps1'
}
