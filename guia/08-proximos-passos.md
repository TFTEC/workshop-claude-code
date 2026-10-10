# 08. Próximos passos

## Automação: o Claude sem você na frente

Tudo o que você fez no workshop foi interativo. O mesmo agente roda sem conversa, em script, em agendamento e no GitHub.

### Modo headless: `claude -p`

Manda um pedido, recebe a resposta e termina. Serve para script e CI.

```powershell
claude -p "Resuma em 5 tópicos o que mudou no último commit" --output-format text
```

- `--output-format json` devolve a resposta em JSON, para outro programa ler.
- `--allowedTools` diz quais ferramentas ele pode usar sem perguntar.
- `--bare` é o recomendado para CI: pula os hooks, os plugins, os subagentes, a memória automática e a busca do `CLAUDE.md`, e só carrega o que você passar na linha de comando (`--mcp-config`, `--settings`, `--agents`). Assim o resultado não depende da máquina. Dois cuidados: **sem hooks, o hook-freio não roda**; e o login do claude.ai não vale, porque o `--bare` exige `ANTHROPIC_API_KEY`. Para automatizar algo que toca no Azure, rode sem `--bare`, com o freio.

### `/loop`: repetir um pedido enquanto a sessão está aberta

O `/loop` agenda um pedido para repetir dentro da sessão em que você está. Serve para vigiar algo que demora, como um deploy, uma pipeline ou uma fila:

```text
/loop 10m Rode az deployment group show -g rg-app -n deploy-web --query properties.provisioningState -o tsv e me avise quando sair de Running.
```

- **Intervalo:** `s`, `m`, `h` ou `d`, com mínimo de 1 minuto. Sem intervalo (`/loop <pedido>`), o próprio Claude escolhe o ritmo, entre 1 minuto e 1 hora.
- **Só com a sessão aberta.** Fechou o Claude Code, o loop para. Uma tarefa repetida expira sozinha em 7 dias.
- **Cada volta é um turno normal**, que gasta tokens. Para vigiar por horas, prefira um intervalo maior.
- **Para parar:** no loop sem intervalo, **Esc**. Nos outros, peça: `cancele o loop do deploy`.

### `/schedule`: rotinas na nuvem

O `/schedule` cria uma **rotina**, que roda na infraestrutura da Anthropic, sem a sua máquina ligada.

| | `/loop` | `/schedule` |
|---|---|---|
| Onde roda | Na sua máquina, dentro da sessão | Na nuvem da Anthropic |
| Precisa da sessão aberta? | Sim | Não |
| Intervalo mínimo | 1 minuto | 1 hora |
| Cota | A da sua sessão: cada volta é um turno normal | Pro, Max, Team ou Enterprise, com login no claude.ai. Ainda é *research preview* |

### GitHub

`/install-github-app` configura o Claude no repositório (só para repositórios no github.com). Depois, mencionar `@claude` numa issue ou num PR põe o agente para trabalhar ali. A Action oficial é `anthropics/claude-code-action@v1`.

Uma ideia para levar: rodar o relatório FinOps toda segunda-feira, no modo anonimizado, e postar o HTML para a equipe.

## Segurança: as três proteções

Antes de apontar o agente para um ambiente real, confira:

1. **Permissão mínima.** A identidade que o Claude usa tem só o que a tarefa pede. Para ler o Azure, o papel **Reader**; para custo, **Cost Management Reader**. Nada de Contributor "por garantia".
2. **Um hook que barra o perigoso.** Instrução no `CLAUDE.md` é um pedido; o hook `PreToolUse` com exit 2 é um impedimento (parte 05). Teste o hook **dentro do Claude** antes de confiar nele.
3. **Modo de permissão adequado.** Em ambiente real, prefira o manual mode, que pergunta antes de agir. `bypassPermissions` só em container ou VM isolados.

E mais:

- **Nunca ponha segredo** em `CLAUDE.md`, skill ou ficha: eles vão para o git.
- **Plugins e hooks de terceiros rodam com as suas permissões.** Instale só da fonte oficial de cada projeto.
- **Mostre só o anonimizado** em tela compartilhada. A saída do `az account show` traz ID de subscription, de tenant e o seu e-mail.

## Como seguir praticando

1. **Use no seu dia a dia, com um pedido pequeno por vez:** um script, um runbook (a skill `gerar-runbook` do exercício 5), a revisão de uma configuração.
2. **Escreva o `CLAUDE.md` do seu projeto real** e confira no `/context` o que carregou.
3. **Termine o relatório FinOps:** os tickets 06 e 07, o custo real, uma regra sua.
4. **Crie um hook para o seu risco:** um freio para `kubectl delete`, `terraform destroy` ou `DROP TABLE`, com testes.
5. **Experimente o fluxo completo** num projeto seu: `/mattpocock-skills:grill-with-docs`, `to-spec`, `to-tickets` e `implement`.

## Onde aprender mais

| Assunto | Link |
|---|---|
| Documentação do Claude Code | https://code.claude.com/docs |
| Novidades de cada versão | https://code.claude.com/docs/en/changelog |
| Modo headless | https://code.claude.com/docs/en/headless |
| GitHub Actions | https://code.claude.com/docs/en/github-actions |
| `/loop` e tarefas agendadas | https://code.claude.com/docs/en/scheduled-tasks |
| Rotinas (`/schedule`) | https://code.claude.com/docs/en/routines |
| Sessões em segundo plano e agent view | https://code.claude.com/docs/en/agent-view |
| Skills do Matt Pocock | https://github.com/mattpocock/skills |
| Skills e plugins oficiais da Anthropic | https://github.com/anthropics/skills e https://github.com/anthropics/claude-plugins-official |
| Documentação do Azure, pelo MCP | https://learn.microsoft.com/api/mcp |
| Este repositório | `README.md`, as fichas em `exercicios/` e a branch `gabarito` |

Dentro do Claude Code, `/help` e `?` mostram os comandos e atalhos, e você pode simplesmente perguntar: "como eu faço X no Claude Code?".
