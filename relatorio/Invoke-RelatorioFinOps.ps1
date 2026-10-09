<#
.SYNOPSIS
    Relatório FinOps: lê UMA subscription Azure, só com leitura, e aponta desperdício segundo as regras FinOps.

.DESCRIPTION
    Cada regra FinOps é um arquivo em relatorio/regras/ (FIN-01.psd1, FIN-02.psd1...).
    Para cada regra, o script pega a resposta da KQL da regra e transforma cada linha em um achado.

    Fonte Arquivo: a resposta vem de <PastaDados>/<Id da regra>.json, no mesmo formato de
    `az graph query -o json`. É assim que os testes e quem não tem subscription rodam o relatório.

    Fonte Azure: roda a KQL de cada regra com `az graph query`, só na subscription-alvo, e junta as
    páginas de 1.000 linhas pelo skip token. Antes, confere o Azure CLI, a extensão resource-graph,
    o login e a subscription, e para com uma mensagem que diz o que falta. As linhas chegam ao motor
    no mesmo formato da fonte Arquivo.

    Economia: cada achado traz a economia estimada em R$ por mês ou "não sei", conforme o campo
    Economia da regra. Os preços de tabela vêm de -TabelaDePrecos; senão, com a fonte Arquivo, de
    <PastaDados>/precos.json; senão, da Retail Prices API (pública, sem login, só GET, em BRL).
    Sem preço confiável, o achado fica com "não sei", nunca com 0 nem com um valor chutado.
    Se a Retail Prices API ou o Cost Management responder 429 (Too Many Requests), o script espera
    e tenta de novo, até 3 vezes (ver Wait-NovaTentativa), antes de desistir.

    Custo real (opcional, -CustoReal): nas regras em que o custo do recurso é o próprio desperdício,
    o custo real dos últimos 30 dias, do Cost Management, troca o preço de tabela ou o "não sei".
    O achado casa com o custo pelo ID do recurso (a coluna id da KQL).

    O script nunca altera nada no Azure. Com a fonte Azure, ele só roda comandos de leitura:
    az extension show, az account show e az graph query, e faz GET na Retail Prices API.
    Só com -CustoReal, roda também az rest --method post na consulta de custo do Cost Management
    (.../providers/Microsoft.CostManagement/query), um POST que só lê.

.PARAMETER SubscriptionId
    A subscription-alvo do relatório.

.PARAMETER Fonte
    De onde vêm os dados: Arquivo (JSON salvo) ou Azure (leitura ao vivo com o Azure CLI).

.PARAMETER DiasSnapshot
    A idade, em dias, a partir da qual um snapshot vira achado na regra FIN-05. Padrão: 30.

.PARAMETER PastaDados
    Com a fonte Arquivo, a pasta com um JSON por regra. Padrão: testes/dados (dados fictícios).

.PARAMETER Saida
    A pasta onde o script grava achados.json e relatorio-finops.html. É criada se não existir. Padrão: saida.

.PARAMETER Anonimizar
    Liga o modo anonimizado, para mostrar o relatório numa tela compartilhada: recursos, grupos de
    recursos e subscriptions viram rótulos (disco-01, rg-01, sub-01) e os valores em reais são
    arredondados para a dezena. Nenhum arquivo de saída grava um nome original.

.PARAMETER TabelaDePrecos
    Um JSON com os preços, no formato da resposta da Retail Prices API (Items[]). Vale para as duas
    fontes: substitui o precos.json da pasta de dados e a própria API. É como os testes da fonte
    Azure rodam sem rede.

.PARAMETER CustoReal
    Liga o custo real dos últimos 30 dias por recurso. Com a fonte Azure, vem do Cost Management e
    pede o papel Cost Management Reader; com a fonte Arquivo, de <PastaDados>/custo-real.json. Sem
    permissão ou sem o arquivo, o relatório segue com o preço de tabela ou "não sei" e avisa. Sem
    este switch, nenhuma consulta de custo é feita.

.EXAMPLE
    ./relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId <id-da-sua-subscription> -Fonte Azure -CustoReal

.EXAMPLE
    ./relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Fonte Arquivo

.EXAMPLE
    ./relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Fonte Arquivo -Anonimizar

.EXAMPLE
    ./relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId <id-da-sua-subscription> -Fonte Azure
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $SubscriptionId,

    [Parameter(Mandatory)]
    [ValidateSet('Arquivo', 'Azure')]
    [string] $Fonte,

    [ValidateRange(1, 3650)]
    [int] $DiasSnapshot = 30,

    [string] $PastaDados,

    [string] $Saida = 'saida',

    [switch] $Anonimizar,

    [string] $TabelaDePrecos,

    [switch] $CustoReal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# O padrão fica aqui, e não no param(): no Windows PowerShell 5.1, $PSScriptRoot chega vazio no param().
if (-not $PastaDados) { $PastaDados = Join-Path $PSScriptRoot '../testes/dados' }

# Os parâmetros que as regras podem usar. Na regra, o marcador {{Nome}} vira o valor do parâmetro:
# a KQL de FIN-05 traz ago({{DiasSnapshot}}d), que vira ago(30d) no padrão.
$ParametrosDasRegras = @{ DiasSnapshot = $DiasSnapshot }

# Lê o catálogo: um arquivo .psd1 por regra, em ordem de ID, com os marcadores já preenchidos.
function Get-Catalogo {
    $pasta = Join-Path $PSScriptRoot 'regras'
    foreach ($arquivo in Get-ChildItem -Path $pasta -Filter 'FIN-*.psd1' | Sort-Object Name) {
        $regra = Import-PowerShellDataFile -Path $arquivo.FullName
        foreach ($campo in @($regra.Keys)) {
            if ($regra[$campo] -is [string]) { $regra[$campo] = Resolve-Marcadores $regra[$campo] }
        }
        $regra
    }
}

# Troca cada {{Nome}} do texto pelo valor do parâmetro de mesmo nome.
function Resolve-Marcadores {
    param([string]$Texto)
    foreach ($nome in $ParametrosDasRegras.Keys) {
        $Texto = $Texto.Replace("{{$nome}}", [string]$ParametrosDasRegras[$nome])
    }
    $Texto
}

# As fontes: cada uma devolve as linhas (o "data") da resposta da KQL de uma regra,
# no formato de `az graph query -o json`. O motor não sabe de qual fonte a linha veio.
function Get-LinhasDaRegra {
    param($Regra)
    switch ($Fonte) {
        'Arquivo' { Get-LinhasDoArquivo $Regra }
        'Azure'   { Get-LinhasDoAzure $Regra }
    }
}

function Get-LinhasDoArquivo {
    param($Regra)
    $arquivo = Join-Path $PastaDados "$($Regra.Id).json"
    if (-not (Test-Path -LiteralPath $arquivo -PathType Leaf)) {
        throw "Faltam os dados da regra $($Regra.Id): não achei o arquivo $arquivo. Confira a pasta passada em -PastaDados."
    }
    $resposta = Get-Content -Raw -Encoding UTF8 -LiteralPath $arquivo | ConvertFrom-Json
    @($resposta.data)
}

# Fonte Azure: roda a KQL da regra no Azure Resource Graph, só na subscription-alvo, e junta as
# páginas. Cada página traz até 1.000 linhas; enquanto a resposta trouxer skip_token, pede a próxima.
function Get-LinhasDoAzure {
    param($Regra)
    # A KQL vai numa linha só: no Windows, o az é um az.cmd, e o cmd.exe corta o argumento na
    # primeira quebra de linha, levando junto o --subscriptions. Por isso a KQL não usa comentário //.
    $kql = @($Regra.Kql -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ' '
    $linhas = New-Object System.Collections.Generic.List[object]
    $skipToken = $null
    do {
        $argumentos = @('graph', 'query', '-q', $kql, '--subscriptions', $script:IdDaSubscription, '--first', '1000', '-o', 'json')
        if ($skipToken) { $argumentos += @('--skip-token', $skipToken) }
        $resultado = Invoke-Az $argumentos
        if ($resultado.Codigo -ne 0) {
            throw "A consulta da regra $($Regra.Id) ($($Regra.Titulo)) falhou no Azure Resource Graph. Motivo: $(Get-MotivoDoErro $resultado.Erro) Confira se a sua conta tem o papel Reader (Leitor) na subscription e teste a KQL de relatorio/regras/$($Regra.Id).psd1 no Resource Graph Explorer do portal."
        }
        try { $resposta = $resultado.Saida | ConvertFrom-Json } catch { $resposta = $null }
        if ($null -eq $resposta -or -not $resposta.PSObject.Properties['data']) {
            throw "A consulta da regra $($Regra.Id) ($($Regra.Titulo)) devolveu algo que não é a resposta do az graph query. Rode o relatório de novo; se repetir, teste a KQL de relatorio/regras/$($Regra.Id).psd1 no Resource Graph Explorer do portal."
        }
        foreach ($linha in @($resposta.data)) { $linhas.Add($linha) }
        $skipToken = Get-Coluna $resposta 'skip_token'
    } while ($skipToken)
    # Sem skip token, o Azure entrega só a primeira página quando a KQL usa limit, take ou sample.
    $total = Get-Coluna $resposta 'total_records'
    if ($null -ne $total -and $linhas.Count -lt [long]$total) {
        throw "A regra $($Regra.Id) ($($Regra.Titulo)) recebeu só $($linhas.Count) de $total linhas, e o Azure não mandou o skip token da página seguinte. Isso acontece quando a KQL usa limit, take ou sample: tire-os de relatorio/regras/$($Regra.Id).psd1 e rode de novo. O relatório não conclui nada com a resposta pela metade."
    }
    $linhas
}

# O motivo de um erro do az numa linha, sem o JSON que às vezes vem junto. O erro do Resource Graph
# lista os códigos do mais geral ao mais específico, como "(InvalidQuery) ..." e "(UnknownFunction) ...";
# o último é o que diz o que corrigir.
function Get-MotivoDoErro {
    param([string]$Erro)
    $linhas = @($Erro -split '\r?\n' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $comCodigo = @($linhas | Where-Object { $_ -match '^(ERROR:\s*|Exception Details:\s*)?\(\w+\)\s*\S' })
    $motivo = if ($comCodigo) { $comCodigo[-1] } elseif ($linhas) { $linhas[0] } else { 'o az não disse o motivo' }
    $motivo = (($motivo -replace '^(ERROR:|Exception Details:)\s*', '') -split '\{')[0].Trim()
    if ($motivo.Length -gt 300) { $motivo = $motivo.Substring(0, 300) + '...' }
    if ($motivo -notmatch '[.!?]$') { $motivo += '.' }
    $motivo
}

# Pré-checagens da fonte Azure, antes de rodar qualquer regra.
function Test-AcessoAoAzure {
    $script:ComandoAz = Get-Command az -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $script:ComandoAz) {
        throw 'Não achei o Azure CLI (o comando az). Instale-o seguindo https://aka.ms/installazurecli, abra um terminal novo e rode o relatório de novo.'
    }
    if ((Invoke-Az 'extension', 'show', '--name', 'resource-graph', '-o', 'json').Codigo -ne 0) {
        throw 'Falta a extensão resource-graph do Azure CLI, que roda as consultas das regras. Instale-a no seu terminal com: az extension add --name resource-graph'
    }
    if ((Invoke-Az 'account', 'show', '-o', 'json').Codigo -ne 0) {
        throw 'O Azure CLI não está logado. Rode az login, entre com a sua conta e rode o relatório de novo.'
    }
    # O az só conhece as subscriptions em que o login tem algum papel. A consulta usa o ID que ele
    # devolve, para funcionar também quando -SubscriptionId recebe o nome da subscription.
    $conta = Invoke-Az 'account', 'show', '--subscription', $SubscriptionId, '-o', 'json'
    $script:IdDaSubscription = $null
    if ($conta.Codigo -eq 0) {
        try { $script:IdDaSubscription = ($conta.Saida | ConvertFrom-Json).id } catch { $script:IdDaSubscription = $null }
    }
    if (-not $script:IdDaSubscription) {
        throw "Não achei a subscription $SubscriptionId entre as que o seu login do Azure CLI enxerga. Confira o ID (az account list -o table mostra as suas) e se a sua conta tem o papel Reader (Leitor) nessa subscription. Se o acesso é recente, rode az login de novo."
    }
}

# Roda o az e devolve o código de saída, o que ele escreveu na saída (stdout) e o erro (stderr).
function Invoke-Az {
    param([string[]]$Argumentos)
    # No 5.1, com 'Stop', a primeira linha de stderr de um comando nativo viraria erro fatal.
    $ErrorActionPreference = 'Continue'
    $PSNativeCommandUseErrorActionPreference = $false
    $tudo = & $script:ComandoAz @Argumentos 2>&1
    $codigo = $LASTEXITCODE
    $saida = foreach ($item in $tudo) { if ($item -isnot [System.Management.Automation.ErrorRecord]) { [string]$item } }
    $erro = foreach ($item in $tudo) { if ($item -is [System.Management.Automation.ErrorRecord]) { $item.ToString() } }
    [pscustomobject]@{ Codigo = $codigo; Saida = (@($saida) -join "`n"); Erro = (@($erro) -join "`n") }
}

# As colunas fixas da KQL e o campo do achado em que cada uma vira, na ordem do achado. O resto
# das colunas vira Detalhes. O id (o ID do recurso no Azure) é o que casa o achado com o custo real
# do Cost Management (-CustoReal).
$script:ColunasFixas = [ordered]@{
    name           = 'Recurso'
    resourceGroup  = 'GrupoDeRecursos'
    subscriptionId = 'Subscription'
    location       = 'Local'
    id             = 'IdDoRecurso'
}

# Transforma uma linha da resposta em um achado: a regra, as colunas fixas e os Detalhes.
function ConvertTo-Achado {
    param($Regra, $Linha)
    $achado = [ordered]@{ Regra = $Regra.Id; Titulo = $Regra.Titulo; Severidade = $Regra.Severidade }
    foreach ($coluna in $script:ColunasFixas.Keys) { $achado[$script:ColunasFixas[$coluna]] = Get-Coluna $Linha $coluna }
    $detalhes = [ordered]@{}
    foreach ($coluna in $Linha.PSObject.Properties) {
        if (-not $script:ColunasFixas.Contains($coluna.Name)) { $detalhes[$coluna.Name] = $coluna.Value }
    }
    $achado.Detalhes = $detalhes
    [pscustomobject]$achado
}

# Lê uma coluna da linha; devolve $null se a KQL não projetou essa coluna.
function Get-Coluna {
    param($Linha, [string]$Nome)
    $propriedade = $Linha.PSObject.Properties[$Nome]
    if ($propriedade) { $propriedade.Value } else { $null }
}

# Economia estimada: cada achado ganha Economia (R$ por mês, ou $null), EconomiaStatus ('estimada'
# ou 'nao-sei') e EconomiaMotivo (por que ficou "não sei"). A forma de estimar vem do campo
# Economia da regra. Regra de ouro: sem preço confiável, "não sei", nunca 0 nem um valor chutado.
function Add-Economia {
    param($Regras, $Achados)
    $porId = @{}
    foreach ($regra in $Regras) { $porId[$regra.Id] = $regra }
    foreach ($achado in $Achados) {
        $estimativa = Get-EconomiaDoAchado $porId[$achado.Regra] $achado
        $copia = [ordered]@{}
        foreach ($propriedade in $achado.PSObject.Properties) {
            if ($propriedade.Name -eq 'Detalhes') {
                $copia.Economia = $estimativa.Valor
                $copia.EconomiaStatus = if ($null -eq $estimativa.Valor) { 'nao-sei' } else { 'estimada' }
                $copia.EconomiaMotivo = $estimativa.Motivo
                $copia.EconomiaOrigem = $estimativa.Origem
            }
            $copia[$propriedade.Name] = $propriedade.Value
        }
        [pscustomobject]$copia
    }
}

# Confere o campo Economia de cada regra antes de ler qualquer dado: um erro de digitação no
# catálogo para o relatório, em vez de virar "não sei" sem ninguém perceber.
function Test-FormasDaEconomia {
    param($Regras)
    foreach ($regra in $Regras) {
        $forma = Get-FormaDaEconomia $regra
        $onde = "A regra $($regra.Id) (relatorio/regras/$($regra.Id).psd1) tem o campo Economia"
        if ($forma.ContainsKey('CustoReal') -and $forma['CustoReal'] -isnot [bool]) {
            throw "$onde com CustoReal = '$($forma['CustoReal'])'. Use `$true (o custo real do recurso substitui a estimativa) ou tire o campo."
        }
        switch ($forma['Forma']) {
            'nao-sei' { }
            'advisor' {
                if (-not $forma['Coluna'] -or -not $forma['ColunaDaMoeda']) {
                    throw "$onde com a forma 'advisor', mas sem Coluna (a coluna da KQL com o valor) ou sem ColunaDaMoeda."
                }
            }
            'preco-de-tabela' {
                if ($forma['Medidor'] -isnot [hashtable] -or $forma.Medidor.Count -eq 0) {
                    throw "$onde com a forma 'preco-de-tabela', mas sem o Medidor (os campos do filtro da Retail Prices API)."
                }
                $dePara = if ($forma['DePara']) { $forma.DePara } else { @{} }
                foreach ($nome in $dePara.Keys) {
                    $entrada = $dePara[$nome]
                    if ($entrada -isnot [hashtable] -or -not $entrada['Coluna'] -or ($entrada['Valores'] -isnot [hashtable] -and -not $entrada['Faixas'])) {
                        throw "$onde com o DePara '$nome' incompleto: ele precisa de Coluna e de Valores (uma tabela) ou Faixas."
                    }
                }
                $soQuando = if ($forma['SoQuando']) { $forma.SoQuando } else { @{} }
                $motivosSeNao = if ($forma.ContainsKey('MotivoSeNao')) { $forma['MotivoSeNao'] } else { @{} }
                if ($motivosSeNao -isnot [hashtable]) {
                    throw "$onde com o MotivoSeNao fora do formato: ele é uma tabela de coluna do SoQuando -> texto do motivo."
                }
                foreach ($coluna in $motivosSeNao.Keys) {
                    if (-not $soQuando.ContainsKey($coluna) -or $motivosSeNao[$coluna] -isnot [string] -or -not $motivosSeNao[$coluna].Trim()) {
                        throw "$onde com o MotivoSeNao '$coluna', que precisa ser uma coluna do SoQuando e ter o texto do motivo."
                    }
                }
            }
            default {
                throw "$onde com a forma '$($forma['Forma'])', que o script não conhece. Use 'advisor', 'preco-de-tabela' ou 'nao-sei'."
            }
        }
    }
}

# O campo Economia da regra como hashtable. Aceita a forma curta: Economia = 'nao-sei'.
function Get-FormaDaEconomia {
    param($Regra)
    $economia = $Regra['Economia']
    if ($economia -is [string]) { return @{ Forma = $economia } }
    if ($economia -is [hashtable]) { return $economia }
    @{ Forma = 'nao-sei'; Motivo = 'A regra não diz como estimar a economia.' }
}

# A economia de um achado: @{ Valor = R$ por mês, ou $null; Motivo = por que ficou "não sei";
# Origem = de onde veio o valor ('advisor' ou 'preco-de-tabela'), ou $null no "não sei" }.
function Get-EconomiaDoAchado {
    param($Regra, $Achado)
    $forma = Get-FormaDaEconomia $Regra
    $estimativa = switch ($forma.Forma) {
        'advisor'         { Get-EconomiaDoAdvisor $forma $Achado }
        'preco-de-tabela' { Get-EconomiaDoPrecoDeTabela $forma $Achado }
        default {
            $motivo = if ($forma['Motivo']) { $forma['Motivo'] } else { 'A regra não tem como estimar a economia.' }
            @{ Valor = $null; Motivo = $motivo }
        }
    }
    $estimativa.Origem = if ($null -ne $estimativa.Valor) { $forma.Forma } else { $null }
    $estimativa
}

# Forma 'advisor': a economia que o próprio Advisor informa, numa coluna da KQL, só em reais.
# Em outra moeda, o achado fica com "não sei", e o motivo mostra o valor e a moeda que o Advisor
# informou (USD 12,34), para quem lê ter a ordem de grandeza; esse valor não entra no total em R$.
# No modo anonimizado, ele vai para a dezena, como os valores em reais.
function Get-EconomiaDoAdvisor {
    param($Forma, $Achado)
    $valor = Get-ColunaDoAchado $Achado $Forma.Coluna
    $moeda = [string](Get-ColunaDoAchado $Achado $Forma.ColunaDaMoeda)
    $numero = ConvertTo-Numero $valor
    if ($null -eq $numero -or $numero -le 0) { return @{ Valor = $null; Motivo = 'O Advisor não informou a economia desta recomendação.' } }
    if ($moeda -ne 'BRL') {
        $informado = Format-Numero $(if ($Anonimizar) { Get-Dezena $numero } else { $numero })
        $motivo = if ($moeda.Trim()) { "$moeda $informado informados pelo Advisor por mês, em outra moeda" }
        else { "$informado informados pelo Advisor por mês, sem dizer a moeda" }
        return @{ Valor = $null; Motivo = "${motivo}: o relatório não converte moeda, e o valor fica fora do total em R$." }
    }
    @{ Valor = [math]::Round($numero, 2, [System.MidpointRounding]::AwayFromZero); Motivo = $null }
}

# Forma 'preco-de-tabela': monta o medidor com as colunas do achado, busca o preço na tabela de
# preços e converte para R$ por mês. Qualquer dúvida no caminho deixa o achado com "não sei".
function Get-EconomiaDoPrecoDeTabela {
    param($Forma, $Achado)
    $naoSei = { param([string]$Motivo) @{ Valor = $null; Motivo = $Motivo } }

    # 1. Só estima quando cada coluna de SoQuando tem um dos valores esperados. Quando a coluna tem
    #    um valor legível que fica de fora, e a regra diz por quê em MotivoSeNao, o motivo é o dela
    #    (o disco nunca anexado, que o Azure não cobra); senão, o medidor é ambíguo.
    $condicoes = if ($Forma['SoQuando']) { $Forma.SoQuando } else { @{} }
    $motivosSeNao = if ($Forma['MotivoSeNao']) { $Forma.MotivoSeNao } else { @{} }
    foreach ($coluna in $condicoes.Keys) {
        $valor = Get-ColunaDoAchado $Achado $coluna
        if (Test-ValorAceito $valor $condicoes[$coluna]) { continue }
        if ($motivosSeNao.ContainsKey($coluna) -and (Test-ValorLegivel $valor $condicoes[$coluna])) {
            return & $naoSei $motivosSeNao[$coluna]
        }
        return & $naoSei "Medidor ambíguo: a coluna $coluna não tem um valor que a regra sabe precificar."
    }

    # 2. De-para: cada nome vira um pedaço do medidor, por tabela de valores ou por faixas de número.
    $pedacos = @{}
    $dePara = if ($Forma['DePara']) { $Forma.DePara } else { @{} }
    foreach ($nome in $dePara.Keys) {
        $regraDoPedaco = $dePara[$nome]
        $valor = Get-ColunaDoAchado $Achado $regraDoPedaco.Coluna
        $pedaco = $null
        if ($regraDoPedaco['Faixas']) {
            $numero = ConvertTo-Numero $valor
            if ($null -ne $numero -and $numero -gt 0) {
                $faixa = @($regraDoPedaco.Faixas | Sort-Object { [decimal]$_.Ate } | Where-Object { $numero -le [decimal]$_.Ate } | Select-Object -First 1)
                if ($faixa) { $pedaco = [string]$faixa[0].Valor }
            }
        } elseif ($null -ne $valor -and $regraDoPedaco.Valores.ContainsKey([string]$valor)) {
            $pedaco = [string]$regraDoPedaco.Valores[[string]$valor]
        }
        if ($null -eq $pedaco) {
            return & $naoSei "Medidor ambíguo: a coluna $($regraDoPedaco.Coluna) não tem um valor que a regra sabe precificar."
        }
        $pedacos[$nome] = $pedaco
    }

    # 3. O medidor: troca cada {nome} pelo pedaço do de-para ou pelo valor da coluna da KQL.
    $filtro = [ordered]@{}
    foreach ($campo in @($Forma.Medidor.Keys | Sort-Object)) {
        $texto = [string]$Forma.Medidor[$campo]
        foreach ($marcador in [regex]::Matches($texto, '\{(\w+)\}')) {
            $nome = $marcador.Groups[1].Value
            $valor = if ($pedacos.ContainsKey($nome)) { $pedacos[$nome] } else { Get-ColunaDoAchado $Achado $nome }
            if ($null -eq $valor -or ('' -eq [string]$valor -and -not $pedacos.ContainsKey($nome))) {
                return & $naoSei "Medidor ambíguo: a coluna $nome veio vazia."
            }
            $texto = $texto.Replace($marcador.Value, [string]$valor)
        }
        $filtro[$campo] = $texto
    }

    # 4. O preço: um só, em reais, sem faixa de consumo.
    $consulta = Get-ItensDePreco $filtro
    if ($consulta.Erro) { return & $naoSei $consulta.Erro }
    # Get-Coluna lê cada campo do item: num arquivo feito à mão, um campo pode faltar.
    $itens = @($consulta.Itens | Where-Object { (Get-Coluna $_ 'type') -eq 'Consumption' })
    # O medidor no motivo: o meterName ou, quando a regra não filtra por ele, o produto e o SKU.
    $medidor = if ($filtro.Contains('meterName')) { " ($($filtro.meterName))" }
    elseif ($filtro.Contains('skuName')) { " ($((@($filtro['productName'], $filtro['skuName']) | Where-Object { $_ }) -join ', '))" }
    else { '' }
    if ($itens.Count -eq 0) { return & $naoSei "A tabela de preços não tem esse medidor$medidor." }
    if (@($itens | Where-Object { (ConvertTo-Numero (Get-Coluna $_ 'tierMinimumUnits')) -gt 0 }).Count -gt 0) {
        return & $naoSei "O medidor$medidor tem preço em faixas de consumo, que dependem do uso."
    }
    $precos = @($itens | ForEach-Object { '{0}|{1}|{2}' -f (Get-Coluna $_ 'retailPrice'), (Get-Coluna $_ 'unitOfMeasure'), (Get-Coluna $_ 'currencyCode') } | Sort-Object -Unique)
    if ($precos.Count -gt 1) { return & $naoSei "A tabela de preços tem mais de um preço para o medidor$medidor." }
    $item = $itens[0]
    $preco = ConvertTo-Numero (Get-Coluna $item 'retailPrice')
    if ([string](Get-Coluna $item 'currencyCode') -ne 'BRL' -or $null -eq $preco -or $preco -le 0) {
        return & $naoSei "A tabela de preços não tem um preço em reais para o medidor$medidor."
    }

    # 5. Para R$ por mês: por hora, x 730 horas; por mês, direto; por GB por mês, x a quantidade em GB.
    $unidade = [string](Get-Coluna $item 'unitOfMeasure')
    if ($unidade -match '^(\d+) Hours?$') { $mensal = $preco / [decimal]$Matches[1] * 730 }
    elseif ($unidade -match '^(\d+)/Month$') { $mensal = $preco / [decimal]$Matches[1] }
    elseif ($unidade -match '^(\d+) GB/Month$' -and $Forma['Quantidade']) { $mensal = $preco / [decimal]$Matches[1] }
    else { return & $naoSei "O medidor$medidor é cobrado por '$unidade', que o relatório não sabe levar para R$ por mês." }

    # 6. A quantidade, quando a regra declara: instâncias do plano, GB do snapshot...
    if ($Forma['Quantidade']) {
        $quantidade = ConvertTo-Numero (Get-ColunaDoAchado $Achado $Forma.Quantidade)
        if ($null -eq $quantidade -or $quantidade -le 0) { return & $naoSei "Medidor ambíguo: a coluna $($Forma.Quantidade) não traz a quantidade." }
        $mensal = $mensal * $quantidade
    }
    $mensal = [math]::Round($mensal, 2, [System.MidpointRounding]::AwayFromZero)
    if ($mensal -le 0) { return & $naoSei "O preço do medidor$medidor fica abaixo de R$ 0,01 por mês." }
    @{ Valor = $mensal; Motivo = $null }
}

# O valor de uma coluna bate com um dos valores aceitos pela regra (em SoQuando)? Quando o valor
# aceito é booleano ($true ou $false), a coluna é lida como booleano (ver ConvertTo-Booleano);
# nos outros casos, a comparação é de texto, sem diferenciar maiúsculas. Valor vazio nunca bate.
function Test-ValorAceito {
    param($Valor, $Aceitos)
    foreach ($aceito in @($Aceitos)) {
        if ($aceito -is [bool]) {
            $booleano = ConvertTo-Booleano $Valor
            if ($null -ne $booleano -and $booleano -eq $aceito) { return $true }
        } elseif ($null -ne $Valor -and '' -ne [string]$Valor -and [string]$Valor -eq [string]$aceito) {
            return $true
        }
    }
    $false
}

# A coluna tem um valor que dá para ler? Com valores aceitos booleanos, só um valor que vira
# booleano; nos outros casos, qualquer valor não vazio. Vazio, ausente ou ilegível é medidor ambíguo.
function Test-ValorLegivel {
    param($Valor, $Aceitos)
    if (@(@($Aceitos) | Where-Object { $_ -is [bool] }).Count -gt 0) { return $null -ne (ConvertTo-Booleano $Valor) }
    $null -ne $Valor -and '' -ne [string]$Valor
}

# Um booleano a partir de um valor da KQL: $true e $false, 1 e 0, "1" e "0", "true" e "false"
# (sem diferenciar maiúsculas). O Resource Graph devolve uma expressão booleana calculada na KQL
# como 1 ou 0, e não como true ou false (visto no ensaio). Devolve $null se não for booleano.
function ConvertTo-Booleano {
    param($Valor)
    if ($Valor -is [bool]) { return $Valor }
    if ($null -eq $Valor) { return $null }
    switch -Regex ([string]::Format([cultureinfo]::InvariantCulture, '{0}', $Valor).Trim()) {
        '^(1|true)$'  { return $true }
        '^(0|false)$' { return $false }
    }
    $null
}

# Preços de tabela. Cada medidor é consultado uma vez por execução (cache pelo filtro).
# Com -TabelaDePrecos, ou com a fonte Arquivo, os preços vêm de um JSON no formato da resposta da
# Retail Prices API (Items[]). Com a fonte Azure e sem -TabelaDePrecos, vêm da própria API.
# Devolve @{ Itens = os itens do medidor; Erro = por que não deu para ler os preços, ou $null }.
$script:CacheDePrecos = @{}
$script:ArquivoDePrecos = $null
$script:ItensDoArquivoDePrecos = $null
$script:AvisouPrecos = $false
function Get-ItensDePreco {
    param($Filtro)
    $chave = (@($Filtro.Keys) | ForEach-Object { "$_=$($Filtro[$_])" }) -join ';'
    if (-not $script:CacheDePrecos.ContainsKey($chave)) {
        $resultado = @{ Itens = @(); Erro = $null }
        try {
            $resultado.Itens = @(if ($script:ArquivoDePrecos) { Get-PrecosDoArquivo $Filtro } else { Get-PrecosDaApi $Filtro })
        } catch {
            # No achado, o motivo fica curto; o detalhe do erro vai só no aviso da tela, uma vez.
            $resultado.Erro = 'Não consegui ler a tabela de preços (veja o aviso na tela).'
            if (-not $script:AvisouPrecos) {
                Write-Warning "Não consegui ler a tabela de preços: $($_.Exception.Message) Os achados que dependem de preço de tabela ficam com 'não sei'."
                $script:AvisouPrecos = $true
            }
        }
        $script:CacheDePrecos[$chave] = $resultado
    }
    $script:CacheDePrecos[$chave]
}

# A tabela de preços de um arquivo JSON: só os itens em que cada campo do filtro bate exatamente,
# com as maiúsculas, como na Retail Prices API.
function Get-PrecosDoArquivo {
    param($Filtro)
    if ($null -eq $script:ItensDoArquivoDePrecos) {
        if (-not (Test-Path -LiteralPath $script:ArquivoDePrecos -PathType Leaf)) {
            # Só o nome do arquivo: o caminho inteiro pode ter nome de pasta que não deve aparecer na tela.
            throw "não achei o arquivo $(Split-Path -Leaf $script:ArquivoDePrecos) na pasta de dados (-PastaDados)."
        }
        $tabela = Get-Content -Raw -Encoding UTF8 -LiteralPath $script:ArquivoDePrecos | ConvertFrom-Json
        $script:ItensDoArquivoDePrecos = @($tabela.Items)
    }
    foreach ($item in $script:ItensDoArquivoDePrecos) {
        $bate = $true
        foreach ($campo in $Filtro.Keys) {
            $propriedade = $item.PSObject.Properties[$campo]
            if (-not $propriedade -or [string]$propriedade.Value -cne $Filtro[$campo]) { $bate = $false; break }
        }
        if ($bate) { $item }
    }
}

# Nova tentativa quando o serviço responde 429 (Too Many Requests): a Retail Prices API e o Cost
# Management limitam quantos pedidos aceitam por minuto. São no máximo $TentativasNo429 tentativas
# por pedido. Entre elas, a espera é a que o cabeçalho Retry-After pede, até 60 s; sem ele, a espera
# cresce: 5 s, depois 10 s. Só depois disso o relatório desiste e cai para "não sei".
$script:TentativasNo429 = 3
$script:EsperaMaximaNo429 = 60

# Espera antes da tentativa seguinte e avisa na tela quanto tempo e por quê.
function Wait-NovaTentativa {
    param([int]$Tentativa, $RetryAfter, [string]$Servico)
    $segundos = if ($null -ne $RetryAfter) { [int][math]::Min([math]::Max([math]::Ceiling($RetryAfter), 1), $script:EsperaMaximaNo429) }
    else { [int](5 * [math]::Pow(2, $Tentativa - 1)) }
    Write-Host "$Servico respondeu 429 (Too Many Requests): nova tentativa em $segundos s ($($Tentativa + 1) de $script:TentativasNo429)."
    Start-Sleep -Seconds $segundos
}

# A resposta HTTP de um erro do Invoke-RestMethod, ou $null quando o erro não traz resposta: no
# PowerShell 7, um HttpResponseMessage; no 5.1, um HttpWebResponse.
function Get-RespostaDoErro {
    param($Erro)
    $excecao = $Erro.Exception
    if ($excecao.PSObject.Properties['Response'] -and $excecao.Response) { $excecao.Response } else { $null }
}

# O erro do Invoke-RestMethod é um 429 (Too Many Requests)?
function Test-Erro429DaApi {
    param($Erro)
    $resposta = Get-RespostaDoErro $Erro
    if ($resposta -and $resposta.PSObject.Properties['StatusCode']) { return [int]$resposta.StatusCode -eq 429 }
    $Erro.Exception.Message -match '\b429\b|Too Many Requests'
}

# Os segundos que o cabeçalho Retry-After da resposta pede, ou $null se ele não veio. Ele traz os
# segundos ou uma data. No PowerShell 7, vem pronto em Headers.RetryAfter; no 5.1, como texto.
function Get-RetryAfter {
    param($Erro)
    $resposta = Get-RespostaDoErro $Erro
    if (-not $resposta -or -not $resposta.PSObject.Properties['Headers'] -or -not $resposta.Headers) { return $null }
    if ($resposta.Headers.PSObject.Properties['RetryAfter']) {
        $retryAfter = $resposta.Headers.RetryAfter
        if (-not $retryAfter) { return $null }
        if ($null -ne $retryAfter.Delta) { return $retryAfter.Delta.TotalSeconds }
        if ($null -ne $retryAfter.Date) { return ($retryAfter.Date - [DateTimeOffset]::UtcNow).TotalSeconds }
        return $null
    }
    $texto = [string]$resposta.Headers['Retry-After']
    $segundos = 0
    if ([int]::TryParse($texto, [ref]$segundos)) { return $segundos }
    $data = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($texto, [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal, [ref]$data)) {
        return ($data - [DateTimeOffset]::UtcNow).TotalSeconds
    }
    $null
}

# Um GET na Retail Prices API, com nova tentativa no 429. Se ela recusar todas as tentativas, o
# relatório não pede mais nenhum preço nesta execução: os outros medidores também ficam com "não
# sei", sem esperar tudo de novo.
$script:ApiDePrecosRecusou = $false
function Invoke-ApiDePrecos {
    param([string]$Url)
    if ($script:ApiDePrecosRecusou) {
        throw "a Retail Prices API já tinha respondido 429 (Too Many Requests) nas $script:TentativasNo429 tentativas, e o relatório não pede mais preços nesta execução."
    }
    for ($tentativa = 1; ; $tentativa++) {
        try {
            return Invoke-RestMethod -Method Get -Uri $Url
        } catch {
            if (-not (Test-Erro429DaApi $_)) { throw }
            if ($tentativa -ge $script:TentativasNo429) {
                $script:ApiDePrecosRecusou = $true
                throw "a Retail Prices API respondeu 429 (Too Many Requests) nas $tentativa tentativas. Rode o relatório de novo daqui a alguns minutos."
            }
            Wait-NovaTentativa $tentativa (Get-RetryAfter $_) 'A Retail Prices API'
        }
    }
}

# A Retail Prices API: pública, sem login, só GET, em reais. Junta as páginas pelo NextPageLink.
function Get-PrecosDaApi {
    param($Filtro)
    $condicoes = @(foreach ($campo in $Filtro.Keys) { "$campo eq '$(([string]$Filtro[$campo]).Replace("'", "''"))'" })
    $condicoes += "priceType eq 'Consumption'"
    $url = "https://prices.azure.com/api/retail/prices?currencyCode='BRL'&`$filter=" + [uri]::EscapeDataString($condicoes -join ' and ')
    # No Windows PowerShell 5.1, o HTTPS pode não ligar o TLS 1.2 sozinho.
    if ($PSVersionTable.PSVersion.Major -lt 6) {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
    $paginas = 0
    while ($url) {
        $paginas++
        if ($paginas -gt 20) { throw 'a Retail Prices API mandou páginas demais para um medidor só.' }
        $pagina = Invoke-ApiDePrecos $url
        foreach ($item in @($pagina.Items)) { $item }
        $url = if ($pagina.PSObject.Properties['NextPageLink']) { $pagina.NextPageLink } else { $null }
    }
}

# Uma coluna da KQL no achado: as fixas viraram campos (ver $ColunasFixas: name é Recurso,
# location é Local...); as outras estão em Detalhes. Devolve $null se a KQL não projetou a coluna.
function Get-ColunaDoAchado {
    param($Achado, [string]$Nome)
    if (-not $Nome) { return $null }
    if ($script:ColunasFixas.Contains($Nome)) { return $Achado.($script:ColunasFixas[$Nome]) }
    if ($Achado.Detalhes.Contains($Nome)) { $Achado.Detalhes[$Nome] } else { $null }
}

# Custo real (-CustoReal): o que cada recurso custou de verdade nos últimos 30 dias, segundo o
# Cost Management. Só vale nas regras em que o custo do recurso é o próprio desperdício, que
# marcam CustoReal = $true no campo Economia (o disco solto, o IP sem uso...). Nelas, o custo real
# troca o preço de tabela ou o "não sei". Sem o custo real, o achado fica como estava.
$script:VersaoDaApiDeCusto = '2025-03-01'

# Os 30 dias completos antes de hoje, em UTC.
function Get-PeriodoDoCustoReal {
    $hoje = [datetime]::UtcNow.Date
    @{ De = $hoje.AddDays(-30); Ate = $hoje.AddSeconds(-1) }
}

# Lê o custo real. Devolve @{ Custos = ID do recurso em minúsculas -> R$ dos 30 dias;
# Origem = de onde veio, para o HTML e a tela; Aviso = por que não deu para ler, ou $null }.
# Custo real é opcional: qualquer falha vira um aviso, e o relatório segue sem ele.
function Read-CustoReal {
    param($Periodo)
    $leitura = @{ Custos = @{}; Origem = $null; Aviso = $null }
    try {
        if ($Fonte -eq 'Arquivo') {
            $respostas = @(Get-CustoRealDoArquivo)
            $leitura.Origem = 'custo-real.json da pasta de dados (JSON salvo, não é leitura ao vivo)'
        } else {
            $respostas = @(Get-CustoRealDoAzure $Periodo)
            $de = $Periodo.De.ToString('dd/MM/yyyy', [cultureinfo]::InvariantCulture)
            $ate = $Periodo.Ate.ToString('dd/MM/yyyy', [cultureinfo]::InvariantCulture)
            $leitura.Origem = "Cost Management, de $de a $ate"
        }
        $outrasMoedas = New-Object System.Collections.Generic.List[string]
        $leitura.Custos = ConvertFrom-RespostaDeCusto $respostas $outrasMoedas
        if ($outrasMoedas.Count -gt 0) {
            Write-Warning "O Cost Management informou o custo em $(@($outrasMoedas | Sort-Object -Unique) -join ', '), e o relatório não converte moeda: esses achados ficam com o preço de tabela ou ""não sei""."
        }
    } catch {
        $leitura.Aviso = "Não li o custo real: $($_.Exception.Message) O relatório segue com o preço de tabela ou ""não sei""."
        Write-Warning $leitura.Aviso
    }
    $leitura
}

# Fonte Arquivo: <PastaDados>/custo-real.json, no formato da resposta da consulta do Cost Management.
function Get-CustoRealDoArquivo {
    $arquivo = Join-Path $PastaDados 'custo-real.json'
    if (-not (Test-Path -LiteralPath $arquivo -PathType Leaf)) {
        throw 'não achei o arquivo custo-real.json na pasta de dados (-PastaDados).'
    }
    Get-Content -Raw -Encoding UTF8 -LiteralPath $arquivo | ConvertFrom-Json
}

# Fonte Azure: a consulta de custo do Cost Management (Query - Usage), só na subscription-alvo.
# É um POST, mas de leitura: só consulta o custo, não muda nada. O corpo vai num arquivo
# (--body @arquivo), porque, no Windows, o cmd.exe do az.cmd estraga as aspas de um JSON passado
# direto no argumento. Pede o custo real (ActualCost) dos 30 dias, somado por recurso (ResourceId).
# Quando o resultado não cabe numa página, a resposta traz o nextLink, e a página seguinte vem com o
# mesmo POST e o skip token em --url-parameters: o & do nextLink cortaria o comando no cmd.exe.
function Get-CustoRealDoAzure {
    param($Periodo)
    $url = "https://management.azure.com/subscriptions/$($script:IdDaSubscription)/providers/Microsoft.CostManagement/query?api-version=$script:VersaoDaApiDeCusto"
    $formato = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    $corpo = [ordered]@{
        type       = 'ActualCost'
        timeframe  = 'Custom'
        timePeriod = [ordered]@{
            from = $Periodo.De.ToString($formato, [cultureinfo]::InvariantCulture)
            to   = $Periodo.Ate.ToString($formato, [cultureinfo]::InvariantCulture)
        }
        dataset    = [ordered]@{
            granularity = 'None'
            aggregation = @{ totalCost = [ordered]@{ name = 'PreTaxCost'; function = 'Sum' } }
            grouping    = @([ordered]@{ type = 'Dimension'; name = 'ResourceId' })
        }
    }
    $arquivoDoCorpo = [System.IO.Path]::GetTempFileName()
    try {
        Write-Texto $arquivoDoCorpo (ConvertTo-Json -InputObject $corpo -Depth 5)
        $skipToken = $null
        $paginas = 0
        do {
            $paginas++
            if ($paginas -gt 50) { throw 'o Cost Management mandou páginas demais.' }
            $argumentos = @('rest', '--method', 'post', '--url', $url, '--body', "@$arquivoDoCorpo", '-o', 'json')
            if ($skipToken) { $argumentos += @('--url-parameters', "`$skiptoken=$skipToken") }
            $resultado = Invoke-AzComNovaTentativa $argumentos 'O Cost Management'
            if ($resultado.Codigo -ne 0) { throw (Get-MotivoDoErroDeCusto $resultado.Erro) }
            # 204 No Content: a subscription não teve custo no período.
            if (-not $resultado.Saida.Trim()) { break }
            try { $resposta = $resultado.Saida | ConvertFrom-Json } catch { $resposta = $null }
            if ($null -eq $resposta) { throw 'o Cost Management devolveu algo que não é a resposta da consulta de custo.' }
            $resposta
            $skipToken = Get-SkipTokenDoCusto $resposta
        } while ($skipToken)
    } finally {
        Remove-Item -LiteralPath $arquivoDoCorpo -Force -ErrorAction SilentlyContinue
    }
}

# Roda o az e, se o serviço responder 429 (Too Many Requests), tenta de novo, com a mesma política
# da Retail Prices API (ver Wait-NovaTentativa). O az rest não mostra o Retry-After: a espera é a
# crescente, 5 s e depois 10 s. Devolve o resultado da última tentativa.
function Invoke-AzComNovaTentativa {
    param([string[]]$Argumentos, [string]$Servico)
    for ($tentativa = 1; ; $tentativa++) {
        $resultado = Invoke-Az $Argumentos
        if ($resultado.Codigo -eq 0 -or -not (Test-Erro429DoAz $resultado.Erro) -or $tentativa -ge $script:TentativasNo429) {
            return $resultado
        }
        Wait-NovaTentativa $tentativa $null $Servico
    }
}

# O erro do az é um 429 (Too Many Requests)? O az rest escreve, por exemplo,
# "Too Many Requests({...""code"":""429""...})".
function Test-Erro429DoAz {
    param([string]$Erro)
    $Erro -match '\b429\b|Too ?Many ?Requests'
}

# O skip token da página seguinte, tirado do nextLink da resposta; $null se não há página seguinte.
function Get-SkipTokenDoCusto {
    param($Resposta)
    $propriedades = Get-Coluna $Resposta 'properties'
    $proxima = if ($propriedades) { [string](Get-Coluna $propriedades 'nextLink') } else { '' }
    if (-not $proxima) { return $null }
    $token = [regex]::Match($proxima, '[?&]\$skiptoken=([^&]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if (-not $token.Success) { throw 'o Cost Management mandou uma página seguinte sem o skip token.' }
    [uri]::UnescapeDataString($token.Groups[1].Value)
}

# O motivo de uma falha da consulta de custo, numa frase, sem ID, caminho do Azure nem e-mail:
# o aviso aparece na tela e no HTML, também no modo anonimizado. Falta de permissão (401, 403,
# AuthorizationFailed) diz qual papel pedir.
function Get-MotivoDoErroDeCusto {
    param([string]$Erro)
    if ($Erro -match 'AuthorizationFailed|RBACAccessDenied|Unauthorized|Forbidden|\b40[13]\b') {
        return 'a sua conta não tem permissão para ler o custo desta subscription. Peça o papel Cost Management Reader (Leitor de Gerenciamento de Custos), além do Reader.'
    }
    if (Test-Erro429DoAz $Erro) {
        return "o Cost Management respondeu 429 (Too Many Requests) nas $script:TentativasNo429 tentativas. Rode o relatório de novo daqui a alguns minutos."
    }
    $codigo = [regex]::Match($Erro, '"code"\s*:\s*"([^"]+)"')
    $mensagem = [regex]::Match($Erro, '"message"\s*:\s*"([^"]+)"')
    $motivo = if ($codigo.Success -and $mensagem.Success) { "$($codigo.Groups[1].Value): $($mensagem.Groups[1].Value)" } else { Get-MotivoDoErro $Erro }
    $motivo = $motivo -replace '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', '<oculto>'
    $motivo = $motivo -replace '/subscriptions/[^\s''"]*', '<oculto>' -replace '[^\s''"]+@[^\s''"]+', '<oculto>'
    if ($motivo -notmatch '[.!?]$') { $motivo += '.' }
    "o Cost Management recusou a consulta. Motivo: $motivo"
}

# As linhas das respostas do Cost Management (properties.columns e properties.rows) como uma tabela
# de custo por ID do recurso, em minúsculas: o Cost Management devolve o ID em minúsculas, e o
# Resource Graph, com a grafia original. Linha repetida de um recurso soma. Linha em outra moeda
# fica de fora e entra em $OutrasMoedas, porque o relatório não converte moeda.
function ConvertFrom-RespostaDeCusto {
    param($Respostas, $OutrasMoedas)
    $custos = @{}
    foreach ($resposta in $Respostas) {
        $propriedades = Get-Coluna $resposta 'properties'
        $colunas = @(if ($propriedades) { Get-Coluna $propriedades 'columns' })
        $nomes = @($colunas | ForEach-Object { ([string](Get-Coluna $_ 'name')).ToLowerInvariant() })
        $iId = [array]::IndexOf($nomes, 'resourceid')
        $iMoeda = [array]::IndexOf($nomes, 'currency')
        $iCusto = [array]::IndexOf($nomes, 'pretaxcost')
        if ($iCusto -lt 0) { $iCusto = [array]::IndexOf($nomes, 'cost') }
        if ($iId -lt 0 -or $iCusto -lt 0) {
            throw 'a resposta do Cost Management não tem as colunas ResourceId e PreTaxCost (ou Cost).'
        }
        foreach ($linha in @(Get-Coluna $propriedades 'rows')) {
            $id = [string]$linha[$iId]
            $valor = ConvertTo-Numero $linha[$iCusto]
            $moeda = if ($iMoeda -ge 0) { [string]$linha[$iMoeda] } else { 'BRL' }
            if (-not $id -or $null -eq $valor) { continue }
            if ($moeda -ne 'BRL') { $OutrasMoedas.Add($moeda); continue }
            $chave = $id.ToLowerInvariant()
            $custos[$chave] = $valor + $(if ($custos.ContainsKey($chave)) { $custos[$chave] } else { 0 })
        }
    }
    $custos
}

# Troca a economia pelo custo real nas regras com CustoReal = $true, quando o Cost Management traz
# um custo positivo para o ID do recurso do achado. Custo 0 ou ausente deixa o achado como estava:
# o relatório nunca mostra 0.
function Add-CustoReal {
    param($Regras, $Achados, $Custos)
    $porId = @{}
    foreach ($regra in $Regras) { $porId[$regra.Id] = $regra }
    foreach ($achado in $Achados) {
        $forma = Get-FormaDaEconomia $porId[$achado.Regra]
        $chave = if ($achado.IdDoRecurso) { ([string]$achado.IdDoRecurso).ToLowerInvariant() } else { $null }
        if ($forma['CustoReal'] -eq $true -and $chave -and $Custos.ContainsKey($chave)) {
            $valor = [math]::Round([decimal]$Custos[$chave], 2, [System.MidpointRounding]::AwayFromZero)
            if ($valor -gt 0) {
                $achado.Economia = $valor
                $achado.EconomiaStatus = 'estimada'
                $achado.EconomiaMotivo = $null
                $achado.EconomiaOrigem = 'custo-real'
            }
        }
        $achado
    }
}

# Um número (decimal) a partir de um valor da KQL; $null se não for número.
function ConvertTo-Numero {
    param($Valor)
    if ($null -eq $Valor -or $Valor -is [bool]) { return $null }
    $numero = [decimal]0
    if ([decimal]::TryParse([string]::Format([cultureinfo]::InvariantCulture, '{0}', $Valor), [System.Globalization.NumberStyles]::Float, [cultureinfo]::InvariantCulture, [ref]$numero)) { $numero } else { $null }
}

# Modo anonimizado: cada recurso, grupo de recursos e subscription vira um rótulo estável dentro
# da execução (o mesmo nome original sempre vira o mesmo rótulo). Roda depois de montar os achados
# e antes de gravar qualquer arquivo, então nada do que o script grava carrega um nome original.
function ConvertTo-Anonimizado {
    param($Regras, $Achados, [string]$SubscriptionId)

    # Um mapa por tipo de nome, sem diferenciar maiúsculas: no Azure, "RG-Loja" e "rg-loja" são o mesmo grupo.
    $mapas = @{}
    foreach ($tipo in 'Recurso', 'Grupo', 'Sub') {
        $mapas[$tipo] = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }
    $contadores = @{}
    $prefixos = @{}
    foreach ($regra in $Regras) {
        $prefixos[$regra.Id] = if ($regra['Rotulo']) { $regra['Rotulo'] } else { 'recurso' }
    }

    # Primeiro, todos os rótulos. A subscription do parâmetro é a sub-01.
    $subscription = Get-Rotulo $mapas.Sub $contadores $SubscriptionId 'sub'
    foreach ($achado in $Achados) {
        $null = Get-Rotulo $mapas.Recurso $contadores $achado.Recurso $prefixos[$achado.Regra]
        $null = Get-Rotulo $mapas.Grupo $contadores $achado.GrupoDeRecursos 'rg'
        $null = Get-Rotulo $mapas.Sub $contadores $achado.Subscription 'sub'
    }

    # Depois, uma cópia de cada achado com os rótulos no lugar dos nomes, já sabendo todos os nomes.
    $anonimos = foreach ($achado in $Achados) {
        $copia = [ordered]@{}
        foreach ($propriedade in $achado.PSObject.Properties) { $copia[$propriedade.Name] = $propriedade.Value }
        $copia.Recurso = Get-Rotulo $mapas.Recurso $contadores $achado.Recurso $prefixos[$achado.Regra]
        $copia.GrupoDeRecursos = Get-Rotulo $mapas.Grupo $contadores $achado.GrupoDeRecursos 'rg'
        $copia.Subscription = Get-Rotulo $mapas.Sub $contadores $achado.Subscription 'sub'
        # O ID do recurso leva a subscription, o grupo e o nome: fica oculto inteiro.
        if ($achado.IdDoRecurso) { $copia.IdDoRecurso = '<oculto>' }
        foreach ($nome in @($copia.Keys)) {
            if (Test-ValorEmReais $nome $copia[$nome]) { $copia[$nome] = Get-Dezena $copia[$nome] }
        }
        $detalhes = [ordered]@{}
        foreach ($chave in $achado.Detalhes.Keys) { $detalhes[$chave] = Protect-Detalhe $mapas $chave $achado.Detalhes[$chave] }
        $copia.Detalhes = $detalhes
        [pscustomobject]$copia
    }
    @{ Achados = @($anonimos); SubscriptionId = $subscription }
}

# Valor em reais, pelo nome da coluna (Economia, custoMensal, preco, valor...), e que é número.
function Test-ValorEmReais {
    param([string]$Nome, $Valor)
    $numero = $Valor -is [int] -or $Valor -is [long] -or $Valor -is [double] -or $Valor -is [single] -or $Valor -is [decimal]
    $numero -and $Nome -match 'economia|custo|pre[cç]o|valor'
}

# A dezena mais próxima: 123,45 vira 120; 125 vira 130. Com piso de 10 para valor positivo:
# 3,20 vira 10, para o relatório nunca mostrar 0 para algo que custa.
function Get-Dezena {
    param($Valor)
    $dezena = [math]::Round([decimal]$Valor / 10, [System.MidpointRounding]::AwayFromZero) * 10
    if ([decimal]$Valor -gt 0 -and $dezena -lt 10) { $dezena = [decimal]10 }
    $dezena
}

# Um valor de detalhe no modo anonimizado. Valor em reais: vai para a dezena mais próxima.
# Igual a um nome original: vira o rótulo desse nome. Com um nome original no meio, com cara de
# ID do Azure (/subscriptions/..., /providers/...), com um GUID ou com um endereço IP (IPv4 ou
# IPv6, como o IP público de FIN-02): vira <oculto>.
# Os outros números, as datas e o texto comum (SKU, tamanho) continuam como estão.
function Protect-Detalhe {
    param($Mapas, [string]$Chave, $Valor)
    if (Test-ValorEmReais $Chave $Valor) { return Get-Dezena $Valor }
    if ($null -eq $Valor -or $Valor -is [ValueType]) { return $Valor }
    $texto = if ($Valor -is [string]) { $Valor } else { ConvertTo-Json -InputObject $Valor -Depth 5 -Compress }

    foreach ($mapa in $Mapas.Values) {
        if ($mapa.ContainsKey($texto)) { return $mapa[$texto] }
    }
    $identificador = '/(subscriptions|resourcegroups|providers)/|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    if ($texto -match $identificador -or (Test-TemIp $texto)) { return '<oculto>' }
    foreach ($mapa in $Mapas.Values) {
        foreach ($original in $mapa.Keys) {
            if ($texto.IndexOf($original, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return '<oculto>' }
        }
    }
    $Valor
}

# O texto tem um endereço IP? IPv4: quatro números de 0 a 255 separados por ponto (10.0.2.5,
# 203.0.113.10, também dentro de 10.0.0.0/16). IPv6: um trecho de grupos hexadecimais separados
# por dois-pontos que o .NET aceita como endereço IPv6 (2001:db8::10); a hora 18:45:00 não passa.
function Test-TemIp {
    param([string]$Texto)
    $octeto = '(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)'
    if ($Texto -match "(?<![\d.])(?:$octeto\.){3}$octeto(?![\d.])") { return $true }
    foreach ($trecho in [regex]::Matches($Texto, '(?<![0-9A-Fa-f:.])(?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f.]*(?![0-9A-Fa-f:.])')) {
        $endereco = $null
        if ([System.Net.IPAddress]::TryParse($trecho.Value, [ref]$endereco) -and
            $endereco.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) { return $true }
    }
    $false
}

# O rótulo de um nome: o mesmo da primeira vez em que ele apareceu, ou o próximo do prefixo (disco-01, disco-02...).
function Get-Rotulo {
    param($Mapa, $Contadores, $Original, [string]$Prefixo)
    if ($null -eq $Original -or '' -eq $Original) { return $Original }
    $chave = [string]$Original
    if (-not $Mapa.ContainsKey($chave)) {
        $Contadores[$Prefixo] = 1 + [int]$Contadores[$Prefixo]
        $Mapa[$chave] = '{0}-{1:00}' -f $Prefixo, $Contadores[$Prefixo]
    }
    $Mapa[$chave]
}

# Escapa um valor para o HTML, para que nenhum nome vire código na página.
# Troca só os 5 caracteres especiais e deixa os acentos como estão.
function ConvertTo-TextoHtml {
    param($Texto)
    ([string]$Texto).Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace("'", '&#39;')
}

# "1 achado", "3 achados".
function Format-Quantidade {
    param([int]$Numero, [string]$Singular, [string]$Plural)
    if ($Numero -eq 1) { "1 $Singular" } else { "$Numero $Plural" }
}

# Classe CSS da severidade, para a cor do selo.
function Get-ClasseSeveridade {
    param([string]$Severidade)
    switch ($Severidade) {
        'Alta'  { 'sev-alta' }
        'Média' { 'sev-media' }
        'Baixa' { 'sev-baixa' }
        default { 'sev-outra' }
    }
}

# Um valor de detalhe pronto para ler: data em dd/MM/aaaa, lista ou objeto em JSON curto.
function Format-Valor {
    param($Valor)
    if ($null -eq $Valor) { return '—' }
    if ($Valor -is [datetime]) { return $Valor.ToString('dd/MM/yyyy', [cultureinfo]::InvariantCulture) }
    if ($Valor -is [string] -or $Valor -is [ValueType]) { return [string]$Valor }
    ConvertTo-Json -InputObject $Valor -Depth 5 -Compress
}

# Um número no formato brasileiro, com duas casas: 1.234,56. Monta o formato à mão para dar o
# mesmo resultado em qualquer máquina, no PowerShell 7 e no 5.1.
function Format-Numero {
    param($Valor)
    $formato = New-Object System.Globalization.NumberFormatInfo
    $formato.NumberDecimalSeparator = ','
    $formato.NumberGroupSeparator = '.'
    ([decimal]$Valor).ToString('N2', $formato)
}

# Um valor em reais no formato brasileiro: R$ 1.234,56.
function Format-Reais {
    param($Valor)
    'R$ ' + (Format-Numero $Valor)
}

# A conta da economia: o total do que foi estimado, separado da contagem do "não sei".
function Get-ResumoDaEconomia {
    param($Achados)
    $estimados = @($Achados | Where-Object EconomiaStatus -eq 'estimada')
    $total = [decimal]0
    foreach ($achado in $estimados) { $total += [decimal]$achado.Economia }
    @{ Total = $total; Estimados = $estimados.Count; NaoSei = @($Achados | Where-Object EconomiaStatus -eq 'nao-sei').Count }
}

# O resumo da economia em texto, para a tela e para os cartões do topo do HTML. Os dois saem dos
# mesmos pedaços: a tela junta cada um em uma frase (Estimada e NaoSei), e o cartão do HTML põe
# cada pedaço num estilo (Titulo, o Valor grande com o Periodo, o Complemento menor; o número e o
# RotuloNaoSei no cartão do "não sei"). Sem achado com preço, Valor fica $null.
function Get-FrasesDaEconomia {
    param($Resumo)
    $frases = @{ Titulo = 'Economia estimada:'; Valor = $null; Periodo = '/mês' }
    if ($Resumo.Estimados -gt 0) {
        $frases.Valor = Format-Reais $Resumo.Total
        $frases.Complemento = "somando $(Format-Quantidade $Resumo.Estimados 'achado com preço' 'achados com preço')"
        $frases.Estimada = "$($frases.Titulo) $($frases.Valor)$($frases.Periodo), $($frases.Complemento)."
    } else {
        $frases.Complemento = 'nenhum achado com preço'
        $frases.Estimada = "$($frases.Titulo) $($frases.Complemento)."
    }
    $frases.RotuloNaoSei = "$(if ($Resumo.NaoSei -eq 1) { 'achado' } else { 'achados' }) sem estimativa (não sei)"
    $frases.NaoSei = "$($Resumo.NaoSei) $($frases.RotuloNaoSei)."
    $frases
}

# A célula de economia de um achado: R$ por mês com a origem do valor logo abaixo (custo real,
# preço de tabela ou Advisor), ou "não sei" com o motivo.
function Format-EconomiaHtml {
    param($Achado)
    if ($Achado.EconomiaStatus -eq 'estimada') {
        $origem = switch ($Achado.EconomiaOrigem) {
            'custo-real'      { 'custo real, últimos 30 dias' }
            'preco-de-tabela' { 'preço de tabela' }
            'advisor'         { 'Advisor' }
            default           { '' }
        }
        return "<span class=""reais"">$(ConvertTo-TextoHtml (Format-Reais $Achado.Economia))</span> <small class=""origem origem-$(ConvertTo-TextoHtml $Achado.EconomiaOrigem)"">$origem</small>"
    }
    $motivo = ConvertTo-TextoHtml $Achado.EconomiaMotivo
    "<span class=""nao-sei"">não sei</span> <small class=""motivo"">$motivo</small>"
}

function New-HtmlDoRelatorio {
    param($Regras, $Achados, [string]$SubscriptionId, [string]$Fonte, [switch]$Anonimizado, [string]$RotuloPrecos, $LeituraDoCusto)

    # Com -CustoReal, o topo diz de onde veio o custo real, ou por que ele não foi lido.
    $metaCustoReal = ''
    $notaCustoReal = ''
    if ($LeituraDoCusto) {
        $comCustoReal = @($Achados | Where-Object EconomiaOrigem -eq 'custo-real').Count
        $textoCustoReal = if ($LeituraDoCusto.Aviso) { $LeituraDoCusto.Aviso }
        else { "$($LeituraDoCusto.Origem): $(Format-Quantidade $comCustoReal 'achado' 'achados') com o custo real" }
        $metaCustoReal = "<div><dt>Custo real</dt><dd>$(ConvertTo-TextoHtml $textoCustoReal)</dd></div>"
        if (-not $LeituraDoCusto.Aviso) {
            $notaCustoReal = ' O valor marcado como "custo real" é o que o recurso custou nos últimos 30 dias, segundo o Cost Management.'
        }
    }

    $selo = if ($Anonimizado) {
        '<p class="selo-anonimizado">Modo anonimizado: nomes trocados por rótulos e valores arredondados para a dezena</p>'
    } else { '' }
    $geradoEm = (Get-Date).ToString('dd/MM/yyyy HH:mm', [cultureinfo]::InvariantCulture)
    $rotuloFonte = if ($Fonte -eq 'Arquivo') { 'Arquivo (JSON salvo, não é leitura ao vivo)' } else { 'Azure (az graph query)' }
    $regrasComAchado = @($Regras | Where-Object { $id = $_.Id; @($Achados | Where-Object Regra -eq $id).Count -gt 0 })
    $economia = Get-ResumoDaEconomia $Achados
    # Os mesmos pedaços de texto do resumo na tela (Get-FrasesDaEconomia), cada um com o seu estilo.
    $frases = Get-FrasesDaEconomia $economia
    $numeroEconomia = if ($null -ne $frases.Valor) { "$(ConvertTo-TextoHtml $frases.Valor)<small>$(ConvertTo-TextoHtml $frases.Periodo)</small>" } else { '—' }
    $cartaoEconomia = "<span class=""titulo-cartao"">$(ConvertTo-TextoHtml $frases.Titulo)</span> <span class=""numero"">$numeroEconomia</span> <span class=""rotulo"">$(ConvertTo-TextoHtml $frases.Complemento)</span>"
    $cartaoNaoSei = "<span class=""numero"">$($economia.NaoSei)</span> <span class=""rotulo"">$(ConvertTo-TextoHtml $frases.RotuloNaoSei)</span>"

    $linhasResumo = foreach ($regra in $Regras) {
        $daRegra = @($Achados | Where-Object Regra -eq $regra.Id)
        $qtd = $daRegra.Count
        $classeLinha = if ($qtd -eq 0) { ' class="zerada"' } else { '' }
        $id = ConvertTo-TextoHtml $regra.Id
        $daEconomia = Get-ResumoDaEconomia $daRegra
        $celulaEconomia = if ($qtd -eq 0) { '—' }
        elseif ($daEconomia.Estimados -eq 0) { '<span class="nao-sei">não sei</span>' }
        else {
            $mais = if ($daEconomia.NaoSei -gt 0) { " <span class=""nao-sei"">+ $($daEconomia.NaoSei) não sei</span>" } else { '' }
            "$(Format-Reais $daEconomia.Total)$mais"
        }
        @"
        <tr$classeLinha>
          <td><a href="#$id">$id</a></td>
          <td>$(ConvertTo-TextoHtml $regra.Titulo)</td>
          <td><span class="sev $(Get-ClasseSeveridade $regra.Severidade)">$(ConvertTo-TextoHtml $regra.Severidade)</span></td>
          <td class="num">$qtd</td>
          <td class="num">$celulaEconomia</td>
        </tr>
"@
    }

    $secoesRegras = foreach ($regra in $Regras) {
        $daRegra = @($Achados | Where-Object Regra -eq $regra.Id)
        $classeSev = Get-ClasseSeveridade $regra.Severidade
        $classeSecao = $classeSev
        $id = ConvertTo-TextoHtml $regra.Id
        if ($daRegra.Count -eq 0) {
            $classeSecao = "$classeSev sem-achado"
            $corpo = '        <p class="vazio">Nenhum achado: nada para economizar nesta regra.</p>'
        } else {
            $linhas = foreach ($achado in $daRegra) {
                $chips = foreach ($chave in $achado.Detalhes.Keys) {
                    "<span class=""chip""><b>$(ConvertTo-TextoHtml $chave)</b> $(ConvertTo-TextoHtml (Format-Valor $achado.Detalhes[$chave]))</span>"
                }
                $local = if ($achado.Local) { $achado.Local } else { '—' }
                @"
            <tr>
              <td class="recurso">$(ConvertTo-TextoHtml $achado.Recurso)</td>
              <td>$(ConvertTo-TextoHtml $achado.GrupoDeRecursos)</td>
              <td>$(ConvertTo-TextoHtml $local)</td>
              <td class="economia">$(Format-EconomiaHtml $achado)</td>
              <td class="detalhes">$($chips -join ' ')</td>
            </tr>
"@
            }
            $corpo = @"
        <div class="rolagem">
          <table class="achados">
            <thead><tr><th>Recurso</th><th>Grupo de recursos</th><th>Local</th><th class="num">Economia/mês</th><th>Detalhes</th></tr></thead>
            <tbody>
$($linhas -join "`n")
            </tbody>
          </table>
        </div>
"@
        }
        @"
      <section class="regra $classeSecao" id="$id">
        <header class="cabecalho-regra">
          <span class="id">$id</span>
          <h3>$(ConvertTo-TextoHtml $regra.Titulo)</h3>
          <span class="sev $classeSev">$(ConvertTo-TextoHtml $regra.Severidade)</span>
          <span class="contagem">$(Format-Quantidade $daRegra.Count 'achado' 'achados')</span>
        </header>
$corpo
        <details>
          <summary>Ver a KQL desta regra</summary>
          <pre><code>$(ConvertTo-TextoHtml $regra.Kql)</code></pre>
        </details>
      </section>
"@
    }

    $estilo = @'
    :root {
      --fundo: #f4f6f9; --superficie: #ffffff; --texto: #1b2430; --suave: #5a6576; --borda: #e2e7ee;
      --destaque: #0f6cbd; --topo-1: #0b2545; --topo-2: #134074;
      --alta-fundo: #fde7e9; --alta-texto: #a4262c; --alta-borda: #d13438;
      --media-fundo: #fff4ce; --media-texto: #7a5200; --media-borda: #e3a400;
      --baixa-fundo: #e5f1fb; --baixa-texto: #0f548c; --baixa-borda: #2b88d8;
      --economia: #0e7a0d;
    }
    @media (prefers-color-scheme: dark) {
      :root {
        --fundo: #11151b; --superficie: #1a2029; --texto: #e7eaef; --suave: #9ba6b5; --borda: #2b333e;
        --destaque: #62abf5; --topo-1: #0a1a30; --topo-2: #12345e;
        --alta-fundo: #3d1b1f; --alta-texto: #ff9ca1; --alta-borda: #e5555b;
        --media-fundo: #3a2f12; --media-texto: #f3c95f; --media-borda: #d9a21b;
        --baixa-fundo: #13304b; --baixa-texto: #8fc9ff; --baixa-borda: #3c97e6;
        --economia: #6ccb5f;
      }
    }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--fundo); color: var(--texto);
      font: 15px/1.55 "Segoe UI", system-ui, -apple-system, Roboto, "Helvetica Neue", Arial, sans-serif; }
    code, pre { font-family: "Cascadia Code", Consolas, "SF Mono", Menlo, monospace; }
    .topo { background: linear-gradient(135deg, var(--topo-1), var(--topo-2)); color: #fff; padding: 40px 0 72px; }
    .topo .miolo, main, footer { max-width: 1100px; margin: 0 auto; padding-left: 24px; padding-right: 24px; }
    .marca { text-transform: uppercase; letter-spacing: .14em; font-size: 12px; font-weight: 600; opacity: .75; }
    h1 { margin: 6px 0 4px; font-size: 34px; line-height: 1.2; font-weight: 700; }
    .topo p { margin: 0; opacity: .85; }
    .topo .selo-anonimizado { display: inline-block; margin: 14px 0 0; padding: 4px 14px; border-radius: 999px;
      background: #ffd23f; color: #1b2430; font-size: 13px; font-weight: 700; opacity: 1; }
    .meta { display: flex; flex-wrap: wrap; gap: 12px 36px; margin: 22px 0 0; }
    .meta div { min-width: 0; }
    .meta dt { font-size: 12px; text-transform: uppercase; letter-spacing: .08em; opacity: .7; }
    .meta dd { margin: 2px 0 0; font-weight: 600; overflow-wrap: anywhere; }
    main { margin-top: -44px; }
    .cartoes { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; }
    .cartao { background: var(--superficie); border: 1px solid var(--borda); border-radius: 12px; padding: 18px 20px;
      box-shadow: 0 4px 16px rgba(10, 30, 60, .08); }
    .cartao .numero { display: block; font-size: 36px; font-weight: 700; line-height: 1.1; }
    .cartao .rotulo { color: var(--suave); }
    .cartao.principal .numero { color: var(--destaque); }
    h2 { font-size: 20px; margin: 36px 0 12px; }
    .painel { background: var(--superficie); border: 1px solid var(--borda); border-radius: 12px; overflow: hidden; }
    .rolagem { overflow-x: auto; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: 10px 14px; border-bottom: 1px solid var(--borda); vertical-align: top; }
    th { font-size: 12px; text-transform: uppercase; letter-spacing: .06em; color: var(--suave); font-weight: 600; }
    tbody tr:last-child td { border-bottom: 0; }
    td.num, th.num { text-align: right; font-variant-numeric: tabular-nums; font-weight: 600; }
    tr.zerada td { color: var(--suave); }
    a { color: var(--destaque); font-weight: 600; text-decoration: none; }
    a:hover { text-decoration: underline; }
    .sev { display: inline-block; padding: 2px 10px; border-radius: 999px; font-size: 12px; font-weight: 700;
      border: 1px solid transparent; white-space: nowrap; }
    .sev.sev-alta { background: var(--alta-fundo); color: var(--alta-texto); border-color: var(--alta-borda); }
    .sev.sev-media { background: var(--media-fundo); color: var(--media-texto); border-color: var(--media-borda); }
    .sev.sev-baixa { background: var(--baixa-fundo); color: var(--baixa-texto); border-color: var(--baixa-borda); }
    .sev.sev-outra { background: var(--fundo); color: var(--suave); border-color: var(--borda); }
    .regra { background: var(--superficie); border: 1px solid var(--borda); border-left: 5px solid var(--borda);
      border-radius: 12px; margin: 0 0 18px; overflow: hidden; }
    .regra.sev-alta { border-left-color: var(--alta-borda); }
    .regra.sev-media { border-left-color: var(--media-borda); }
    .regra.sev-baixa { border-left-color: var(--baixa-borda); }
    .regra.sem-achado { border-left-color: var(--borda); }
    table.resumo { min-width: 560px; }
    table.resumo a { white-space: nowrap; }
    table.achados { min-width: 900px; }
    .cartao .titulo-cartao { display: block; color: var(--suave); font-weight: 600; }
    .cartao.economia .numero { color: var(--economia); font-size: 30px; white-space: nowrap; }
    .cartao.economia .numero small { font-size: 16px; font-weight: 600; color: var(--suave); }
    .nota-economia { margin: 12px 2px 0; color: var(--suave); font-size: 13px; }
    .nao-sei { display: inline-block; padding: 1px 9px; border-radius: 999px; border: 1px dashed var(--suave);
      background: var(--fundo); color: var(--suave); font-size: 12px; font-weight: 700; white-space: nowrap; }
    td.economia { text-align: right; min-width: 150px; }
    td.economia .reais { font-weight: 700; font-variant-numeric: tabular-nums; white-space: nowrap; color: var(--economia); }
    td.economia .motivo { display: block; margin: 4px 0 0 auto; max-width: 240px; text-align: left; font-size: 12px;
      line-height: 1.4; color: var(--suave); }
    td.economia .origem { display: block; margin-top: 2px; font-size: 11px; color: var(--suave); white-space: nowrap; }
    td.economia .origem-custo-real { color: var(--economia); font-weight: 700; }
    .cabecalho-regra { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 12px; padding: 16px 18px;
      border-bottom: 1px solid var(--borda); }
    .cabecalho-regra h3 { margin: 0; font-size: 17px; flex: 1 1 260px; }
    .cabecalho-regra .id { font-family: "Cascadia Code", Consolas, monospace; font-weight: 700; color: var(--suave); }
    .contagem { color: var(--suave); font-weight: 600; }
    td.recurso { font-weight: 600; overflow-wrap: anywhere; }
    .chip { display: inline-block; margin: 0 6px 4px 0; padding: 1px 8px; border-radius: 6px; background: var(--fundo);
      border: 1px solid var(--borda); font-size: 13px; white-space: nowrap; }
    .chip b { color: var(--suave); font-weight: 600; margin-right: 4px; }
    .vazio { margin: 0; padding: 16px 18px; color: var(--suave); }
    details { border-top: 1px solid var(--borda); padding: 10px 18px; }
    summary { cursor: pointer; color: var(--suave); font-size: 13px; font-weight: 600; }
    pre { margin: 10px 0 4px; padding: 12px 14px; background: var(--fundo); border-radius: 8px; overflow-x: auto; font-size: 13px; }
    footer { padding-top: 28px; padding-bottom: 40px; color: var(--suave); font-size: 13px; }
    @media (max-width: 600px) {
      h1 { font-size: 27px; } .topo { padding: 28px 0 64px; }
      .topo .miolo, main, footer { padding-left: 16px; padding-right: 16px; }
    }
'@

    @"
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Relatório FinOps</title>
  <style>
$estilo
  </style>
</head>
<body>
  <header class="topo">
    <div class="miolo">
      <div class="marca">FinOps no Azure</div>
      <h1>Relatório FinOps</h1>
      <p>Desperdício encontrado na subscription segundo as regras FinOps, lido sem alterar nada.</p>
      $selo
      <dl class="meta">
        <div><dt>Subscription</dt><dd><code>$(ConvertTo-TextoHtml $SubscriptionId)</code></dd></div>
        <div><dt>Gerado em</dt><dd>$geradoEm</dd></div>
        <div><dt>Fonte dos dados</dt><dd>$rotuloFonte</dd></div>
        <div><dt>Preços</dt><dd>$(ConvertTo-TextoHtml $RotuloPrecos)</dd></div>
        $metaCustoReal
      </dl>
    </div>
  </header>
  <main>
    <section class="cartoes" aria-label="Resumo">
      <div class="cartao principal"><span class="numero">$($Achados.Count)</span><span class="rotulo">$(if ($Achados.Count -eq 1) { 'achado' } else { 'achados' }) no total</span></div>
      <div class="cartao"><span class="numero">$($regrasComAchado.Count)</span><span class="rotulo">$(if ($regrasComAchado.Count -eq 1) { 'regra' } else { 'regras' }) com achado, de $(Format-Quantidade $Regras.Count 'verificada' 'verificadas')</span></div>
      <div class="cartao economia">$cartaoEconomia</div>
      <div class="cartao cartao-nao-sei">$cartaoNaoSei</div>
    </section>
    <p class="nota-economia">A economia estimada soma só os achados com preço confiável: o preço de tabela do medidor ou o valor que o próprio Advisor informa. Quando não há preço confiável, o achado mostra "não sei", e não 0.$(ConvertTo-TextoHtml $notaCustoReal)</p>

    <h2>Resumo por regra</h2>
    <div class="painel rolagem">
      <table class="resumo">
        <thead><tr><th>Regra</th><th>O que procura</th><th>Severidade</th><th class="num">Achados</th><th class="num">Economia/mês</th></tr></thead>
        <tbody>
$($linhasResumo -join "`n")
        </tbody>
      </table>
    </div>

    <h2>Achados por regra</h2>
$($secoesRegras -join "`n")
  </main>
  <footer>Relatório gerado só com leitura: nenhum recurso do Azure foi criado, alterado ou apagado.</footer>
</body>
</html>
"@
}

# Grava um texto em UTF-8 sem BOM, igual no PowerShell 7 e no 5.1.
function Write-Texto {
    param([string]$Caminho, [string]$Texto)
    [System.IO.File]::WriteAllText($Caminho, $Texto, [System.Text.UTF8Encoding]::new($false))
}

$regras = @(Get-Catalogo)
Test-FormasDaEconomia $regras

# De onde vêm os preços de tabela: o arquivo de -TabelaDePrecos; senão, com a fonte Arquivo,
# o precos.json da pasta de dados; senão (fonte Azure), a Retail Prices API.
if ($TabelaDePrecos) {
    $script:ArquivoDePrecos = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TabelaDePrecos)
    if (-not (Test-Path -LiteralPath $script:ArquivoDePrecos -PathType Leaf)) {
        throw "Não achei a tabela de preços $script:ArquivoDePrecos, passada em -TabelaDePrecos. Confira o caminho ou rode sem esse parâmetro."
    }
} elseif ($Fonte -eq 'Arquivo') {
    $script:ArquivoDePrecos = Join-Path $PastaDados 'precos.json'
}
$rotuloPrecos = if ($script:ArquivoDePrecos) { 'Tabela de preços em arquivo (JSON salvo, não é a Retail Prices API)' }
else { 'Retail Prices API (preço de tabela em BRL, sem desconto)' }

if ($Fonte -eq 'Azure') { Test-AcessoAoAzure }
$achados = @(
    foreach ($regra in $regras) {
        foreach ($linha in Get-LinhasDaRegra $regra) { ConvertTo-Achado $regra $linha }
    }
)
$achados = @(Add-Economia -Regras $regras -Achados $achados)

# Custo real: só com -CustoReal. Sem o switch, nada é lido e nenhuma consulta de custo é feita.
$leituraDoCusto = $null
if ($CustoReal) {
    $leituraDoCusto = Read-CustoReal (Get-PeriodoDoCustoReal)
    $achados = @(Add-CustoReal -Regras $regras -Achados $achados -Custos $leituraDoCusto.Custos)
}

$subscriptionNoRelatorio = $SubscriptionId
if ($Anonimizar) {
    $anonimizado = ConvertTo-Anonimizado -Regras $regras -Achados $achados -SubscriptionId $SubscriptionId
    $achados = @($anonimizado.Achados)
    $subscriptionNoRelatorio = $anonimizado.SubscriptionId
}

$pastaSaida = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Saida)
New-Item -ItemType Directory -Path $pastaSaida -Force | Out-Null

$arquivoAchados = Join-Path $pastaSaida 'achados.json'
$arquivoHtml = Join-Path $pastaSaida 'relatorio-finops.html'
Write-Texto $arquivoAchados (ConvertTo-Json -InputObject $achados -Depth 5)
Write-Texto $arquivoHtml (New-HtmlDoRelatorio -Regras $regras -Achados $achados -SubscriptionId $subscriptionNoRelatorio -Fonte $Fonte -Anonimizado:$Anonimizar -RotuloPrecos $rotuloPrecos -LeituraDoCusto $leituraDoCusto)

Write-Host "Relatório FinOps: $(Format-Quantidade $achados.Count 'achado' 'achados') em $(Format-Quantidade $regras.Count 'regra verificada' 'regras verificadas')."
if ($Anonimizar) { Write-Host 'Modo anonimizado: nomes trocados por rótulos e valores arredondados para a dezena.' }
foreach ($regra in $regras) {
    $qtd = @($achados | Where-Object Regra -eq $regra.Id).Count
    Write-Host ("  {0}  {1}: {2}" -f $regra.Id, $regra.Titulo, $qtd)
}
$frasesDaEconomia = Get-FrasesDaEconomia (Get-ResumoDaEconomia $achados)
Write-Host $frasesDaEconomia.Estimada
Write-Host $frasesDaEconomia.NaoSei
if ($leituraDoCusto -and -not $leituraDoCusto.Aviso) {
    $comCustoReal = @($achados | Where-Object EconomiaOrigem -eq 'custo-real').Count
    Write-Host "Custo real: $(Format-Quantidade $comCustoReal 'achado' 'achados') com o custo real dos últimos 30 dias. Fonte: $($leituraDoCusto.Origem)."
}
Write-Host "Achados: $arquivoAchados"
Write-Host "HTML:    $arquivoHtml"
