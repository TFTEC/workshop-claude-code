# Glossário e mapa de arquivos do Claude Code

Consulta rápida: **onde cada arquivo do Claude Code fica, como editar** e, depois, os termos de A a Z, cada um com o link da documentação oficial. Conferido na documentação oficial em 10/10/2026, para o Claude Code 2.1.296. As coisas mudam rápido: na dúvida, o link de cada termo é a fonte.

No Windows, `~` é a sua pasta de usuário, `C:\Users\<você>`. No PowerShell, `$HOME` aponta para ela.

## Onde cada coisa fica

A regra de bolso:

- **`.claude\` dentro do projeto** é da equipe: vai para o git e vale para quem clonar.
- **`~\.claude\`** é seu: vale em todos os seus projetos e não vai para o git.
- **Nomes com `.local`** são seus, só neste projeto, e devem ficar fora do git: ponha no `.gitignore` (o `settings.local.json` que o próprio Claude Code cria já sai do git sozinho).

| O quê | No projeto (da equipe) | Seu (`~\.claude\`) | Como abrir ou editar | Quando vale |
|---|---|---|---|---|
| Instruções | `CLAUDE.md` ou `.claude\CLAUDE.md`. Só seu: `CLAUDE.local.md` | `~\.claude\CLAUDE.md` | `/memory` abre no editor, ou `code CLAUDE.md`. `/init` cria o primeiro | No começo da sessão |
| Regras | `.claude\rules\*.md` | `~\.claude\rules\*.md` | `/memory` ou o editor | No começo da sessão, ou quando o caminho casa com o `paths` |
| Memória automática | — | `~\.claude\projects\<projeto>\memory\` (índice no `MEMORY.md`) | `/memory` abre a pasta | No começo da sessão |
| Configurações: permissões, hooks, modo, modelo | `.claude\settings.json`. Só seu: `.claude\settings.local.json` | `~\.claude\settings.json` | `/config`, `/permissions` ou o editor | A maioria vale na hora |
| Skills | `.claude\skills\<nome>\SKILL.md` | `~\.claude\skills\<nome>\SKILL.md` | O editor. `/skills` lista | Na hora. Pasta criada no meio da sessão: `/reload-skills` |
| Subagentes | `.claude\agents\<nome>.md` | `~\.claude\agents\<nome>.md` | O editor, ou peça ao Claude. `/agents` só lembra onde os arquivos ficam | Em segundos. Pasta `agents` criada no meio da sessão: reabra a sessão |
| Hooks | Chave `hooks` no `.claude\settings.json`; o script costuma ficar em `.claude\hooks\` | Chave `hooks` no `~\.claude\settings.json` | O editor. `/hooks` mostra os ativos e de onde vieram | Em geral, na hora |
| Servidores MCP | `.mcp.json` na raiz | `~\.claude.json`, que o Claude Code mantém sozinho: login, confiança de cada pasta e os servidores MCP seus e "local" | `claude mcp add`, `list`, `get` e `remove`. `/mcp` mostra o status | Reabra a sessão se o servidor não aparecer |
| Plugins e marketplaces | Chave `enabledPlugins` no `settings.json` | `~\.claude\plugins\` | `/plugin` ou `claude plugin` | `/reload-plugins` |
| Histórico das conversas | — | `~\.claude\projects\<projeto>\<sessão>.jsonl`, guardado por 30 dias | Não edite. `/resume` reabre, `/export` exporta | — |
| Atalhos de teclado | — | `~\.claude\keybindings.json` | `/keybindings` abre o arquivo | Na hora |
| Configuração da organização | — | `C:\Program Files\ClaudeCode\managed-settings.json`, mantido pela TI | Só a TI edita | Ganha de todas as outras |

As **listas de regras de permissão se somam** entre os arquivos, e um `deny` de qualquer nível vence um `allow` de qualquer outro. Para um valor simples, como o modelo, vence o nível mais alto: a organização, depois a linha de comando (`--settings`), depois `.claude\settings.local.json`, depois `.claude\settings.json` e, por último, `~\.claude\settings.json`. O `/status` mostra, na linha `Setting sources`, quais arquivos carregaram.

**Para editar sem sair do Claude:** **Ctrl+G** abre o texto que você está digitando (ou o plano, no plan mode) no editor de texto. Para os arquivos acima, peça ao próprio Claude: `abra o meu ~/.claude/settings.json e acrescente uma regra deny para Read(./.env)`. Ele mostra o diff antes de gravar.

## Termos de A a Z

Cada termo tem uma linha do que é, como se usa e o link da documentação oficial, quase sempre direto na seção certa. Marcas: **[pago]** exige assinatura Pro, Max, Team ou Enterprise do claude.ai, ou cobra à parte; **[org]** é configurado pela organização; **[prévia]** está em prévia ou é experimental.

### Conceitos

| Termo | O que é | Como se usa | Link |
|---|---|---|---|
| Agent teams [prévia] | Várias sessões do Claude Code coordenadas por uma sessão líder, com lista de tarefas e mensagens entre elas | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` no ambiente ou no `env` do settings | [agent-teams#enable-agent-teams](https://code.claude.com/docs/en/agent-teams#enable-agent-teams) |
| Agente / loop agêntico (agentic loop) | O ciclo de reunir contexto, agir e verificar, repetido até terminar a tarefa | Acontece a cada pedido; `Esc` interrompe para redirecionar | [how-claude-code-works#the-agentic-loop](https://code.claude.com/docs/en/how-claude-code-works#the-agentic-loop) |
| Agentes embutidos | Subagentes que já vêm no Claude Code: Explore, Plan, general-purpose e auxiliares | O Claude escolhe; bloqueie com `"deny": ["Agent(Explore)"]` | [sub-agents#built-in-subagents](https://code.claude.com/docs/en/sub-agents#built-in-subagents) |
| Caminho crítico | Raiz do disco, pasta do usuário, diretório de trabalho e afins; `rm` e `rmdir` neles nunca são aprovados por regra | Automático; em auto e bypass, prompt com contagem de 2 minutos | [permission-modes#critical-paths](https://code.claude.com/docs/en/permission-modes#critical-paths) |
| Caminho protegido | Pastas e arquivos como `.git`, `.claude`, `.vscode` e `.mcp.json`, cuja escrita só é aprovada sem perguntar no bypass | Automático; um allow no settings não libera | [permission-modes#protected-paths](https://code.claude.com/docs/en/permission-modes#protected-paths) |
| Checkpoint | Ponto de restauração criado a cada prompt; desfaz edições feitas pelas ferramentas de arquivo, não as feitas por comandos de Bash | `Esc` `Esc` com o prompt vazio, ou `/rewind` | [checkpointing](https://code.claude.com/docs/en/checkpointing) |
| Classificador do auto mode | Segundo modelo, Sonnet 5 por padrão, que aprova ou bloqueia ações no auto mode; não vê os resultados das ferramentas | Negações em `/permissions`, aba Recently denied; `claude auto-mode defaults` lista as regras | [permission-modes#how-the-classifier-evaluates-actions](https://code.claude.com/docs/en/permission-modes#how-the-classifier-evaluates-actions) |
| Comando (antes "slash command") | Instrução que você chama com `/nome`; os comandos personalizados foram fundidos às skills | `/nome`; `.claude/commands/deploy.md` e `.claude/skills/deploy/SKILL.md` criam o mesmo `/deploy`, e em conflito a skill vence | [glossary#command](https://code.claude.com/docs/en/glossary#command) |
| Compactação automática | Resumo automático da conversa quando o contexto chega perto do limite; o CLAUDE.md da raiz é relido do disco | `/compact [foco]`; o ponto de disparo muda com `/autocompact` | [glossary#compaction](https://code.claude.com/docs/en/glossary#compaction) |
| Conector | Servidor MCP adicionado na conta do claude.ai, que aparece no `/mcp` | Configure no claude.ai e entre no Claude Code com a mesma conta | [glossary#connector](https://code.claude.com/docs/en/glossary#connector) |
| Custo de contexto de um plugin | Quanto um plugin soma ao contexto: sempre (todo turno) e quando uma peça dele roda | No painel do `/plugin install <nome>@claude-plugins-official`, a seção **Context cost**; no terminal, `claude plugin details <nome>` mostra **Projected token cost** e a tabela por componente | [plugins/install](https://code.claude.com/docs/en/plugins/install) |
| Contexto / janela de contexto | A memória de trabalho da sessão: conversa, arquivos lidos, saídas de comandos, CLAUDE.md, skills carregadas | `/context` mostra o que ocupa espaço | [glossary#context-window](https://code.claude.com/docs/en/glossary#context-window) |
| Effort (nível de esforço) | Quanto o modelo raciocina: `low`, `medium`, `high`, `xhigh`, `max`; Opus 5.5, Sonnet 5.5 e Haiku 5.5 começam em `medium` | `/effort`, `--effort`, setas no `/model` | [model-config#adjust-effort-level](https://code.claude.com/docs/en/model-config#adjust-effort-level) |
| Extended thinking | O raciocínio que o modelo faz antes de responder; não desliga no Opus 5.5, Sonnet 5.5, Haiku 5.5 e Fable | `Alt+T` liga ou desliga onde é permitido; `Ctrl+O` mostra o raciocínio | [model-config#extended-thinking](https://code.claude.com/docs/en/model-config#extended-thinking) |
| Fast mode [pago] [prévia] | Configuração do Opus até 2,5 vezes mais rápida, com preço maior por token; nas assinaturas, sai dos créditos de uso | `/fast`, `Alt+O` | [fast-mode](https://code.claude.com/docs/en/fast-mode) |
| Ferramenta (tool) | Uma ação que o Claude pode executar: Read, Edit, Write, Bash, PowerShell, WebFetch, Agent e outras | O nome canônico vai em regras de permissão, no `tools` do subagente e no matcher de hook | [tools-reference](https://code.claude.com/docs/en/tools-reference) |
| Ferramenta PowerShell [prévia] | Roda comandos PowerShell nativamente; no Windows, quando ativa, vira o shell principal | Ativa por padrão no Windows para contas do claude.ai e do Console; `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` ou `0`; regras `PowerShell(...)` | [tools-reference#powershell-tool](https://code.claude.com/docs/en/tools-reference#powershell-tool) |
| Fork (subagente bifurcado) | Subagente que herda a conversa inteira em vez de começar do zero; o resultado volta à conversa | `/subtask <tarefa>` | [sub-agents#fork-the-current-conversation](https://code.claude.com/docs/en/sub-agents#fork-the-current-conversation) |
| Hook | Comando, chamada HTTP, prompt ou agente que roda sozinho num ponto fixo do ciclo de vida, sem depender da decisão do modelo | Chave `hooks` no settings. Eventos principais: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `Stop`, `SubagentStart`, `SubagentStop`, `PreCompact`, `SessionEnd` | [hooks#hook-lifecycle](https://code.claude.com/docs/en/hooks#hook-lifecycle) |
| Marketplace | Catálogo de plugins; o oficial da Anthropic, `claude-plugins-official`, já vem adicionado | `/plugin marketplace add <dono/repo>` | [plugins/install#add-a-marketplace](https://code.claude.com/docs/en/plugins/install#add-a-marketplace) |
| MCP (Model Context Protocol) | Padrão aberto para ligar o Claude a ferramentas e dados externos | `claude mcp add`, `/mcp`, `.mcp.json` | [glossary#mcp-model-context-protocol](https://code.claude.com/docs/en/glossary#mcp-model-context-protocol) |
| Modelo | O modelo Claude que raciocina; aliases `sonnet`, `opus`, `haiku`, `fable`, `best` e `opusplan` | `/model`, `--model`, `Alt+P` | [model-config#model-aliases](https://code.claude.com/docs/en/model-config#model-aliases) |
| Monitor (ferramenta) | Roda um script em segundo plano e devolve cada linha de saída ao Claude, para vigiar algo sem repetir o pedido | O Claude usa sozinho; hooks de shell devem casar `Bash\|PowerShell\|Monitor` | [tools-reference#monitor-tool](https://code.claude.com/docs/en/tools-reference#monitor-tool) |
| Modo de permissão | O comportamento base de aprovação da sessão; são seis modos, nas linhas seguintes | `Shift+Tab`, `--permission-mode`, `permissions.defaultMode` | [permission-modes](https://code.claude.com/docs/en/permission-modes) |
| Modo `acceptEdits` | Aceita edições e `mkdir`, `touch`, `rm`, `rmdir`, `mv`, `cp` e `sed` dentro dos diretórios de trabalho | `Shift+Tab` uma vez a partir do Manual; `--permission-mode acceptEdits` | [permission-modes#auto-approve-file-edits-with-acceptedits-mode](https://code.claude.com/docs/en/permission-modes#auto-approve-file-edits-with-acceptedits-mode) |
| Modo `auto` | Um classificador revisa as ações no seu lugar; modo inicial das sessões no terminal desde a v2.1.283 | `Shift+Tab`, `--permission-mode auto` | [permission-modes#eliminate-prompts-with-auto-mode](https://code.claude.com/docs/en/permission-modes#eliminate-prompts-with-auto-mode) |
| Modo `bypassPermissions` | Pula os prompts; deny e ask continuam valendo; só para container ou máquina virtual | `--dangerously-skip-permissions` ou `--permission-mode bypassPermissions` | [permission-modes#skip-all-checks-with-bypasspermissions-mode](https://code.claude.com/docs/en/permission-modes#skip-all-checks-with-bypasspermissions-mode) |
| Modo `default` (Manual) | Pergunta antes de editar, rodar comandos ou acessar a rede; só as leituras são livres | `--permission-mode default` ou `manual` | [permission-modes#available-modes](https://code.claude.com/docs/en/permission-modes#available-modes) |
| Modo `dontAsk` | Nega tudo que pediria permissão e roda só o pré-aprovado; fora do ciclo do `Shift+Tab` | `--permission-mode dontAsk` | [permission-modes#allow-only-pre-approved-tools-with-dontask-mode](https://code.claude.com/docs/en/permission-modes#allow-only-pre-approved-tools-with-dontask-mode) |
| Modo `plan` | Lê e explora, propõe um plano e não edita até você aprovar | `Shift+Tab`, `/plan`, `--permission-mode plan`; `Ctrl+G` edita o plano | [permission-modes#analyze-before-you-edit-with-plan-mode](https://code.claude.com/docs/en/permission-modes#analyze-before-you-edit-with-plan-mode) |
| Pergunta de confiança da pasta (workspace trust) | Diálogo na primeira vez que você abre uma pasta; até aceitar, as regras allow e os diretórios extras do settings do projeto e os hooks no frontmatter de subagentes ficam retidos | Aceite no diálogo; em `-p` ele não aparece | [permissions#project-allow-rules-and-workspace-trust](https://code.claude.com/docs/en/permissions#project-allow-rules-and-workspace-trust) |
| Plugin | Pacote instalável de skills, subagentes, hooks e servidores MCP | `/plugin`, `/plugin install <nome>@<marketplace>`, `claude plugin` | [plugins/overview](https://code.claude.com/docs/en/plugins/overview) |
| Prompt injection | Instruções hostis escondidas num arquivo, página ou resultado de ferramenta | Defesas: permissões, auto mode, sandbox | [glossary#prompt-injection](https://code.claude.com/docs/en/glossary#prompt-injection) |
| Regras de permissão | Entradas `allow`, `ask` e `deny`, avaliadas na ordem deny, ask, allow | `/permissions` ou a chave `permissions` do settings | [permissions#manage-permissions](https://code.claude.com/docs/en/permissions#manage-permissions) |
| Sandbox | Isolamento de sistema operacional, de arquivos e rede, para os comandos de shell; macOS, Linux e WSL2, não no Windows nativo | `/sandbox`, `sandbox.enabled` | [sandboxing](https://code.claude.com/docs/en/sandboxing) |
| Servidor MCP | Programa que dá ferramentas, prompts ou recursos ao Claude via MCP | `claude mcp add`, `.mcp.json`, plugin ou conector | [glossary#mcp-server](https://code.claude.com/docs/en/glossary#mcp-server) |
| Sessão | Uma conversa ligada ao diretório atual, com janela de contexto própria e transcrição em `~/.claude/projects/` | `claude -c`, `claude -r`, `/resume`, `/clear` | [glossary#session](https://code.claude.com/docs/en/glossary#session) |
| Skill | Arquivo `SKILL.md` com instruções que o Claude carrega quando é relevante ou quando você chama | `/nome-da-skill`; `.claude/skills/<nome>/SKILL.md` | [skills](https://code.claude.com/docs/en/skills) |
| Subagente | Assistente com contexto, prompt e ferramentas próprios que devolve só o resumo | `.claude/agents/<nome>.md`; `@agent-<nome>`; `claude --agent <nome>` | [sub-agents](https://code.claude.com/docs/en/sub-agents) |
| System reminder | Mensagem que o Claude Code insere na conversa: CLAUDE.md, lista de skills, aviso de arquivo alterado; por isso o CLAUDE.md não faz parte do prompt de sistema | Automático | [glossary#system-reminder](https://code.claude.com/docs/en/glossary#system-reminder) |
| Token | Unidade em que o texto e o custo são contados; a definição formal fica no glossário da plataforma, não no do Claude Code | `/usage` mostra custo; `/context` mostra ocupação | [costs#reduce-token-usage](https://code.claude.com/docs/en/costs#reduce-token-usage) |
| Transcrição (transcript) | O arquivo `.jsonl` que guarda a sessão e permite retomá-la | `~/.claude/projects/<projeto>/<id-da-sessão>.jsonl` | [glossary#transcript](https://code.claude.com/docs/en/glossary#transcript) |
| Transporte MCP | Como o Claude Code fala com o servidor: `stdio` (processo local), `http` (remoto, recomendado), `sse` (obsoleto) ou `ws` | `claude mcp add --transport http <nome> <url>`; `claude mcp add --transport stdio <nome> -- <comando>` | [mcp#installing-mcp-servers](https://code.claude.com/docs/en/mcp#installing-mcp-servers) |
| Turno (turn) | Uma resposta completa do Claude, do envio da mensagem até o fim, com as chamadas de ferramenta no meio | Os hooks `Stop` disparam no fim de cada turno | [glossary#turn](https://code.claude.com/docs/en/glossary#turn) |
| Ultrathink | Palavra que, no prompt, pede raciocínio mais profundo só naquele turno | Escreva `ultrathink` no prompt; "think hard" não é palavra-chave | [model-config#use-ultrathink-for-one-off-deep-reasoning](https://code.claude.com/docs/en/model-config#use-ultrathink-for-one-off-deep-reasoning) |

### Arquivos e configuração

| Termo | O que é | Como se usa | Link |
|---|---|---|---|
| `.claude/` e `~/.claude/` | Pasta de configuração do projeto e do usuário: settings, skills, agentes, regras | No Windows, `~/.claude` é `%USERPROFILE%\.claude` | [claude-directory](https://code.claude.com/docs/en/claude-directory) |
| `~/.claude.json` | Arquivo que o Claude Code mantém: login, estado por projeto (confiança da pasta), servidores MCP de escopo local e usuário | Não precisa editar; no Windows é `%USERPROFILE%\.claude.json` | [settings#find-or-create-your-settings-files](https://code.claude.com/docs/en/settings#find-or-create-your-settings-files) |
| `.claude/agents/` | Pasta dos subagentes do projeto; a do usuário é `~/.claude/agents/` | Um `.md` por agente, com frontmatter | [sub-agents#choose-the-subagent-scope](https://code.claude.com/docs/en/sub-agents#choose-the-subagent-scope) |
| `.claude/commands/` | Formato antigo de comando personalizado; ainda funciona | `.claude/commands/deploy.md` cria `/deploy` | [skills#where-skills-live](https://code.claude.com/docs/en/skills#where-skills-live) |
| `.claude/rules/` com `paths` | Regras em arquivos separados; com `paths:` no frontmatter, só carregam quando o Claude mexe num arquivo que casa | `paths:` com globs como `"src/api/**/*.ts"` | [memory#path-specific-rules](https://code.claude.com/docs/en/memory#path-specific-rules) |
| `.claude/skills/` | Pasta das skills do projeto; a do usuário é `~/.claude/skills/` | `.claude/skills/<nome>/SKILL.md` | [skills#where-skills-live](https://code.claude.com/docs/en/skills#where-skills-live) |
| `.mcp.json` | Servidores MCP de escopo projeto, na raiz; vai ao git; o Claude Code pede aprovação antes de usar | `claude mcp add --scope project ...` | [mcp#project-scope](https://code.claude.com/docs/en/mcp#project-scope) |
| AGENTS.md | Arquivo de instruções para agentes; o Claude lê no lugar do CLAUDE.md quando não há CLAUDE.md na pasta nem acima dela (v2.1.277+) | `/config`, opção Project instructions; ou `@AGENTS.md` dentro do CLAUDE.md | [memory#agents-md](https://code.claude.com/docs/en/memory#agents-md) |
| `CLAUDE_CODE_USE_POWERSHELL_TOOL` | Variável que liga (`1`) ou desliga (`0`) a ferramenta PowerShell | No ambiente ou no `env` do settings | [tools-reference#enable-the-powershell-tool](https://code.claude.com/docs/en/tools-reference#enable-the-powershell-tool) |
| `CLAUDE_CONFIG_DIR` | Variável que troca a pasta `~/.claude` | No shell, nos settings do usuário ou nas managed | [env-vars](https://code.claude.com/docs/en/env-vars) |
| `CLAUDE_PROJECT_DIR` | Variável com a raiz do projeto, passada aos hooks e aos servidores MCP stdio | Hook: `"${CLAUDE_PROJECT_DIR}/.claude/hooks/x.sh"`; hook PowerShell: `$env:CLAUDE_PROJECT_DIR` ou `${CLAUDE_PROJECT_DIR}`, nunca `$CLAUDE_PROJECT_DIR` | [hooks#reference-scripts-by-path](https://code.claude.com/docs/en/hooks#reference-scripts-by-path) |
| CLAUDE.md | Instruções persistentes que o Claude lê no começo de toda sessão; orientam, não bloqueiam | `./CLAUDE.md` ou `./.claude/CLAUDE.md`; `~/.claude/CLAUDE.md`; `/init`, `/memory` | [memory#claude-md-files](https://code.claude.com/docs/en/memory#claude-md-files) |
| CLAUDE.local.md | Instruções pessoais do projeto, lidas junto com o CLAUDE.md | Na raiz do projeto, listado no `.gitignore` | [memory#choose-where-to-put-claude-md-files](https://code.claude.com/docs/en/memory#choose-where-to-put-claude-md-files) |
| `defaultShell` | Chave que escolhe se os comandos digitados com `!` rodam em Bash ou PowerShell | `"defaultShell": "powershell"` | [settings-reference#defaultshell](https://code.claude.com/docs/en/settings-reference#defaultshell) |
| Escopos do MCP | Onde o servidor vale: `local` (padrão; só você, neste projeto, em `~/.claude.json`), `project` (`.mcp.json`, para o time) e `user` (todos os seus projetos) | `claude mcp add --scope local`, `--scope project` ou `--scope user` | [mcp#mcp-installation-scopes](https://code.claude.com/docs/en/mcp#mcp-installation-scopes) |
| Escopos dos settings | Managed, depois `--settings`, `.claude/settings.local.json`, `.claude/settings.json` e `~/.claude/settings.json`; listas somam | `/status` mostra os carregados | [settings#settings-precedence](https://code.claude.com/docs/en/settings#settings-precedence) |
| Frontmatter | Bloco YAML entre `---` no topo de skills, subagentes, output styles e regras | O `---` de abertura tem de ser a primeira linha | [glossary#frontmatter](https://code.claude.com/docs/en/glossary#frontmatter) |
| Imports com `@` no CLAUDE.md | Puxa outro arquivo para o contexto, até quatro níveis; o caminho é relativo ao arquivo que importa | `@README`, `@docs/git-instructions.md`; com espaço: `@Design\ Docs/api.md` | [memory#import-additional-files](https://code.claude.com/docs/en/memory#import-additional-files) |
| `keybindings.json` | Arquivo de atalhos personalizados, recarregado sem reiniciar | `/keybindings` abre `~/.claude/keybindings.json` | [keybindings](https://code.claude.com/docs/en/keybindings) |
| Managed settings [org] | Configurações impostas pela organização, acima de todos os outros arquivos | Windows: `C:\Program Files\ClaudeCode\managed-settings.json` ou registro `HKLM\SOFTWARE\Policies\ClaudeCode` | [managed-settings](https://code.claude.com/docs/en/managed-settings) |
| Memória automática (auto memory) | Notas que o próprio Claude grava entre sessões, por repositório; as primeiras 200 linhas ou 25 KB do `MEMORY.md` carregam em toda sessão | `/memory` liga, desliga e abre a pasta `~/.claude/projects/<projeto>/memory/` | [memory#auto-memory](https://code.claude.com/docs/en/memory#auto-memory) |
| Output style | Instruções que mudam papel, tom e formato das respostas: Default, Proactive, Concise, Explanatory, Learning ou um próprio | `/output-style <nome>`, ou `/config`, opção Output style | [output-styles](https://code.claude.com/docs/en/output-styles) |
| `settings.json` | Arquivo JSON de configuração: permissões, hooks, `env`, modelo; JSON estrito, sem comentários | `~/.claude/settings.json`, `.claude/settings.json` | [settings](https://code.claude.com/docs/en/settings) |
| `settings.local.json` | Configuração pessoal do projeto, fora do git (quando o Claude Code cria o arquivo, ele o esconde do git; criado à mão, ponha no `.gitignore`); recebe as regras do "Yes, and don't ask again" | `.claude/settings.local.json` | [settings#keep-personal-settings-out-of-a-repository](https://code.claude.com/docs/en/settings#keep-personal-settings-out-of-a-repository) |
| Statusline | Barra no rodapé que roda um script seu e mostra o que ele imprimir: contexto, custo, branch | `/statusline` ou a chave `statusLine` | [statusline](https://code.claude.com/docs/en/statusline) |
| Vim mode | Edição do prompt com as teclas do Vim | `/config`, opção Editor mode, ou `"editorMode": "vim"` | [interactive-mode#vim-editor-mode](https://code.claude.com/docs/en/interactive-mode#vim-editor-mode) |

### Comandos de barra

| Termo | O que é | Como se usa | Link |
|---|---|---|---|
| `/add-dir` | Dá acesso a mais um diretório na sessão | `/add-dir <caminho>` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/agents` | Hoje só imprime um lembrete: peça ao Claude ou edite `.claude/agents/` | `/agents` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/autocompact` | Define com que ocupação o contexto compacta sozinho | `/autocompact 500k` ou `/autocompact auto` | [model-config#set-the-auto-compact-window](https://code.claude.com/docs/en/model-config#set-the-auto-compact-window) |
| `/btw` | Pergunta paralela que vê a conversa, sem ferramentas e sem entrar no histórico | `/btw <pergunta>` | [interactive-mode#side-questions-with-%2Fbtw](https://code.claude.com/docs/en/interactive-mode#side-questions-with-%2Fbtw) |
| `/bug` | Relata um bug com o contexto da sessão; alias `/share`; separado do `/feedback` desde a v2.1.212 | `/bug [relato]` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/clear` | Começa uma conversa nova com contexto vazio; a anterior fica no `/resume`; aliases `/reset` e `/new` | `/clear [nome]` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/code-review` | Skill que revisa o diff atual ou um PR atrás de bugs; alias `/review` | `/code-review [nível] [--fix] [PR]` | [code-review#review-a-diff-locally](https://code.claude.com/docs/en/code-review#review-a-diff-locally) |
| `/compact` | Resume a conversa para liberar contexto | `/compact [instruções de foco]` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/config` | Abre as configurações: tema, modelo, output style, editor; alias `/settings` | `/config` ou `/config chave=valor` | [settings](https://code.claude.com/docs/en/settings) |
| `/context` | Mostra a ocupação do contexto numa grade colorida, com sugestões | `/context [all]` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/cost` | Alias de `/usage` | `/cost` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/diff` | Mostra as mudanças na árvore de trabalho, inclusive as do Claude | `/diff` | [interactive-mode#review-changes-with-%2Fdiff](https://code.claude.com/docs/en/interactive-mode#review-changes-with-%2Fdiff) |
| `/doctor` | Skill de checkup da instalação, dos settings, das extensões e do CLAUDE.md, que propõe correções; alias `/checkup` | `/doctor`; no terminal, `claude doctor` só diagnostica | [skills#check-your-setup-with-/doctor](https://code.claude.com/docs/en/skills#check-your-setup-with-/doctor) |
| `/effort` | Ajusta o nível de esforço | `/effort [low\|medium\|high\|xhigh\|max\|auto]` | [model-config#adjust-effort-level](https://code.claude.com/docs/en/model-config#adjust-effort-level) |
| `/exit` | Sai do CLI; alias `/quit` | `/exit` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/export` | Exporta a conversa como texto | `/export [arquivo]` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/fast` [pago] | Liga ou desliga o fast mode | `/fast [on\|off]` | [fast-mode#toggle-fast-mode](https://code.claude.com/docs/en/fast-mode#toggle-fast-mode) |
| `/feedback` | Envia feedback sobre o produto | `/feedback [texto]` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/fewer-permission-prompts` | Skill que lê suas transcrições e propõe um allow de comandos só leitura no `.claude/settings.json` | `/fewer-permission-prompts` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/goal` | Mantém o Claude trabalhando entre turnos até uma condição ser cumprida | `/goal <condição>`; `/goal clear` | [goal](https://code.claude.com/docs/en/goal) |
| `/help` | Ajuda e lista de comandos | `/help` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/hooks` | Navegador só leitura dos hooks configurados e de onde cada um vem | `/hooks` | [hooks#the-%2Fhooks-menu](https://code.claude.com/docs/en/hooks#the-%2Fhooks-menu) |
| `/ide` | Gerencia a integração com IDEs e mostra o status | `/ide` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/init` | Gera um CLAUDE.md inicial; se já existe, sugere melhorias | `/init`; `CLAUDE_CODE_NEW_INIT=1` para o fluxo interativo | [memory#set-up-a-project-claude-md](https://code.claude.com/docs/en/memory#set-up-a-project-claude-md) |
| `/install-github-app` | Instala o app do Claude no GitHub e, opcionalmente, os workflows do GitHub Actions; só para github.com | `/install-github-app` | [github-actions#quick-setup](https://code.claude.com/docs/en/github-actions#quick-setup) |
| `/keybindings` | Abre o arquivo de atalhos | `/keybindings` | [keybindings](https://code.claude.com/docs/en/keybindings) |
| `/login` e `/logout` | Entra e sai da conta Anthropic | `/login`, `/logout` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/loop` | Skill que repete um prompt num intervalo enquanto a sessão estiver aberta; alias `/proactive` | `/loop 5m <prompt>` | [scheduled-tasks](https://code.claude.com/docs/en/scheduled-tasks) |
| `/mcp` | Gerencia os servidores MCP e a autenticação OAuth | `/mcp`; `/mcp reconnect all` | [mcp#managing-your-servers](https://code.claude.com/docs/en/mcp#managing-your-servers) |
| `/memory` | Abre os CLAUDE.md e liga ou desliga a memória automática | `/memory` | [memory#view-and-edit-with-%2Fmemory](https://code.claude.com/docs/en/memory#view-and-edit-with-%2Fmemory) |
| `/model` | Troca o modelo e salva como padrão; no seletor, `s` troca só na sessão | `/model [modelo]` | [model-config#setting-your-model](https://code.claude.com/docs/en/model-config#setting-your-model) |
| `/output-style` | Lista ou troca o output style; voltou na v2.1.269 | `/output-style concise` | [output-styles#change-your-output-style](https://code.claude.com/docs/en/output-styles#change-your-output-style) |
| `/permissions` | Gerencia as regras allow, ask e deny, os diretórios de trabalho e as negações do auto mode; alias `/allowed-tools` | `/permissions` | [permissions#manage-permissions](https://code.claude.com/docs/en/permissions#manage-permissions) |
| `/plan` | Entra no plan mode direto do prompt | `/plan [tarefa]` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/plugin` | Gerencia plugins e marketplaces | `/plugin`; `/plugin install <nome>@<marketplace>` | [plugins/install](https://code.claude.com/docs/en/plugins/install) |
| `/powerup` | Lições interativas rápidas sobre as funcionalidades | `/powerup` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/release-notes` | Mostra o changelog por versão | `/release-notes` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/reload-skills` | Relê as pastas de skills e comandos sem reiniciar | `/reload-skills` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/remote-control` [pago] | Deixa a sessão local controlável pelo claude.ai ou pelo app do Claude; alias `/rc` | `/remote-control` | [remote-control](https://code.claude.com/docs/en/remote-control) |
| `/resume` | Retoma uma conversa por ID ou nome, ou abre o seletor; alias `/continue` | `/resume [sessão]` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/review` | Alias de `/code-review` desde a v2.1.223 | `/review [PR]` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/rewind` | Volta código e conversa, ou um dos dois, a um checkpoint, ou resume parte da conversa; aliases `/checkpoint` e `/undo` | `/rewind` ou `Esc` `Esc` | [checkpointing#rewind-and-summarize](https://code.claude.com/docs/en/checkpointing#rewind-and-summarize) |
| `/sandbox` | Liga e configura o sandbox; só em plataformas suportadas, não no Windows nativo | `/sandbox` | [sandboxing#get-started](https://code.claude.com/docs/en/sandboxing#get-started) |
| `/schedule` [pago] [prévia] | Cria e gerencia rotinas que rodam na nuvem; alias `/routines` | `/schedule [descrição]` | [routines](https://code.claude.com/docs/en/routines) |
| `/security-review` | Revisa as mudanças do branch atual atrás de vulnerabilidades; precisa do remoto `origin` | `/security-review` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/skills` | Lista as skills; `t` ordena por tokens, `Space` muda a visibilidade | `/skills` | [skills#override-skill-visibility-from-settings](https://code.claude.com/docs/en/skills#override-skill-visibility-from-settings) |
| `/status` | Mostra versão, modelo, conta, conectividade e os settings carregados | `/status` | [settings#check-what-loaded](https://code.claude.com/docs/en/settings#check-what-loaded) |
| `/statusline` | Configura a barra de status, com o subagente statusline-setup | `/statusline [descrição]` | [statusline](https://code.claude.com/docs/en/statusline) |
| `/subtask` | Cria um fork em segundo plano que herda a conversa | `/subtask <tarefa>` | [sub-agents#fork-the-current-conversation](https://code.claude.com/docs/en/sub-agents#fork-the-current-conversation) |
| `/tasks` | Lista e controla o trabalho em segundo plano, inclusive subagentes; alias `/bashes` | `/tasks` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/terminal-setup` | Instala o atalho `Shift+Enter` no VS Code, Cursor, Devin Desktop, Alacritty ou Zed | `/terminal-setup` | [terminal-config#enter-multiline-prompts](https://code.claude.com/docs/en/terminal-config#enter-multiline-prompts) |
| `/theme` | Troca o tema de cores | `/theme` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/update-config` | Skill: você descreve a mudança e o Claude edita o `settings.json` certo | `/update-config <pedido>` | [commands#all-commands](https://code.claude.com/docs/en/commands#all-commands) |
| `/usage` | Custo da sessão, limites do plano e estatísticas; aliases `/cost` e `/stats` | `/usage` | [costs#track-your-costs](https://code.claude.com/docs/en/costs#track-your-costs) |

### Atalhos e gestos

| Termo | O que é | Como se usa | Link |
|---|---|---|---|
| `!` (modo shell) | Roda um comando de shell direto, põe a saída no contexto, e o Claude comenta | `! git status`. No Windows roda em Bash (Git Bash) por padrão, ou em PowerShell quando não há Bash; `"defaultShell": "powershell"` muda | [interactive-mode#shell-mode-with-prefix](https://code.claude.com/docs/en/interactive-mode#shell-mode-with-prefix), [settings-reference#defaultshell](https://code.claude.com/docs/en/settings-reference#defaultshell) |
| `@` | Menciona um arquivo, com autocompletar de caminho; também menciona subagentes | `@src/app.ts`; `@agent-<nome>` | [interactive-mode#quick-commands](https://code.claude.com/docs/en/interactive-mode#quick-commands) |
| `/` | Abre o menu de comandos e skills | `/` e letras para filtrar | [interactive-mode#quick-commands](https://code.claude.com/docs/en/interactive-mode#quick-commands) |
| `?` | Com o prompt vazio, mostra o painel de atalhos | `?` | [interactive-mode#quick-commands](https://code.claude.com/docs/en/interactive-mode#quick-commands) |
| Quebra de linha | Nova linha sem enviar | `\` e `Enter`, ou `Ctrl+J`, em qualquer terminal; `Shift+Enter` nativo no Windows Terminal | [interactive-mode#multiline-input](https://code.claude.com/docs/en/interactive-mode#multiline-input) |
| `Shift+Tab` | Alterna os modos de permissão: auto, Manual, acceptEdits, plan | `Shift+Tab` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Alt+M` | Faz o papel do `Shift+Tab` no Windows quando o runtime não ativa o modo VT | `Alt+M` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Esc` | Interrompe o Claude e mantém o que já foi feito; fecha diálogos; num prompt de permissão, recusa | `Esc` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Esc` `Esc` | Com texto no prompt, limpa; com o prompt vazio, abre o menu de rewind | `Esc` duas vezes | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Ctrl+C` | Interrompe; sem nada rodando, limpa o prompt, e na segunda vez sai | `Ctrl+C` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Ctrl+D` | Sai da sessão: duas vezes em 800 ms | `Ctrl+D` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Ctrl+R` | Busca reversa no histórico de prompts | `Ctrl+R` | [interactive-mode#command-history](https://code.claude.com/docs/en/interactive-mode#command-history) |
| `Ctrl+O` | Abre o visualizador da transcrição, com o detalhe das ferramentas e o raciocínio | `Ctrl+O` | [interactive-mode#transcript-viewer](https://code.claude.com/docs/en/interactive-mode#transcript-viewer) |
| `←` com o campo vazio | Manda a sessão inteira para segundo plano e abre a agent view; o mesmo que `/background` | `←`; `Esc` volta ao terminal | [agent-view](https://code.claude.com/docs/en/agent-view) |
| `Ctrl+B` | Manda comandos e agentes em andamento para segundo plano; no tmux, duas vezes | `Ctrl+B` | [interactive-mode#background-bash-commands](https://code.claude.com/docs/en/interactive-mode#background-bash-commands) |
| `Ctrl+G` | Abre o prompt, ou o plano, no editor de texto padrão | `Ctrl+G` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Ctrl+T` | Mostra ou esconde a lista de tarefas do Claude | `Ctrl+T` | [interactive-mode#task-list](https://code.claude.com/docs/en/interactive-mode#task-list) |
| `Ctrl+S` | Guarda o texto do prompt e o devolve depois | `Ctrl+S` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Ctrl+L` | Redesenha a tela quando ela fica bagunçada | `Ctrl+L` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Alt+V` / `Ctrl+V` | Cola uma imagem da área de transferência como `[Image #N]` | No Windows e no WSL, `Alt+V`; nos demais, `Ctrl+V` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Alt+P` | Troca o modelo sem limpar o prompt | `Alt+P` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Alt+T` | Liga ou desliga o extended thinking | `Alt+T` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Alt+O` | Liga ou desliga o fast mode | `Alt+O` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Ctrl+X` `Ctrl+K` | Para todos os subagentes em segundo plano; confirme apertando de novo em 3 segundos | `Ctrl+X` `Ctrl+K` | [interactive-mode#general-controls](https://code.claude.com/docs/en/interactive-mode#general-controls) |
| `Ctrl+Enter` | Envia já as mensagens que você enfileirou enquanto o Claude trabalhava | `Ctrl+Enter`, ou `Ctrl+X` `Ctrl+S` em terminais sem teclas estendidas | [interactive-mode#queue-messages-while-claude-works](https://code.claude.com/docs/en/interactive-mode#queue-messages-while-claude-works) |
| `↑` / `↓` | Navega no histórico de prompts, inclusive de sessões anteriores do projeto | `↑`, `↓` | [interactive-mode#command-history](https://code.claude.com/docs/en/interactive-mode#command-history) |
| `claude --continue` / `-c` | Retoma a conversa mais recente do diretório atual | `claude -c` | [cli-reference#cli-flags](https://code.claude.com/docs/en/cli-reference#cli-flags) |
| `claude --resume` / `-r` | Retoma uma sessão por ID ou nome, ou abre o seletor | `claude -r "nome"` | [cli-reference#cli-flags](https://code.claude.com/docs/en/cli-reference#cli-flags) |

### Automação, segundo plano e superfícies

| Termo | O que é | Como se usa | Link |
|---|---|---|---|
| Modo não interativo (`-p`, antes "headless") | Roda um prompt e sai, para scripts e CI | `claude -p "pergunta"` | [headless](https://code.claude.com/docs/en/headless) |
| `--output-format` | Formato da saída no `-p`: `text`, `json` ou `stream-json` | `claude -p "..." --output-format json` | [headless#get-structured-output](https://code.claude.com/docs/en/headless#get-structured-output) |
| `--bare` | Abre sem hooks (o freio não roda), subagentes, plugins, MCP, memória automática e CLAUDE.md, e exige `ANTHROPIC_API_KEY`; as skills continuam chamáveis por `/nome`; a documentação recomenda para CI | `claude --bare -p "..."` | [headless#start-faster-with-bare-mode](https://code.claude.com/docs/en/headless#start-faster-with-bare-mode) |
| `--allowedTools` e `--disallowedTools` | Allow e deny pela linha de comando, só naquela sessão | `--allowedTools "Bash(git log *)" "Read"` | [cli-reference#cli-flags](https://code.claude.com/docs/en/cli-reference#cli-flags) |
| `--permission-mode` | Modo inicial da sessão | `claude --permission-mode plan` | [cli-reference#cli-flags](https://code.claude.com/docs/en/cli-reference#cli-flags) |
| `--dangerously-skip-permissions` | O mesmo que o modo `bypassPermissions` | Só em container ou máquina virtual | [cli-reference#cli-flags](https://code.claude.com/docs/en/cli-reference#cli-flags) |
| `--add-dir` | Diretório extra de trabalho; também carrega as skills, os comandos e os agentes dele | `claude --add-dir ../lib` | [cli-reference#cli-flags](https://code.claude.com/docs/en/cli-reference#cli-flags) |
| `--agent` e `--agents` | Roda a sessão como um subagente; define subagentes por JSON só para a sessão | `claude --agent code-reviewer` | [sub-agents#invoke-subagents-explicitly](https://code.claude.com/docs/en/sub-agents#invoke-subagents-explicitly) |
| `--safe-mode` | Abre sem nenhuma personalização, para diagnosticar uma configuração quebrada | `claude --safe-mode` | [cli-reference#cli-flags](https://code.claude.com/docs/en/cli-reference#cli-flags) |
| `claude doctor` | Diagnóstico só leitura da instalação e dos settings, sem abrir sessão | `claude doctor` | [cli-reference#cli-commands](https://code.claude.com/docs/en/cli-reference#cli-commands) |
| Worktree | Cópia isolada do repositório, num git worktree, para sessões em paralelo | `claude --worktree <nome>` ou `-w`; `isolation: worktree` no subagente | [worktrees](https://code.claude.com/docs/en/worktrees) |
| Tarefas em segundo plano | Comandos de shell e subagentes que rodam sem travar a conversa | `Ctrl+B`; `/tasks` | [interactive-mode#background-bash-commands](https://code.claude.com/docs/en/interactive-mode#background-bash-commands) |
| Agent view [prévia] | Uma tela para despachar e acompanhar sessões que rodam sem terminal | `claude agents`; `claude --bg "<tarefa>"`; `/background` | [agent-view](https://code.claude.com/docs/en/agent-view) |
| `claude attach`, `logs`, `stop` e `rm` | Comandos de terminal das sessões em segundo plano: abrir, ver as últimas linhas, parar e tirar da lista | `claude attach <id ou nome>`; `claude logs <id ou nome>`; `claude stop <id>` | [agent-view](https://code.claude.com/docs/en/agent-view) |
| Agent SDK | Biblioteca Python e TypeScript com as ferramentas e o loop do Claude Code | Pacotes do SDK, ou `claude -p` pela CLI | [agent-sdk/overview](https://code.claude.com/docs/en/agent-sdk/overview) |
| GitHub Actions e `@claude` | Action que roda o Claude Code nos workflows; mencionar `@claude` num PR ou numa issue aciona o Claude | `/install-github-app`, ou instalação manual | [github-actions](https://code.claude.com/docs/en/github-actions) |
| `/loop` e tarefas agendadas | Repetem um prompt na sessão aberta; intervalo mínimo de 1 minuto; a sessão precisa ficar aberta | `/loop 5m check if the deploy finished` | [scheduled-tasks#compare-scheduling-options](https://code.claude.com/docs/en/scheduled-tasks#compare-scheduling-options) |
| Rotinas [pago] [prévia] | Configuração salva que roda na nuvem por agenda, por chamada de API ou por evento do GitHub; intervalo mínimo de 1 hora | `/schedule`, ou claude.ai/code/routines | [routines](https://code.claude.com/docs/en/routines) |
| Remote Control [pago] | Continua uma sessão local pelo celular ou navegador; o código segue rodando na sua máquina; não funciona com chave de API | `claude --remote-control`; `/remote-control` | [remote-control#requirements](https://code.claude.com/docs/en/remote-control#requirements) |
| Sessão na nuvem / Claude Code na web [pago] | Sessão que roda na nuvem, num clone do repositório; "Claude Code on the web" hoje nomeia só o acesso pelo navegador | claude.ai/code; `claude --cloud "<tarefa>"`; `/teleport` traz para o terminal | [claude-code-on-the-web](https://code.claude.com/docs/en/claude-code-on-the-web) |
| App desktop [pago] | App do Claude com a aba Code; macOS, Windows x64 e ARM64, Linux em beta | Instale o app; `/desktop` leva a sessão do CLI para o app | [desktop](https://code.claude.com/docs/en/desktop) |
| Extensão do VS Code | Interface gráfica do Claude Code dentro do VS Code 1.94 ou mais novo, com diffs, menções e revisão de plano | Instale a extensão e entre com a conta | [vs-code#prerequisites](https://code.claude.com/docs/en/vs-code#prerequisites) |
| JetBrains | Plugin para IntelliJ, PyCharm, WebStorm e outras IDEs, com diff na IDE e seleção compartilhada | `Ctrl+Esc` abre o Claude Code; `Alt+Ctrl+K` insere referência de arquivo | [jetbrains#features](https://code.claude.com/docs/en/jetbrains#features) |
| Claude in Chrome [pago] | Extensão que deixa o Claude abrir abas, ler o console e preencher formulários no Chrome ou no Edge; não funciona no WSL | `claude --chrome`; `/chrome` | [chrome#prerequisites](https://code.claude.com/docs/en/chrome#prerequisites) |

### O que saiu de cena

- **`#` (memória rápida):** removido na v2.0.70, de 15/12/2025. O changelog manda pedir ao Claude para editar o CLAUDE.md; o `/memory` abre o arquivo ([changelog](https://code.claude.com/docs/en/changelog), [memory#view-and-edit-with-%2Fmemory](https://code.claude.com/docs/en/memory#view-and-edit-with-%2Fmemory)).
- **`/vim`:** removido na v2.1.92. O vim mode continua, por `/config`, opção Editor mode ([commands#all-commands](https://code.claude.com/docs/en/commands#all-commands)).
- **Assistente do `/agents`:** removido na v2.1.198; o comando continua só como lembrete ([commands#all-commands](https://code.claude.com/docs/en/commands#all-commands)).

## Leia mais

- **O glossário oficial do Claude Code**, em inglês: https://code.claude.com/docs/en/glossary. Ele define os conceitos; este aqui acrescenta onde cada arquivo fica no Windows, como usar cada termo e o que vimos no workshop.
- **A lista de todos os comandos de barra:** https://code.claude.com/docs/en/commands.
- **Todos os atalhos de teclado:** https://code.claude.com/docs/en/interactive-mode.
- **O que mudou em cada versão:** https://code.claude.com/docs/en/changelog. Se algo aqui não bater com a sua tela, confira a sua versão com `claude --version`.