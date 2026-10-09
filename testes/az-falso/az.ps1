<#
az falso: faz o papel do Azure CLI nos testes da fonte Azure (testes/relatorio.azure.Tests.ps1).
Nunca fala com o Azure: devolve respostas enlatadas.

Os testes não põem esta pasta no PATH. Eles geram, numa pasta temporária, um lançador chamado
az.cmd (no Windows) ou az (no macOS e no Linux) que chama este script com o pwsh, e põem só essa
pasta na frente do PATH. Assim, o relatório roda o az falso como roda o de verdade: um processo à
parte, que no Windows passa pelo cmd.exe.

Só responde aos três comandos de leitura que o relatório pode usar: account show, extension show
e graph query. A única exceção é a consulta de custo do bônus (-CustoReal): az rest --method post
em https://management.azure.com/subscriptions/<id>/providers/Microsoft.CostManagement/query, que é
leitura apesar do POST. Qualquer outro comando, inclusive outro az rest, fica registrado no log e
falha, e o teste aponta.

Variáveis de ambiente:
  AZ_FALSO_LOG      arquivo onde cada chamada vira uma linha JSON: {"args": [...]}. Na consulta de
                    custo, a linha traz também "body", o texto do corpo que veio em --body @arquivo.
  AZ_FALSO_DADOS    pasta com as respostas enlatadas:
                    - a resposta da KQL de cada regra, no formato de `az graph query -o json`:
                      <Id>.json é a primeira página; <Id>.<skip_token>.json é a página que esse skip token pede;
                    - a resposta da consulta de custo, no formato do Cost Management: custo-real.json é a
                      primeira página; custo-real.<skip_token>.json é a que --url-parameters $skiptoken=<skip_token> pede.
  AZ_FALSO_CENARIO  normal (padrão), sem-extensao, sem-login, erro-na-consulta, sem-permissao-de-custo
                    (a consulta de custo falha com AuthorizationFailed, como sem o papel Cost Management Reader),
                    custo-429-uma-vez (a primeira consulta de custo falha com 429 Too Many Requests, e as
                    seguintes respondem; conta pelo log) ou custo-429-sempre (toda consulta de custo dá 429).

A única subscription que este az enxerga é 00000000-0000-0000-0000-000000000000.
#>
$ErrorActionPreference = 'Stop'
$argumentos = @($args | ForEach-Object { [string]$_ })
$subscriptionConhecida = '00000000-0000-0000-0000-000000000000'
$cenario = if ($env:AZ_FALSO_CENARIO) { $env:AZ_FALSO_CENARIO } else { 'normal' }

if ($env:AZ_FALSO_LOG) {
    $registro = [ordered]@{ args = $argumentos }
    # O corpo da consulta de custo vem num arquivo (--body @arquivo): o log guarda o texto dele.
    $iCorpo = [array]::IndexOf($argumentos, '--body')
    if ($iCorpo -ge 0 -and $iCorpo + 1 -lt $argumentos.Count -and $argumentos[$iCorpo + 1].StartsWith('@')) {
        $arquivoDoCorpo = $argumentos[$iCorpo + 1].Substring(1)
        if (Test-Path -LiteralPath $arquivoDoCorpo -PathType Leaf) { $registro.body = Get-Content -Raw -LiteralPath $arquivoDoCorpo }
    }
    Add-Content -LiteralPath $env:AZ_FALSO_LOG -Value ($registro | ConvertTo-Json -Compress) -Encoding utf8
}

# Escreve no stderr, como o az de verdade, e sai com o código dado.
function Exit-ComErro {
    param([string]$Texto, [int]$Codigo = 1)
    [Console]::Error.WriteLine($Texto)
    exit $Codigo
}

# O valor que vem depois de um parâmetro (por exemplo, o de --subscriptions); $null se não veio.
function Get-Valor {
    param([string[]]$Nomes)
    for ($i = 0; $i -lt $argumentos.Count - 1; $i++) {
        if ($Nomes -contains $argumentos[$i]) { return $argumentos[$i + 1] }
    }
    $null
}

function Get-TextoNormalizado {
    param([string]$Texto)
    ($Texto -replace '\s+', ' ').Trim()
}

# Os marcadores {{Nome}} do catálogo (ex.: {{DiasSnapshot}}) chegam aqui já trocados pelo valor
# do parâmetro, então valem como "qualquer texto" na comparação.
function Test-KqlDaRegra {
    param([string]$KqlDoCatalogo, [string]$KqlRecebida)
    $partes = (Get-TextoNormalizado $KqlDoCatalogo) -split '\{\{\w+\}\}'
    $padrao = '^' + (($partes | ForEach-Object { [regex]::Escape($_) }) -join '.+?') + '$'
    (Get-TextoNormalizado $KqlRecebida) -match $padrao
}

$comando = ($argumentos | Select-Object -First 2) -join ' '

switch ($comando) {
    'extension show' {
        if ($cenario -eq 'sem-extensao') { Exit-ComErro "ERROR: The extension $(Get-Valor '--name', '-n') is not installed." }
        @{ name = 'resource-graph'; version = '2.1.1'; extensionType = 'whl'; preview = $false } | ConvertTo-Json
        exit 0
    }

    'account show' {
        if ($cenario -eq 'sem-login') { Exit-ComErro "ERROR: Please run 'az login' to setup account." }
        $pedida = Get-Valor '--subscription', '-s'
        if ($pedida -and $pedida -ne $subscriptionConhecida) {
            Exit-ComErro "ERROR: Subscription '$pedida' not found. Check the spelling and casing and try again."
        }
        [ordered]@{
            environmentName = 'AzureCloud'
            id              = $subscriptionConhecida
            isDefault       = $true
            name            = 'Assinatura ficticia do laboratorio'
            state           = 'Enabled'
            tenantId        = '00000000-0000-0000-0000-000000000000'
            user            = [ordered]@{ name = 'aluno@exemplo.com'; type = 'user' }
        } | ConvertTo-Json
        exit 0
    }

    'graph query' {
        $kql = Get-Valor '--graph-query', '-q'
        if (-not $kql) { Exit-ComErro 'ERROR: the following arguments are required: --graph-query/--q/-q' 2 }
        if ($kql -match '\n') {
            Exit-ComErro 'az falso: a KQL chegou com quebra de linha. No Windows, o az.cmd corta o argumento na primeira linha.'
        }

        if ($cenario -eq 'erro-na-consulta') {
            Exit-ComErro @'
ERROR: (BadRequest) Please provide below info when asking for support: timestamp = 2026-10-08T12:00:00.0000000Z, correlationId = 00000000-0000-0000-0000-000000000000.
Code: BadRequest
Message: Please provide below info when asking for support: timestamp = 2026-10-08T12:00:00.0000000Z, correlationId = 00000000-0000-0000-0000-000000000000.
Exception Details:	(InvalidQuery) Query is invalid. Please refer to the documentation for the Azure Resource Graph service and fix the error before retrying.
	Code: InvalidQuery
	Message: Query is invalid. Please refer to the documentation for the Azure Resource Graph service and fix the error before retrying.
	(UnknownFunction) Unknown function: 'todatetimex'.
	Code: UnknownFunction
	Message: Unknown function: 'todatetimex'.
Additional Information:Type: ErrorDetails
Info: {
    "code": "UnknownFunction",
    "message": "Unknown function: 'todatetimex'.",
    "additionalProperties": { "line": 1, "characterPositionInLine": 180 }
}
'@
        }

        # Descobre de qual regra é a KQL comparando com o catálogo, sem ligar para espaços e quebras de linha.
        $pastaRegras = Join-Path $PSScriptRoot '../../relatorio/regras'
        $regra = Get-ChildItem -Path $pastaRegras -Filter 'FIN-*.psd1' |
            ForEach-Object { Import-PowerShellDataFile -Path $_.FullName } |
            Where-Object { Test-KqlDaRegra -KqlDoCatalogo $_.Kql -KqlRecebida $kql } |
            Select-Object -First 1
        if (-not $regra) { Exit-ComErro "ERROR: (InvalidQuery) az falso: a KQL não é de nenhuma regra do catálogo: $kql" }

        $skipToken = Get-Valor '--skip-token'
        $nome = if ($skipToken) { "$($regra.Id).$skipToken.json" } else { "$($regra.Id).json" }
        $arquivo = Join-Path $env:AZ_FALSO_DADOS $nome
        if (-not (Test-Path -LiteralPath $arquivo -PathType Leaf)) {
            Exit-ComErro "ERROR: (InvalidSkipToken) az falso: não há resposta enlatada em $arquivo"
        }
        Get-Content -Raw -Encoding UTF8 -LiteralPath $arquivo
        exit 0
    }

    { $argumentos[0] -eq 'rest' } {
        # Só a consulta de custo do bônus passa: POST em .../providers/Microsoft.CostManagement/query.
        # Qualquer outro método ou endereço é tratado como comando fora da lista.
        $metodo = Get-Valor '--method', '-m'
        $url = Get-Valor '--url', '--uri', '-u'
        $consulta = '^https://management\.azure\.com/subscriptions/([^/]+)/providers/Microsoft\.CostManagement/query\?api-version=[\w.-]+$'
        if ($metodo -ne 'post' -or $url -notmatch $consulta) {
            Exit-ComErro "az falso: comando fora da lista de leitura (account show, extension show, graph query e o POST da consulta de custo): az $($argumentos -join ' ')" 99
        }
        $pedida = $Matches[1]
        if ($pedida -ne $subscriptionConhecida) {
            Exit-ComErro "ERROR: (SubscriptionNotFound) The subscription '$pedida' could not be found."
        }
        $corpo = Get-Valor '--body', '-b'
        if (-not $corpo -or -not $corpo.StartsWith('@') -or -not (Test-Path -LiteralPath $corpo.Substring(1) -PathType Leaf)) {
            Exit-ComErro 'az falso: a consulta de custo chegou sem o corpo num arquivo (--body @arquivo).' 2
        }
        if ($cenario -eq 'sem-permissao-de-custo') {
            Exit-ComErro "ERROR: Forbidden({""error"":{""code"":""AuthorizationFailed"",""message"":""The client 'aluno@exemplo.com' with object id '00000000-0000-0000-0000-000000000000' does not have authorization to perform action 'Microsoft.CostManagement/query/action' over scope '/subscriptions/$subscriptionConhecida' or the scope is invalid. If access was recently granted, please refresh your credentials.""}})"
        }
        if ($cenario -in 'custo-429-uma-vez', 'custo-429-sempre') {
            # Quantas consultas de custo chegaram nesta execução, contando esta: o log tem uma linha por chamada.
            $consultasDeCusto = 1
            if ($env:AZ_FALSO_LOG -and (Test-Path -LiteralPath $env:AZ_FALSO_LOG)) {
                $consultasDeCusto = @(Get-Content -LiteralPath $env:AZ_FALSO_LOG -Encoding utf8 | Where-Object { ($_ | ConvertFrom-Json).args[0] -eq 'rest' }).Count
            }
            if ($cenario -eq 'custo-429-sempre' -or $consultasDeCusto -le 1) {
                # O que o az rest escreve quando o Cost Management limita os pedidos (visto no ensaio de 09/10).
                Exit-ComErro 'ERROR: Too Many Requests({"error":{"code":"429","message":"429: Too many requests. Please retry."}})'
            }
        }
        $parametros = Get-Valor '--url-parameters', '--uri-parameters'
        $nome = if ($parametros -match '^\$skiptoken=(.+)$') { "custo-real.$($Matches[1]).json" } else { 'custo-real.json' }
        $arquivo = Join-Path $env:AZ_FALSO_DADOS $nome
        if (-not (Test-Path -LiteralPath $arquivo -PathType Leaf)) {
            Exit-ComErro "ERROR: (InvalidSkipToken) az falso: não há resposta enlatada em $arquivo"
        }
        Get-Content -Raw -Encoding UTF8 -LiteralPath $arquivo
        exit 0
    }

    default {
        Exit-ComErro "az falso: comando fora da lista de leitura (account show, extension show, graph query e o POST da consulta de custo): az $($argumentos -join ' ')" 99
    }
}
