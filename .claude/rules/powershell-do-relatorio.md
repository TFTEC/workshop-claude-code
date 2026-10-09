---
paths:
  - "relatorio/**/*.ps1"
  - "relatorio/**/*.psd1"
---

# Convenções de PowerShell do relatório FinOps

- O script roda no PowerShell 7 e, sempre que possível, também no Windows PowerShell 5.1. Não use recursos só do 7, como `??`, `?.` e o operador ternário.
- Todo script começa com a ajuda em comentário (`.SYNOPSIS`, `.PARAMETER`, `.EXAMPLE`), em português.
- Use `[CmdletBinding()]`, `Set-StrictMode -Version Latest` e `$ErrorActionPreference = 'Stop'`.
- Funções usam verbos aprovados do PowerShell (`Get-`, `ConvertTo-`, `New-`) e substantivos em português, como `Get-Catalogo`.
- Cada regra FinOps é um arquivo `relatorio/regras/FIN-xx.psd1`, com ID, título, KQL, severidade e a forma de estimar a economia.
- O Azure só é lido com `az graph query`, `az account show` e GET na Retail Prices API.
- Sem preço confiável, a economia é "não sei", nunca 0 nem um valor chutado.
- Leia arquivos com `-Encoding UTF8`. Os scripts (`.ps1` e `.psd1`) ficam em UTF-8 com BOM, para o Windows PowerShell 5.1 ler os acentos; as saídas do relatório (HTML e JSON) são gravadas em UTF-8 sem BOM.
