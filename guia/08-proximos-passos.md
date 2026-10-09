# 08. Próximos passos

## Automação: o Claude sem você na frente

Tudo o que você fez no workshop foi interativo. O mesmo agente roda sem conversa, em script, em agendamento e no GitHub.

**Modo headless** (`claude -p`): manda um pedido, recebe a resposta e termina. Serve para script e CI.

```powershell
claude -p "Resuma em 5 tópicos o que mudou no último commit" --output-format text
```

- `--output-format json` devolve a resposta em JSON, para outro programa ler.
- `--allowedTools` diz quais ferramentas ele pode usar sem perguntar.
- `--bare` é o recomendado para script e CI: pula hooks, skills, plugins e MCP que não estejam na linha de comando, para o resultado não depender da máquina.

**Agendamentos:**

- `/loop 5m <pedido>` repete um pedido na própria sessão aberta, de tempos em tempos.
- `/schedule` cria uma rotina na nuvem, que roda sem a sua máquina, com intervalo mínimo de 1 hora.

**GitHub:** `/install-github-app` configura o Claude no repositório (só para repositórios no github.com). Depois, mencionar `@claude` numa issue ou num PR põe o agente para trabalhar ali. A Action oficial é `anthropics/claude-code-action@v1`.

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
| Agendamentos | https://code.claude.com/docs/en/scheduled-tasks |
| Skills do Matt Pocock | https://github.com/mattpocock/skills |
| Skills e plugins oficiais da Anthropic | https://github.com/anthropics/skills e https://github.com/anthropics/claude-plugins-official |
| Documentação do Azure, pelo MCP | https://learn.microsoft.com/api/mcp |
| Este repositório | `README.md`, as fichas em `exercicios/` e a branch `gabarito` |

Dentro do Claude Code, `/help` e `?` mostram os comandos e atalhos, e você pode simplesmente perguntar: "como eu faço X no Claude Code?".
