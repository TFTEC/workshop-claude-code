# Exercício 7: hook-freio

**Horário:** 14h00 · **Tempo:** 20 minutos

**Objetivo:** criar com o Claude um hook que barra qualquer comando de escrita no Azure, registrar esse hook no projeto, ver o bloqueio acontecer e confirmar que a leitura continua passando.

**Feature:** hooks do Claude Code (evento `PreToolUse`), o `.claude/settings.json` do projeto, `/hooks` e o plan mode para revisar o plano antes de criar.

## Antes de começar

Um **hook** é um comando que o próprio Claude Code roda num momento fixo da sessão. O hook `PreToolUse` roda **antes** de cada chamada de ferramenta, inclusive antes da pergunta de permissão. O **hook-freio** lê o comando que o Claude vai rodar no terminal:

- **se for escrita no Azure**, o freio sai com **exit 2**. O Claude Code barra a chamada **antes de o comando rodar**: o `az` nem é chamado, e nada vai ao Azure. O Claude recebe a mensagem do freio e conta o que aconteceu;
- **se não for**, o freio sai com **exit 0**, e o comando segue o caminho de sempre, com as perguntas de permissão do modo em que você está.

> **O freio precisa estar ativo antes de qualquer passo que toque no Azure.** A partir das 15h20, o Claude trabalha com a subscription da sua empresa. Não siga para a ficha 8 antes de o `/hooks` mostrar o freio e o teste do passo 6 barrar a escrita.

O freio é a **segunda proteção**:

1. **A primeira é a permissão.** A sua conta tem só o papel **Reader** na subscription. Mesmo que um comando de escrita escape, o Azure recusa.
2. **A segunda é o freio.** O comando de escrita nem sai da sua máquina.

O combinado de `.claude/rules/combinados.md` ("o Azure só é lido") é um **pedido** ao Claude, como você viu no exercício 4: ele costuma seguir, mas nada o obriga. O freio é um **impedimento**: quem roda o freio é o Claude Code, não o modelo, e o exit 2 barra a chamada em qualquer modo de permissão, até no auto mode.

Deixe um **segundo terminal PowerShell** aberto na pasta do repositório, como no exercício 5. Confira nele que o PowerShell 7 está instalado, porque o freio roda com o `pwsh`:

```powershell
pwsh --version
```

Tem que aparecer `PowerShell 7.` seguido do resto do número. Se der erro, veja o **Travou?**.

## Passos

1. **Comece do zero.** No Claude, rode `/clear`. Depois aperte **Shift+Tab** até aparecer `⏸ plan mode on` embaixo do campo de digitar.

2. **Peça o plano do freio.** Mande:

   ```text
   Crie o hook-freio deste projeto: um hook PreToolUse do Claude Code que barra, antes de rodar, qualquer comando que altere o Azure. Requisitos:
   1. O hook é um script PowerShell em .claude/hooks/freio.ps1. Ele lê do stdin o JSON do PreToolUse e pega o comando em tool_input.command.
   2. Vale para as ferramentas Bash, PowerShell e Monitor.
   3. Bloqueia com exit 2 e uma mensagem em português no stderr, começando com "Hook-freio:":
      - verbos de escrita do Azure CLI: create, delete, update, set, add, remove, start, stop, restart, deallocate, purge, import, deploy, assign e parecidos;
      - az deployment em qualquer forma;
      - az rest com método diferente de GET;
      - cmdlets de escrita do módulo Az, como New-Az*, Set-Az*, Remove-Az*, Update-Az*, Start-Az* e Stop-Az*;
      - terraform apply e terraform destroy.
   4. Deixa passar a leitura: show, list, az graph query, az account show e az account set.
   5. Avalia cada parte de um comando composto (&&, ;, |) e não diferencia maiúsculas de minúsculas.
   6. Se o JSON vier inválido ou sem comando, sai com exit 0, para não travar a sessão.
   7. Registra o hook no .claude/settings.json do projeto, na forma exec: "command": "pwsh" e "args" com -NoProfile, -NonInteractive, -ExecutionPolicy, Bypass, -File e "${CLAUDE_PROJECT_DIR}/.claude/hooks/freio.ps1".
   Não rode nenhum comando az.
   ```

   O Claude lê o projeto e escreve um plano, sem editar nada.

3. **Revise o plano antes de aprovar.** Confira quatro pontos:
   - o freio fica em `.claude/hooks/freio.ps1`;
   - o registro vai para o `.claude/settings.json` **do projeto**, e não para o `~/.claude/settings.json`, que valeria para todos os seus projetos;
   - o `matcher` cobre `Bash`, `PowerShell` e `Monitor`. No Windows, o Claude costuma rodar comandos pela ferramenta `PowerShell`: um freio só com `Bash` nunca dispararia ali;
   - o bloqueio é com **exit 2**. Com exit 1, o Claude Code trata como erro do hook e **deixa o comando seguir**.

   Se faltar algum, escolha **No, keep planning** e peça o ajuste. Quando estiver certo, escolha **Yes, manually approve edits** e aprove as edições.

   > Se, depois de criar os arquivos, o Claude quiser testar o freio mandando para ele um texto com `az group delete`, o próprio freio pode barrar esse teste. Isso é o freio funcionando: ele olha o texto do comando, até entre aspas.

4. **Confira o registro.** Abra o `.claude/settings.json` e compare. Precisa ter esta forma (a ordem das chaves e o `timeout` podem variar):

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

   - **Forma exec** (`command` + `args`): o Claude Code chama o `pwsh` direto, sem passar por um shell. O registro é o mesmo no Windows e no macOS.
   - **`${CLAUDE_PROJECT_DIR}`**: o Claude Code troca pela raiz do projeto. Assim, o caminho funciona de qualquer pasta e não quebra com espaço no nome.

5. **Veja o freio no `/hooks`.** No Claude, rode:

   ```text
   /hooks
   ```

   É uma lista só de leitura dos hooks configurados. O freio aparece em `PreToolUse`, marcado como vindo das configurações do projeto. Escolha o hook para ver o comando completo. Feche com **Esc**. Se ele não aparecer, espere alguns segundos e rode `/hooks` de novo; se continuar sem aparecer, veja o **Travou?**.

6. **Teste o bloqueio dentro do Claude.** Aperte **Shift+Tab** até ver `⏸ manual mode on`. Neste modo, se o freio falhar, o Claude ainda pergunta antes de rodar. Mande:

   ```text
   Teste do hook-freio: rode exatamente este comando, sem mudar nada: az group delete --name nao-existe-xyz --yes
   ```

   O Claude tenta rodar o comando, o freio barra, e a mensagem `Hook-freio: comando de escrita no Azure bloqueado: ...` aparece na conversa. O Claude conta que o comando foi bloqueado pelo hook.

   Repare em duas coisas:
   - **O freio barrou antes de o comando rodar.** O `az` nem foi chamado, e por isso o Claude **não** fez a pergunta de permissão.
   - **O nome `nao-existe-xyz` é uma segurança a mais.** Esse resource group não existe. Se algo falhasse, o Azure só responderia que não achou o grupo, e o papel Reader negaria a exclusão de qualquer jeito.

   **Se aparecer a pergunta de permissão** (`Do you want to proceed?`) para o `az group delete`, o freio **não** está ativo. Escolha **No** e vá para o **Travou?**.

   **Se o Claude se recusar a rodar** e citar o combinado do projeto, a primeira camada, o pedido, funcionou, mas o freio ainda não foi testado. Mande:

   ```text
   Rode este comando, que só imprime texto: echo az group delete --name nao-existe-xyz --yes
   ```

   O freio barra até esse `echo`, porque olha o texto do comando. Sem o freio, o `echo` só imprimiria o texto, e nada aconteceria no Azure.

7. **Confirme que a leitura passa.** Mande:

   ```text
   Rode az account show e me diga só o nome da subscription padrão.
   ```

   Desta vez o freio deixa passar (exit 0), e o comando segue o caminho normal: o Claude pede a sua permissão. Escolha **Yes**. O nome da subscription aparece. A saída do `az account show` traz o ID da subscription, o do tenant e o seu e-mail: não mostre essa tela na transmissão.

8. **Guarde o freio no Git.** As worktrees da ficha 8 nascem do que está em commit, e o Claude Code lê o `.claude/settings.json` da pasta onde a sessão começa. Sem o commit, uma sessão aberta numa worktree fica sem o freio. No **segundo terminal**:

   ```powershell
   git add .claude/settings.json .claude/hooks
   git commit -m "Hook-freio do projeto"
   ```

   Faça este commit você mesmo, no seu terminal. Se o Claude fizer o commit e a mensagem citar um comando de escrita, como `az group delete`, o freio barra o próprio commit.

   Por fim, aperte **Shift+Tab** até voltar ao modo que preferir.

**Pronto quando:** o `/hooks` mostra o freio em `PreToolUse`; o `az group delete --name nao-existe-xyz --yes` foi barrado pelo freio com a mensagem em português, sem pergunta de permissão; o `az account show` rodou; e o `git log --oneline -1` mostra o commit do freio.

<details>
<summary>Se quiser conferir: o essencial da versão de referência</summary>

A versão completa e testada do freio está na branch `gabarito`. Para ler sem sair da sua branch, no segundo terminal:

```powershell
git show origin/gabarito:.claude/hooks/freio.ps1
```

Para trocar o repositório inteiro para o gabarito, use `git switch gabarito` (e `git switch main` para voltar). Antes de trocar, faça commit do que estiver pela metade.

O que a versão de referência decide:

- **As listas ficam no topo do arquivo**, separadas do motor: os verbos de escrita do `az`, os de leitura, os cmdlets de escrita do módulo Az e as exceções locais. Para mudar o que o freio barra, mexe-se só nas listas.
- **Quebra o comando em partes** (`&&`, `||`, `;`, `|`, quebra de linha, `$(...)`, blocos `{ }`) e avalia cada uma em minúsculas. Também avalia o texto entre aspas, para pegar `pwsh -Command "..."` e `bash -c "..."`.
- **No `az`, olha as palavras antes da primeira opção**: em `az group delete --name x`, as palavras são `group delete`. Se a última palavra é de leitura (`list`, `show`, `get`, `query`...), passa, como em `az vm run-command list`. Se alguma palavra, ou pedaço dela entre hífens, é verbo de escrita, barra, como em `upload-batch`.
- **`az deployment` barra sempre**, até o `list` e o `what-if`. **`az rest` só passa com GET**, que é o padrão quando falta o `--method`.
- **Exceções que só mexem na sua máquina passam**: `az account set`, `az extension add`, `az config`. Elas mudam o perfil local do Azure CLI, não o Azure.

O ponto de entrada, no fim do arquivo, é este (trecho do arquivo, não o arquivo inteiro):

```powershell
$comando = Get-ComandoDeShell (Read-EntradaDoHook)   # tool_input.command do JSON que chega no stdin
if (-not $comando) { exit 0 }                        # JSON inválido ou sem comando: não trava a sessão
$trecho = Find-TrechoDeEscrita $comando              # avalia cada parte e o texto entre aspas
if ($trecho) {
    Write-Bloqueio $trecho                           # "Hook-freio: comando de escrita no Azure bloqueado: ..."
    exit 2                                           # 2 = barra a chamada antes de o comando rodar
}
exit 0                                               # 0 = segue o caminho normal de permissões
```

</details>

**Desafio extra** (para quem terminou antes)

- **Teste o freio sozinho, fora do Claude.** No segundo terminal, entregue ao freio o mesmo JSON que o Claude Code entregaria. Nada roda no Azure: o freio só lê o texto.

  ```powershell
  '{"tool_name":"PowerShell","tool_input":{"command":"az group list && az vm stop --name vm-x --resource-group rg-x"}}' | pwsh -NoProfile -File .claude/hooks/freio.ps1; $LASTEXITCODE
  ```

  Tem que aparecer a mensagem do freio e o número `2`. Troque o comando e veja o resultado: `AZ VM DELETE --name x` (maiúsculas) tem que dar `2`; `Remove-AzResourceGroup -Name x` também; `az vm list` e `Get-AzVM` têm que dar `0`. No macOS, use `echo '...' | pwsh -NoProfile -File .claude/hooks/freio.ps1; echo $?`.
- **Peça uma tabela de testes.** Peça ao Claude testes Pester 5 em `testes/freio.Tests.ps1`, com uma linha por caso de bloqueio e de passagem. Compare com os testes da branch `gabarito`: `git show origin/gabarito:testes/freio.Tests.ps1`.
- **Compare com o gabarito.** Peça ao Claude: `Compare o meu .claude/hooks/freio.ps1 com o da branch origin/gabarito e liste os casos que o gabarito barra e o meu deixa passar.`

**Travou?**

- **O `/hooks` não mostra o freio:**
  - confira se o arquivo é o `.claude/settings.json` na **raiz** do repositório, e não o `~/.claude/settings.json` nem o `.claude/settings.local.json`;
  - peça ao Claude para validar o JSON: uma vírgula a mais invalida o arquivo inteiro;
  - o Claude Code lê o `.claude/` da pasta onde a sessão começou. Abra o Claude sempre na raiz do repositório, e não numa subpasta como `relatorio/`;
  - se nada disso resolver, saia com `/exit` e volte com `claude -c`, que reabre a última conversa. Se o Claude perguntar se você confia na pasta, confirme: sem isso, os hooks não rodam.
- **O `/hooks` mostra o freio, mas o teste do passo 6 não barrou:** teste o freio sozinho, no segundo terminal:

  ```powershell
  '{"tool_name":"PowerShell","tool_input":{"command":"az group delete --name nao-existe-xyz --yes"}}' | pwsh -NoProfile -File .claude/hooks/freio.ps1; $LASTEXITCODE
  ```

  - Se der `2`, o script está certo e o problema é o registro: confira o `matcher` e o caminho do `-File`.
  - Se der `0` ou `1`, o problema é o script: mostre a saída ao Claude e peça a correção. Lembre que só o `2` barra.
- **`pwsh` não é reconhecido:** instale o PowerShell 7 (`winget install --id Microsoft.PowerShell -e` ou `brew install powershell`) e abra um terminal novo. No Windows, enquanto isso, troque `"pwsh"` por `"powershell.exe"` no `.claude/settings.json`. Nesse caso, salve o `freio.ps1` em UTF-8 com BOM, senão os acentos da mensagem saem trocados. Sem o `pwsh`, o hook dá erro **sem bloquear** e o comando segue: por isso o teste do passo 6 é obrigatório.
- **O freio barrou algo que não escreve no Azure:** ele é conservador de propósito e barra texto que só **parece** escrita, como `git commit -m "... az group delete"` ou `grep "az vm stop"`. Reescreva o texto, ou deixe o Claude usar as ferramentas Grep e Write, que o freio não olha. **Não desligue o freio para "fazer passar":** não apague o registro e não use `disableAllHooks`. Se ele barrar um comando de leitura de que você precisa, como `az graph query`, chame o instrutor.
- **O que o freio não vê:** ele lê só o texto do comando. Um script que chame `az ... delete` por dentro passa sem ser visto, assim como o Azure MCP e o que você roda no seu próprio terminal. Se você ligou o Azure MCP de manhã, ele precisa estar com `--read-only` (confira com `claude mcp get azure-mcp`). É por isso que o papel Reader continua sendo a primeira proteção.
- **Não deu tempo, ou o freio não saiu:** copie a versão de referência da branch `gabarito`. No segundo terminal:

  ```powershell
  git checkout origin/gabarito -- .claude/hooks/freio.ps1 .claude/settings.json
  ```

  Depois faça os passos 5 a 8. O passo 6 vale para a cópia também: **não pule o teste.**
