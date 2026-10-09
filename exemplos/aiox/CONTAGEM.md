# Contagem: o peso da camada do AIOX

Contagem feita em 08/10/2026 no projeto de origem, uma instalação do AIOX 5.0.4 (pelo `version.json`) feita em abril/2026, sem customização (`"customized": []`).

## Arquivos

| Pasta | Arquivos | O que é |
|---|---:|---|
| `.aiox-core/` | 8.338 | O framework instalado no projeto |
| ↳ sem `node_modules/` | 1.110 | Código, tasks, templates, workflows, agentes e docs do framework |
| ↳ `node_modules/` | 7.228 | Dependências do framework |
| `.claude/` | 28 | A camada que o Claude Code lê |
| `.gemini/` | 25 | A mesma camada para o Gemini CLI |
| `.codex/`, `.cursor/`, `.antigravity/` | 12 cada | A mesma camada para outras ferramentas |
| `.aiox/` | 2 | Configuração do projeto e relatório do ambiente |
| `AGENTS.md` (raiz) | 1 | Instruções para o Codex CLI |

Sem `node_modules/`, a camada inteira passa de 1.200 arquivos.

## Dentro de `.aiox-core/` (sem `node_modules/`)

| Pasta | Arquivos |
|---|---:|
| `development/` | 363 |
| ↳ `development/tasks/` | 208 |
| ↳ `development/scripts/` | 70 |
| ↳ `development/templates/` | 34 |
| ↳ `development/agents/` | 22 |
| ↳ `development/workflows/` | 15 |
| `core/` | 264 |
| `infrastructure/` | 174 |
| `product/` | 129 |
| `scripts/` | 55 |
| `cli/` | 41 |
| `data/` | 23 |
| `workflow-intelligence/` | 19 |
| `docs/` | 11 |
| `monitor/` | 10 |
| Outras pastas (`schemas/`, `elicitation/`, `manifests/`, `presets/`) | 11 |
| Arquivos na raiz (`constitution.md`, `core-config.yaml`, `user-guide.md`…) | 10 |

São 354 arquivos `.md` só no framework.

## Dentro de `.claude/`

| Item | Arquivos | Tamanho |
|---|---:|---|
| `CLAUDE.md` | 1 | 356 linhas |
| Agentes em `commands/AIOX/agents/` | 12 | 5.093 linhas no total (o `dev.md` sozinho tem 560) |
| Regras em `rules/` | 10 | 1.029 linhas no total |
| Hooks em `hooks/` | 3 | 2 scripts e um README |
| `settings.json` | 1 | 3 linhas, só o idioma |
| `settings.local.json` | 1 | 2 regras `allow` e os 2 hooks do AIOX, com caminho absoluto da máquina |

## Para comparar com o formato enxuto

| | AIOX | Formato enxuto (`../formato-enxuto/`) |
|---|---|---|
| Instrução principal | `.claude/CLAUDE.md`, 356 linhas genéricas | `CLAUDE.md`, 97 linhas sobre o projeto |
| Unidade de trabalho | Story em `docs/stories/` | Issue do GitHub, uma worktree por issue |
| Quem faz o quê | 12 personas com autoridade exclusiva | Skills pequenas que se compõem |
| Arquivos da camada | Mais de 1.200, sem `node_modules/` | Cerca de 50, mais o fork das skills (111) |
