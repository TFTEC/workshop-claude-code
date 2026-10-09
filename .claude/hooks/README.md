# Hook-freio

O hook-freio impede o Claude Code de rodar qualquer comando que altere o ambiente Azure. Os comandos de leitura passam normalmente. Ele é a condição para apontar o Claude para o Azure da empresa onde você trabalha.

| Arquivo | O que é |
|---|---|
| `.claude/hooks/freio.ps1` | O hook. As listas do que bloqueia e do que passa ficam no topo do arquivo. |
| `.claude/settings.json` | O registro do hook no projeto. |
| `testes/freio.Tests.ps1` | Os testes (Pester 5), com a tabela de casos. |

## Como funciona

1. Antes de cada chamada das ferramentas de shell do Claude (`Bash`, `PowerShell` e `Monitor`), o Claude Code roda o `freio.ps1` e manda pelo stdin um JSON com a chamada. O comando vem em `tool_input.command`.
2. O freio quebra o comando em partes (`&&`, `||`, `;`, `|`, quebras de linha, `$(...)`, blocos `{ }`) e avalia cada uma, sem diferenciar maiúsculas de minúsculas. O texto entre aspas também é avaliado, para pegar casos como `bash -c "..."` e `pwsh -Command "..."`.
3. Se alguma parte escreve no Azure, o freio sai com **exit 2** e explica o motivo em português no stderr. O Claude Code bloqueia a chamada e mostra essa mensagem ao Claude:

   ```
   Hook-freio: comando de escrita no Azure bloqueado: az group delete -n rg-app --yes. O workshop só lê o Azure.
   ```

4. Se nada escreve no Azure, o freio sai com **exit 0** e a chamada segue o fluxo normal de permissões.
5. Se o JSON vier inválido ou sem comando, o freio sai com exit 0, para não travar a sessão.

## Como registrar

O registro fica no `.claude/settings.json` do projeto. Assim ele entra no git e vale para quem clonar o repositório. Não coloque o freio no `~/.claude/settings.json`, porque ali ele valeria para todos os seus projetos.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|PowerShell|Monitor",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh",
            "args": ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
                     "${CLAUDE_PROJECT_DIR}/.claude/hooks/freio.ps1"],
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

- **`matcher`**: cobre as três ferramentas que executam comando de shell. No Windows, o Claude usa a ferramenta `PowerShell` como shell principal. Um hook que casa só com `Bash` nunca dispararia ali.
- **`command` + `args`** (forma exec): o Claude Code chama o `pwsh` direto, sem passar por um shell. Ele mesmo troca `${CLAUDE_PROJECT_DIR}` pela raiz do projeto, então caminho com espaço não quebra. O registro é o mesmo no Windows e no macOS.
- **`pwsh`** precisa estar no PATH (PowerShell 7). No macOS, instale com `brew install powershell`. No Windows sem o PowerShell 7, troque `"pwsh"` por `"powershell.exe"`: o freio também roda no Windows PowerShell 5.1.
- **Confiança da pasta**: numa sessão interativa, o Claude Code só roda hooks depois que você aceita a pergunta de confiança da pasta.
- **Edição durante a sessão**: o Claude Code costuma perceber sozinho a mudança no `settings.json`. Se o freio não aparecer no `/hooks` depois de alguns segundos, reinicie a sessão.

## Como testar

**1. Testes automáticos** (Pester 5 no PowerShell 7):

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path testes/freio.Tests.ps1 -Output Detailed"
```

Os testes rodam o `freio.ps1` de verdade, entregam a ele o JSON do PreToolUse e conferem o exit code e a mensagem. Nenhum comando do Azure é executado. No Windows, uma parte dos casos também roda no Windows PowerShell 5.1.

**2. À mão, no seu terminal** (fora do Claude):

```powershell
'{"tool_name":"Bash","tool_input":{"command":"az group delete -n rg-teste --yes"}}' | pwsh -NoProfile -File .claude/hooks/freio.ps1; $LASTEXITCODE
```

O resultado esperado é a mensagem do freio seguida de `2`. Troque o comando por `az group list` e o resultado vira `0`, sem mensagem. No macOS, use `echo '...' | pwsh -NoProfile -File .claude/hooks/freio.ps1; echo $?`.

**3. Dentro do Claude Code:**

1. Digite `/hooks` e confira que o freio aparece em `PreToolUse`.
2. Peça ao Claude: "rode `echo az group delete --name rg-teste-do-freio`".
3. O freio bloqueia, e o Claude mostra a mensagem de bloqueio.

O teste usa `echo` de propósito: o freio olha o texto do comando, e por isso barra até um `echo` com cara de escrita. Se o freio não estiver ativo, o `echo` só imprime o texto e nada acontece no Azure.

## O que bloqueia e o que passa

| Família | Bloqueia | Passa |
|---|---|---|
| Azure CLI | Verbos de escrita: `create`, `delete`, `update`, `set`, `add`, `remove`, `start`, `stop`, `restart`, `deallocate`, `purge`, `import`, `deploy`, `assign`, `upload`, `tag`, `scale`, `move`, `invoke`, `run` e equivalentes (lista completa no topo do `freio.ps1`). Vale também com hífen: `upload-batch`, `create-for-rbac`, `revoke-access`. | `show`, `list`, `get-*`, `graph query`, `account show/list`, `login`, `logout`. Se a última palavra é de leitura, o comando passa: `az vm run-command list`, `az tag list`. |
| `az deployment` | Qualquer forma, até `list` e `what-if`; também `az group deployment` e `az webapp deployment`. | Nada. |
| `az rest` | Qualquer método diferente de GET (`put`, `patch`, `delete`, `post`, `head`...). | GET, que é o padrão quando falta `--method`. Também passa o POST em `.../providers/Microsoft.CostManagement/query` (ver exceções). |
| Módulo Az (PowerShell) | Verbo de escrita com substantivo começando por `Az`: `New-`, `Set-`, `Remove-`, `Update-`, `Start-`, `Stop-`, `Restart-`, `Move-`, `Register-`, `Import-`, `Publish-`, `Add-`, `Grant-`, `Revoke-`, `Enable-`, `Disable-`, `Suspend-`, `Resume-`, `Invoke-` e outros. Exemplos: `Remove-AzResourceGroup`, `New-AzVM`, `Remove-AzureRmVM`. | `Get-Az*`, `Search-AzGraph`, `Connect-AzAccount`, `Select-AzSubscription`. |
| Terraform | `apply`, `destroy`, `import`, também com opção antes (`terraform -chdir=infra apply`). | `init`, `plan`, `validate`, `fmt`, `show`, `state list`, `output`. |
| Fora do Azure | — | `git`, `ls`, `Get-ChildItem`, `npm`, scripts locais (`pwsh ./relatorio.ps1`). |

## Exceções e o motivo de cada uma

Estes comandos têm verbo de escrita, mas só mexem na máquina do aluno, não no Azure:

| Comando | Por que passa |
|---|---|
| `az account set`, `az account clear` | Trocam a subscription padrão ou apagam as contas, só no perfil local do CLI (`~/.azure`). Escolher a subscription é necessário para o relatório. `az account alias create`, `az account management-group create` e `az account lock create` continuam bloqueados. |
| `az extension ...` (`add`, `update`, `remove`, `list`, `show`) | Instalam e removem extensões do próprio CLI na máquina. O relatório precisa da extensão `resource-graph`. |
| `az config ...`, `az configure` | Mudam o arquivo de configuração local do CLI. |
| `az bicep build`, `build-params`, `install`, `uninstall`, `upgrade` | Compilam Bicep e instalam a ferramenta na máquina. Nada vai ao Azure. `az bicep publish` continua bloqueado, porque publica num registry. |
| `az upgrade`, `az aks install-cli` | Atualizam o CLI ou instalam o `kubectl` na máquina. |
| `az rest --method post` em `.../providers/Microsoft.CostManagement/query` | É uma consulta de custo, ou seja, leitura, mesmo sendo POST. O bônus do relatório usa essa consulta. Um POST em qualquer outro caminho do Cost Management (por exemplo, rodar um export) continua bloqueado. |
| Módulo Az: `*-AzContext`, `Enable/Disable-AzContextAutosave`, `Update-AzConfig`, `Enable/Disable-AzureRmAlias`, `Enable/Disable-AzDataCollection` | Mudam só o contexto e a configuração locais da sessão do PowerShell, como o `az account set`. |

## Limites

O freio é a segunda proteção. A primeira é a permissão: aponte o Claude para o Azure com uma identidade que tenha só o papel **Reader** na subscription. O freio não cobre estes casos:

- **Só a linha de comando**: um script (`.ps1`, `.sh`) que chame `az ... delete` por dentro passa sem ser visto. Uma variável que monta o verbo (`$v = 'delete'; az group $v`) também.
- **Outras ferramentas**: `azd`, `azcopy`, `kubectl`, chamadas diretas à API com `curl` ou `Invoke-RestMethod`, e servidores MCP. O Azure MCP da manhã deve ficar em modo somente leitura.
- **Exagero de cautela**: um texto que pareça comando de escrita também é barrado, como `git commit -m "... az group delete"` ou `grep "az vm stop"`. Nesses casos, reescreva o texto, ou use as ferramentas Grep e Write do Claude, que o freio não olha.
- **`pwsh` ausente**: se o `pwsh` não for encontrado, o hook dá erro sem bloquear e o comando segue. Por isso o teste 3 é obrigatório antes de apontar o Claude para o Azure.

## O que foi confirmado na documentação (08/10/2026)

Hooks do Claude Code: <https://code.claude.com/docs/en/hooks> e <https://code.claude.com/docs/en/hooks-guide>.

- **Entrada do PreToolUse**: um JSON no stdin com `session_id`, `cwd`, `hook_event_name`, `tool_name`, `tool_input` e `tool_use_id`. Na ferramenta `Bash`, o comando vem em `tool_input.command`.
- **Ferramenta de PowerShell**: chama-se `PowerShell`, e os campos são os mesmos do Bash, com o comando em `tool_input.command` (<https://code.claude.com/docs/en/tools-reference#powershell-tool>). No Windows, o PowerShell é o shell principal. Sem o Git Bash, o Bash nem é registrado, e por isso a documentação recomenda o matcher `Bash|PowerShell`.
- **Ferramenta Monitor**: roda um comando em segundo plano, com o comando em `command` e as mesmas regras de permissão do Bash (<https://code.claude.com/docs/en/tools-reference#monitor-tool>). Por isso ela entrou no matcher.
- **Exit code**: o 0 deixa seguir; sem saída, o fluxo normal de permissões continua. O 2 bloqueia a chamada, e o stderr vira o motivo mostrado ao Claude. Qualquer outro código, inclusive o 1, é erro não bloqueante, e a ação segue.
- **Matcher**: um valor só com letras, dígitos, `_`, `-`, espaço, `,` e `|` é uma lista exata separada por `|` ou `,`. Qualquer outro caractere transforma o valor numa expressão regular.
- **Como o comando roda**: sem `args` (forma shell), roda no `sh -c` do macOS e do Linux, no Git Bash do Windows, ou no PowerShell quando não há Git Bash. O campo `shell` aceita `"bash"` ou `"powershell"` e é ignorado quando há `args`. Com `args` (forma exec), o Claude Code chama o executável direto, sem shell, e troca os placeholders em `command` e em cada `args`. No Windows, `command` precisa ser um executável de verdade (`.exe`), e o `pwsh.exe` é.
- **`CLAUDE_PROJECT_DIR`**: é a raiz do projeto onde a sessão começou. Continua apontando para a raiz principal mesmo quando o Claude entra numa worktree. A documentação recomenda a forma exec sempre que o hook usa um placeholder de caminho.
- **Confiança e recarga**: numa sessão interativa, os hooks só rodam depois do aceite de confiança da pasta. O `/hooks` mostra os hooks configurados, e edições no `settings.json` costumam ser percebidas sem reiniciar.

`az rest`: segundo <https://learn.microsoft.com/en-us/cli/azure/reference-index?view=azure-cli-latest#az-rest>, o `--method` aceita `delete`, `get`, `head`, `options`, `patch`, `post` e `put`, e o padrão é `get`.
