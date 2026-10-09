# Formato enxuto: cópia sanitizada

Esta pasta é uma cópia sanitizada da camada de agente de um repositório interno da TFTEC, criado em setembro/2026 e copiado em outubro/2026. É uma amostra: os arquivos que mostram o método vieram, quase sempre inteiros. Os que só fazem sentido com as contas e os ambientes da empresa ficaram de fora. Nenhum código da aplicação veio junto.

Os arquivos de instrução ganharam o sufixo `.exemplo` (`CLAUDE.md.exemplo`, `AGENTS.md.exemplo` e `.claude.exemplo/`) para o Claude Code não carregá-los no seu clone nem disparar o hook. No projeto original, eles se chamam `CLAUDE.md`, `AGENTS.md` e `.claude/`. Não renomeie de volta.

```
CLAUDE.md.exemplo                  instrução do projeto, curta
AGENTS.md.exemplo                  só um ponteiro para o CLAUDE.md
CONTEXT.md                         trecho do glossário (8 termos)
docs/adr/0003-...md                uma decisão registrada
docs/agents/README.md              índice dos processos
docs/agents/*.md                   6 documentos de processo
.claude.exemplo/settings.json      configuração do projeto: só o hook de partida
scripts/agentes/retrato-da-partida.mjs  o hook (com os módulos em retrato/)
scripts/agentes/guarda-docs.test.mjs    o teste-guarda da documentação
```

## O que mostrar na demo

1. **`CLAUDE.md` curto.** São 88 linhas nesta cópia e 97 no original. Ele não ensina a programar: traz o mapa das pastas, as "Regras que o código não confessa", o "Estado que engana", as regras das sessões em paralelo e a tabela "Escolha da skill". Compare com o `.claude/CLAUDE.md` do AIOX, em `../aiox/`, que tem 356 linhas genéricas.
2. **Glossário com ADRs.** No `CONTEXT.md`, cada termo tem uma definição e uma linha `_Avoid_` com os sinônimos proibidos. O ADR-0003 cita a seção "Pessoas" do glossário e registra o decisor, a data e a regra que ele substitui.
3. **Processos em `docs/agents/`.** O índice aponta um documento por processo. Em `coordenacao-de-sessoes.md` estão a issue como unidade de trabalho, uma worktree por issue, um "*Pronto quando:*" em cada passo e o modelo do "onde parei". Em `skills-do-matt-pocock.md` está como as skills do Matt Pocock entram no projeto.
4. **O hook `retrato-da-partida`.** O `.claude/settings.json` declara o hook `SessionStart`, que roda o script e mostra à sessão o estado real (git, PRs, issues em andamento, worktrees, sessões vivas) antes da primeira resposta. Siga o caminho do `settings.json` até o script e depois até `docs/agents/retrato-da-partida.md`.
5. **O teste-guarda.** Rode `node --test scripts/agentes/guarda-docs.test.mjs` dentro desta pasta. Os 6 testes passam. Depois apague um link do índice ou estique o `CLAUDE.md.exemplo` além de 200 linhas e mostre o vermelho.
6. **O peso.** No original, a camada própria tem cerca de 50 arquivos: `CLAUDE.md`, `AGENTS.md`, `CONTEXT.md`, `.claude/settings.json`, 5 ADRs, 22 arquivos de processo, 19 scripts de agente e uma skill do projeto. A eles se soma o fork das skills do Matt Pocock, com 111 arquivos do autor. Compare com o `CONTAGEM.md` do AIOX.

**Cuidados:**

- Não rode o retrato sem `RETRATO_SEM_AVANCO=1`. Ele faz `git fetch` e, quando é seguro, avança a `main` do checkout principal do repositório em que estiver. Para só ver o retrato, rode `RETRATO_SEM_AVANCO=1 node scripts/agentes/retrato-da-partida.mjs`.
- Não renomeie `CLAUDE.md.exemplo`, `AGENTS.md.exemplo` nem `.claude.exemplo/` para os nomes originais. Com os nomes originais, o Claude Code carregaria estas instruções no seu clone, e o `settings.json` dispararia o hook na partida.

## O que foi removido

- Todo o código da aplicação (frontend, API, SQL, sites), os dados, o `.env`, o `settings.local.json`, o `.mcp.json`, o fork das skills (`claude-plugins/`), a skill do projeto e as worktrees.
- Os nomes do sistema e dos produtos, de clientes, parceiros comerciais e plataformas de venda, de pessoas e do repositório de origem.
- Os nomes de banco, de Key Vault e de serviços, os IDs de medição, os endereços dos sites, as contas de anúncio e os números de negócio.
- 4 dos 5 ADRs, 15 dos 22 arquivos de processo (os de operação, a faxina e as permissões) e os outros scripts de agente com seus testes. Do teste-guarda saíram as regras que conferiam os documentos removidos.
- Os caminhos locais viraram `<projeto>`, e alguns exemplos dos documentos foram trocados por descrições neutras. Onde um documento citava outro que não veio, o texto diz "fora desta cópia".
