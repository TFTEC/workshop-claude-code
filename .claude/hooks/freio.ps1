#requires -Version 5.1
<#
Hook-freio: hook PreToolUse do Claude Code que impede comandos de escrita no Azure.
Recebe pelo stdin o JSON do PreToolUse. Exit 2 bloqueia (o stderr vai para o Claude); exit 0 deixa passar.
#>

# ---------------------------------------------------------------------------
# Tabelas: para mudar o que o freio bloqueia, mexa aqui, não no motor.
# ---------------------------------------------------------------------------

# Partes de palavra do Azure CLI que indicam escrita. Cada palavra do comando é quebrada nos
# hífens: "upload-batch" vira "upload" e "batch", e basta uma parte estar aqui.
$script:VerbosDeEscritaAzCli = @(
    # criar, mudar, apagar
    'create', 'delete', 'update', 'set', 'unset', 'add', 'remove', 'patch', 'put', 'insert',
    'replace', 'merge', 'split', 'clear', 'purge', 'undelete', 'rename', 'move', 'copy', 'sync',
    'import', 'upload', 'push', 'publish', 'deploy', 'build', 'up', 'snapshot', 'backup',
    'restore', 'recover', 'revert', 'archive', 'extend', 'tag', 'untag', 'config', 'configure',
    # ligar, desligar, escalar
    'start', 'stop', 'restart', 'reboot', 'shutdown', 'deallocate', 'pause', 'resume', 'suspend',
    'scale', 'resize', 'redeploy', 'reimage', 'reapply', 'generalize', 'capture', 'convert',
    'swap', 'failover', 'upgrade', 'install', 'uninstall', 'migrate', 'promote', 'rollback',
    'simulate', 'perform', 'abort', 'cancel',
    # executar algo dentro do recurso
    'invoke', 'run', 'execute', 'exec', 'trigger', 'submit', 'send', 'connect', 'disconnect',
    # acesso, identidade, chaves
    'assign', 'unassign', 'grant', 'revoke', 'consent', 'approve', 'reject', 'accept',
    'reset', 'renew', 'regenerate', 'rotate', 'lock', 'unlock', 'acquire', 'release',
    'enable', 'disable', 'activate', 'deactivate', 'register', 'unregister',
    'attach', 'detach', 'link', 'unlink', 'bind', 'unbind', 'open',
    # compra
    'purchase', 'buy'
)

# Se a última palavra do comando começa com um destes, é leitura, mesmo que um grupo do caminho
# pareça escrita (ex.: "az vm run-command list", "az tag list", "az lock list").
$script:VerbosDeLeituraAzCli = @(
    'list', 'show', 'get', 'query', 'wait', 'exists', 'check', 'browse', 'tail', 'download',
    'summarize', 'search', 'find', 'version', 'count', 'view', 'calculate'
)

# Verbos do PowerShell que escrevem quando o substantivo começa por Az (Remove-AzResourceGroup,
# New-AzVM, Remove-AzureRmVM...). Get-, Search-, Connect-, Select- e outros de leitura passam.
$script:VerbosDeEscritaAz = @(
    'New', 'Set', 'Remove', 'Update', 'Start', 'Stop', 'Restart', 'Move', 'Register', 'Unregister',
    'Import', 'Publish', 'Unpublish', 'Add', 'Grant', 'Revoke', 'Enable', 'Disable', 'Suspend',
    'Resume', 'Invoke', 'Restore', 'Reset', 'Rename', 'Approve', 'Deny', 'Submit', 'Sync',
    'Install', 'Uninstall', 'Mount', 'Dismount', 'Deploy', 'Undo', 'Complete', 'Lock', 'Unlock',
    'Protect', 'Unprotect', 'Initialize', 'Convert', 'ConvertTo', 'Repair', 'Switch', 'Backup',
    'Copy', 'Clear', 'Send', 'Push', 'Join', 'Merge'
)

# Substantivos do módulo Az que só mexem no contexto local da sessão (equivalem a az account set).
$script:ExcecoesLocaisAz = @('AzContext', 'AzContextAutosave', 'AzConfig', 'AzureRmAlias', 'AzDataCollection')

# Subcomandos do Terraform que alteram o ambiente (plan, init, validate e show passam).
$script:SubcomandosDeEscritaTerraform = @('apply', 'destroy', 'import')

# Exceções: comandos do Azure CLI que só mexem na configuração local do próprio CLI, não no Azure.
# Vale o comando exato ou qualquer subcomando dele ("extension" cobre "extension add").
$script:ExcecoesLocaisAzCli = @(
    'account set'        # troca a subscription padrão no perfil local (~/.azure)
    'account clear'      # apaga as contas do perfil local; é um logout
    'config'             # az config set/unset/get: arquivo de configuração local do CLI
    'configure'          # az configure --defaults: idem
    'extension'          # instala, atualiza e remove extensões do CLI (ex.: resource-graph)
    'upgrade'            # atualiza o próprio CLI
    'bicep build', 'bicep build-params', 'bicep install', 'bicep uninstall', 'bicep upgrade'  # compila e instala o Bicep na máquina
    'aks install-cli'    # instala o kubectl na máquina
)

# ---------------------------------------------------------------------------
# Entrada e saída do hook
# ---------------------------------------------------------------------------

function Read-EntradaDoHook {
    if (-not [Console]::IsInputRedirected) { return '' }
    $memoria = New-Object System.IO.MemoryStream
    [Console]::OpenStandardInput().CopyTo($memoria)
    # Sem o BOM, o ConvertFrom-Json falharia e o freio deixaria passar.
    return [System.Text.Encoding]::UTF8.GetString($memoria.ToArray()).TrimStart([char]0xFEFF)
}

function Write-Bloqueio([string]$Trecho) {
    $mensagem = "Hook-freio: comando de escrita no Azure bloqueado: $Trecho. O workshop só lê o Azure.`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($mensagem)
    $erro = [Console]::OpenStandardError()
    $erro.Write($bytes, 0, $bytes.Length)
    $erro.Flush()
}

# ---------------------------------------------------------------------------
# Leitura do comando: segmentos e palavras, respeitando aspas
# ---------------------------------------------------------------------------

# Fora das aspas, estes caracteres separam um comando do outro: && || ; | & quebra de linha,
# $( ) e { } (subcomandos e blocos), ` (subcomando do bash) e < > (redirecionamento).
$script:Separadores = [char[]]@(';', '&', '|', "`n", "`r", '(', ')', '{', '}', '`', '<', '>')

function Split-Comando([string]$Texto) {
    # Continuação de linha (\ no bash, ` no PowerShell) junta as linhas num comando só.
    $Texto = $Texto -replace '(\\|`)[ \t]*\r?\n', ' '
    $segmentos = New-Object System.Collections.ArrayList
    $tokens = New-Object System.Collections.ArrayList
    $citacoes = New-Object System.Collections.ArrayList
    $token = New-Object System.Text.StringBuilder
    $temToken = $false
    $inicio = 0
    $i = 0
    while ($i -le $Texto.Length) {
        $separa = $i -eq $Texto.Length -or $Texto[$i] -in $script:Separadores
        # Chave no meio de uma palavra é literal: /subscriptions/{subscriptionId}/, ${VAR}, @{a=1}.
        if ($separa -and $i -lt $Texto.Length -and $temToken) {
            if ($Texto[$i] -eq '{' -or ($Texto[$i] -eq '}' -and $token.ToString().Contains('{'))) { $separa = $false }
        }
        if ($separa) {
            if ($temToken) { [void]$tokens.Add($token.ToString()); [void]$token.Clear(); $temToken = $false }
            if ($tokens.Count -gt 0) {
                $bruto = $Texto.Substring($inicio, $i - $inicio).Trim().TrimEnd('$', '@').Trim()
                [void]$segmentos.Add([pscustomobject]@{
                        Texto    = ($bruto -replace '\s+', ' ')
                        Tokens   = @($tokens)
                        Citacoes = @($citacoes)
                    })
            }
            $tokens.Clear(); $citacoes.Clear()
            $inicio = $i + 1
            $i++
            continue
        }
        $c = $Texto[$i]
        if ($c -eq '"' -or $c -eq "'") {
            $conteudo = New-Object System.Text.StringBuilder
            $j = $i + 1
            while ($j -lt $Texto.Length -and $Texto[$j] -ne $c) {
                if ($c -eq '"' -and ($Texto[$j] -eq '\' -or $Texto[$j] -eq '`') -and $j + 1 -lt $Texto.Length -and $Texto[$j + 1] -eq '"') {
                    $j++
                }
                [void]$conteudo.Append($Texto[$j])
                $j++
            }
            [void]$token.Append($conteudo.ToString())
            [void]$citacoes.Add($conteudo.ToString())
            $temToken = $true
            $i = [Math]::Min($j + 1, $Texto.Length)  # aspa sem fechamento vai até o fim
            continue
        }
        if ([char]::IsWhiteSpace($c) -or $c -eq ',') {
            if ($temToken) { [void]$tokens.Add($token.ToString()); [void]$token.Clear(); $temToken = $false }
            $i++
            continue
        }
        [void]$token.Append($c)
        $temToken = $true
        $i++
    }
    return , $segmentos
}

function Get-NomeDoExecutavel([string]$Token) {
    return (($Token -replace '^.*[\\/]', '') -replace '\.(cmd|exe|bat|ps1)$', '').ToLowerInvariant()
}

# ---------------------------------------------------------------------------
# Regras
# ---------------------------------------------------------------------------

function Get-PalavrasDeComando([string[]]$Argumentos) {
    $palavras = New-Object System.Collections.ArrayList
    foreach ($arg in $Argumentos) {
        if ($arg.StartsWith('-')) {
            if ($palavras.Count -gt 0) { break }
            continue
        }
        [void]$palavras.Add($arg.ToLowerInvariant())
    }
    return , $palavras
}

# az rest: só GET passa (é o padrão quando não há --method). A exceção é a consulta de custo
# do bônus, um POST de leitura em .../providers/Microsoft.CostManagement/query.
function Test-RestDeEscrita([string[]]$Argumentos) {
    $metodo = 'get'
    $url = ''
    for ($i = 0; $i -lt $Argumentos.Count; $i++) {
        $arg = $Argumentos[$i].ToLowerInvariant()
        $proximo = if ($i + 1 -lt $Argumentos.Count) { $Argumentos[$i + 1].ToLowerInvariant() } else { '' }
        if ($arg -in '--method', '-m') { $metodo = $proximo }
        elseif ($arg -match '^(--method|-m)=(.*)$') { $metodo = $Matches[2] }
        elseif ($arg -in '--url', '--uri', '-u') { $url = $proximo }
        elseif ($arg -match '^(--url|--uri|-u)=(.*)$') { $url = $Matches[2] }
    }
    if ($metodo -eq 'get') { return $false }
    if ($metodo -eq 'post' -and $url -match '/providers/microsoft\.costmanagement/query(\?|$)') { return $false }
    return $true
}

function Test-EscritaAzCli([string[]]$Argumentos) {
    $palavras = Get-PalavrasDeComando $Argumentos
    if ($palavras.Count -eq 0) { return $false }
    if ($palavras[0] -eq 'rest') { return (Test-RestDeEscrita $Argumentos) }
    if ($palavras -contains 'deployment') { return $true }
    $caminho = $palavras -join ' '
    foreach ($excecao in $script:ExcecoesLocaisAzCli) {
        if ($caminho -eq $excecao -or $caminho.StartsWith("$excecao ")) { return $false }
    }
    $ultima = $palavras[$palavras.Count - 1]
    if (($ultima -split '-')[0] -in $script:VerbosDeLeituraAzCli) { return $false }
    foreach ($palavra in $palavras) {
        foreach ($parte in ($palavra -split '-')) {
            if ($parte -in $script:VerbosDeEscritaAzCli) { return $true }
        }
    }
    return $false
}

function Test-EscritaTerraform([string[]]$Argumentos) {
    # O subcomando é a primeira palavra que não é opção: terraform -chdir=infra apply.
    foreach ($arg in $Argumentos) {
        if ($arg.StartsWith('-')) { continue }
        return ($arg -in $script:SubcomandosDeEscritaTerraform)
    }
    return $false
}

function Test-CmdletDeEscritaAz([string]$Token) {
    # Aceita o nome qualificado pelo módulo: Az.Resources\Remove-AzResourceGroup.
    if ($Token -notmatch '^(?:[\w.]+\\)?(?<verbo>[a-z]+)-(?<substantivo>az\w*)$') { return $false }
    return ($Matches['verbo'] -in $script:VerbosDeEscritaAz) -and ($Matches['substantivo'] -notin $script:ExcecoesLocaisAz)
}

# Um segmento é de escrita se qualquer palavra dele inicia um comando de escrita.
function Test-SegmentoDeEscrita([string[]]$Tokens) {
    for ($i = 0; $i -lt $Tokens.Count; $i++) {
        $resto = @()
        if ($i + 1 -lt $Tokens.Count) { $resto = $Tokens[($i + 1)..($Tokens.Count - 1)] }
        $nome = Get-NomeDoExecutavel $Tokens[$i]
        if ($nome -eq 'az' -and (Test-EscritaAzCli $resto)) { return $true }
        if ($nome -eq 'terraform' -and (Test-EscritaTerraform $resto)) { return $true }
        if (Test-CmdletDeEscritaAz $Tokens[$i]) { return $true }
    }
    return $false
}

# Devolve a parte do comando que escreve no Azure, ou $null. O texto entre aspas também é
# avaliado como comando, para pegar bash -c "...", pwsh -Command "...", Invoke-Expression '...'.
function Find-TrechoDeEscrita([string]$Comando, [int]$Profundidade = 0) {
    foreach ($segmento in (Split-Comando $Comando)) {
        if (Test-SegmentoDeEscrita $segmento.Tokens) { return $segmento.Texto }
        if ($Profundidade -lt 4) {
            foreach ($citacao in $segmento.Citacoes) {
                $trecho = Find-TrechoDeEscrita $citacao ($Profundidade + 1)
                if ($trecho) { return $trecho }
            }
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
# Ponto de entrada
# ---------------------------------------------------------------------------

# Ferramentas do Claude Code que executam comando de shell em tool_input.command.
$script:FerramentasDeShell = @('Bash', 'PowerShell', 'Monitor')

# Devolve o comando de shell da chamada, ou $null se a entrada não for de uma ferramenta de shell.
function Get-ComandoDeShell([string]$Json) {
    try { $entrada = $Json | ConvertFrom-Json -ErrorAction Stop } catch { return $null }
    if ($null -eq $entrada -or $entrada -isnot [System.Management.Automation.PSCustomObject]) { return $null }
    if (-not $entrada.PSObject.Properties['tool_name'] -or $entrada.tool_name -notin $script:FerramentasDeShell) { return $null }
    if (-not $entrada.PSObject.Properties['tool_input'] -or $entrada.tool_input -isnot [System.Management.Automation.PSCustomObject]) { return $null }
    $comando = $entrada.tool_input.PSObject.Properties['command']
    if (-not $comando -or $comando.Value -isnot [string]) { return $null }
    return $comando.Value
}

# Entrada inválida ou sem comando deixa passar (exit 0): o freio não pode quebrar a sessão.
$comando = Get-ComandoDeShell (Read-EntradaDoHook)
if (-not $comando) { exit 0 }
$trecho = Find-TrechoDeEscrita $comando
if ($trecho) {
    Write-Bloqueio $trecho
    exit 2
}
exit 0
