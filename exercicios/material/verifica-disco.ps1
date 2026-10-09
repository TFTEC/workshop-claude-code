<#
    Material de prática dos exercícios 1, 2 e 3 do workshop.

    Lê o arquivo discos.csv (dados fictícios) e lista os discos com menos de 15% de espaço livre.
    Este script tem um bug de propósito. Deixe o bug onde está até o exercício 3.

    Como rodar, a partir da pasta do repositório:
        pwsh -File .\exercicios\material\verifica-disco.ps1
#>
param(
    [string]$Arquivo = (Join-Path $PSScriptRoot 'discos.csv')
)

$discos = Import-Csv -Path $Arquivo

Write-Output 'Discos com menos de 15% livre:'

foreach ($disco in $discos) {
    $percentualLivre = [int]$disco.LivreGB / [int]$disco.TamanhoGB * 100

    if ($percentualLivre -lt 15) {
        Write-Output ('  {0} {1} {2:N0}% livre' -f $disco.Servidor, $disco.Disco, $percentualLivre)
    }
}
