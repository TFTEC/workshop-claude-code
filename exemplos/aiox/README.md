# AIOX: cópia sanitizada

Esta pasta é uma amostra da camada de agente que o AIOX gera. Ela vem de um projeto da TFTEC com o AIOX instalado sem customização, em abril/2026. O AIOX é o framework de agentes da Synkra, com código aberto sob licença MIT ([SynkraAI/aiox-core](https://github.com/SynkraAI/aiox-core)). Os arquivos daqui são os que o instalador gerou, copiados sem alteração. O código do site e o framework em si (`.aiox-core/`) ficaram de fora; do framework, veio só a contagem.

A pasta `.claude/` virou `.claude.exemplo/`, e o `CLAUDE.md` dentro dela virou `CLAUDE.md.exemplo`, para o Claude Code não carregar as 356 linhas do AIOX no seu clone. No projeto original, os nomes são `.claude/` e `.claude/CLAUDE.md`. Não renomeie de volta.

```
.claude.exemplo/CLAUDE.md.exemplo                  a instrução gerada pelo framework
.claude.exemplo/settings.json                      a configuração versionada do projeto
.claude.exemplo/commands/AIOX/agents/dev.md        persona @dev (Dex)
.claude.exemplo/commands/AIOX/agents/qa.md         persona @qa (Quinn)
.claude.exemplo/rules/agent-authority.md           quem pode fazer o quê
.claude.exemplo/rules/story-lifecycle.md           os estados da story e os gates
.claude.exemplo/rules/workflow-execution.md        os 4 workflows do framework
CONTAGEM.md                                        o número de arquivos da camada inteira
LICENSE                                            a licença MIT do AIOX
```

Os 12 agentes que o instalador gerou em `.claude/commands/AIOX/agents/`:
- `aiox-master.md`
- `analyst.md`
- `architect.md`
- `data-engineer.md`
- `dev.md`
- `devops.md`
- `pm.md`
- `po.md`
- `qa.md`
- `sm.md`
- `squad-creator.md`
- `ux-design-expert.md`

As 10 regras de `.claude/rules/`, das quais 3 vieram para cá:
- `agent-authority.md`
- `agent-handoff.md`
- `agent-memory-imports.md`
- `coderabbit-integration.md`
- `ids-principles.md`
- `mcp-usage.md`
- `story-lifecycle.md`
- `tool-examples.md`
- `tool-response-filtering.md`
- `workflow-execution.md`

## O que mostrar na demo

1. **O `CLAUDE.md` gerado.** No projeto, ele mora em `.claude/CLAUDE.md` (aqui, em `.claude.exemplo/CLAUDE.md.exemplo`) e tem 356 linhas, iguais em qualquer projeto. Os blocos entre `AIOX-MANAGED-START` e `AIOX-MANAGED-END` são do instalador, que os regrava a cada atualização. O texto vale para qualquer projeto: manda rodar `npm run lint` e `npm run typecheck` sem saber se esses scripts existem. Compare com o `CLAUDE.md` de `../formato-enxuto/`, que fala só do projeto e avisa: "Não existe `npm run typecheck`".
2. **As personas.** São 12 agentes com nome, arquétipo e comandos próprios, ativados por `@dev` ou `/AIOX:agents:dev`. Só o `dev.md` tem 560 linhas. Leia o começo: ele manda o modelo "adotar a persona" e "ficar no personagem".
3. **A autoridade exclusiva.** Em `agent-authority.md`, só o `@devops` pode dar `git push` e abrir PR. O fluxo de uma story passa por cinco personas: `@sm *draft → @po *validate → @dev *develop → @qa *qa-gate → @devops *push`.
4. **A story como unidade de trabalho.** Em `story-lifecycle.md`, a story passa por Draft → Ready → InProgress → InReview → Done, com um checklist de 10 pontos e um gate de QA. No formato enxuto, a unidade é a issue.
5. **O que o framework promete e o que o `settings.json` entrega.** O `CLAUDE.md` diz que deny rules no `.claude/settings.json` protegem o framework, e o `aiox doctor` do próprio AIOX espera ao menos 40 delas. O `settings.json` gerado neste projeto tem só `{"language": "portuguese"}`. Os dois hooks que o AIOX instalou foram para o `settings.local.json`, que não vai para o git e guarda o caminho absoluto da máquina.
6. **O peso.** Abra o `CONTAGEM.md`: são mais de 1.200 arquivos de camada sem contar `node_modules/`, contra cerca de 50 no formato enxuto.

## O que foi removido

- Todo o código do site, o `.env`, o `.git` e o histórico do projeto.
- O `.aiox-core/` inteiro (só contado), a pasta `.aiox/`, com a configuração e o relatório do ambiente, o `AGENTS.md` da raiz e as cópias da camada para outras ferramentas (`.codex/`, `.cursor/`, `.gemini/`, `.antigravity/`).
- O `settings.local.json`, com as regras de permissão da máquina e os hooks com caminho local. Os hooks de `.claude/hooks/` também ficaram de fora.
- 10 dos 12 agentes e 7 das 10 regras, que estão listados acima só pelo nome.

Nos arquivos copiados não havia nome de cliente, de pessoa, e-mail, URL interna nem ID. Eles são o texto genérico do framework.
