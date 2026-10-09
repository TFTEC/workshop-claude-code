<#
.SYNOPSIS
    Arquivo de exemplo do exercício 4 (CLAUDE.md e memória). Pode apagar depois do exercício.

.DESCRIPTION
    Quando o Claude lê este arquivo, ele carrega a regra .claude/rules/powershell-do-relatorio.md,
    porque o caminho relatorio/exemplo.ps1 casa com o glob relatorio/**/*.ps1 da regra.
    O arquivo segue as convenções da própria regra: ajuda em comentário, [CmdletBinding()],
    Set-StrictMode, $ErrorActionPreference = 'Stop' e UTF-8 com BOM.

.EXAMPLE
    ./relatorio/exemplo.ps1
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Output 'Olá do relatório FinOps'
