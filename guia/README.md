# Guia do aluno: Claude Code na prática

Este guia é o material de leitura do workshop de Claude Code da TFTEC Masters. Ele explica **como cada funcionalidade funciona e por quê**, com exemplos do dia a dia de quem trabalha com infra e cloud. Leia antes de um bloco do workshop, para chegar com a ideia na cabeça, ou depois, para consultar quando for usar o Claude Code no seu trabalho.

- **Partes 01 a 05, os fundamentos:** acompanham as demonstrações da manhã. Os exemplos são genéricos, para você adaptar ao seu ambiente. As fichas da manhã, em `exercicios/`, são prática **opcional**, para fazer depois.
- **Partes 06 a 08, o formato de trabalho e o projeto:** acompanham a tarde, em que a turma constrói o relatório FinOps com as fichas 07, 08 e 09.

Cada parte explica um conceito em texto curto, mostra um exemplo com comandos, diz quando usar e aponta para a documentação oficial. Cada uma se lê em 5 a 10 minutos.

Para seguir o dia na ordem, bloco a bloco e com os comandos de cada demo, use o [guia do workshop](../guia-do-workshop.md). Este guia explica os conceitos de cada bloco.

## Índice

| Parte | Assunto | Prática |
|---|---|---|
| [01. O que é o Claude Code](01-o-que-e-o-claude-code.md) | O agente, o loop de trabalho, as superfícies, os planos e a instalação | [checklist](../checklist-pre-workshop.md) |
| [02. Sessão, contexto e custo](02-sessao-contexto-e-custo.md) | Primeira sessão, contexto e tokens, modelos, effort e quanto custa | Opcional: fichas [01](../exercicios/01-primeira-sessao.md) e [02](../exercicios/02-modelo-effort-tokens.md) |
| [03. Permissões, plan mode e rewind](03-permissoes-plan-mode-e-rewind.md) | Quanto o Claude faz sozinho, regras de permissão, planejar antes de editar e desfazer | Opcional: ficha [03](../exercicios/03-permissoes-plan-mode-rewind.md) |
| [04. Memória e instruções](04-memoria-e-instrucoes.md) | `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, regras e memória automática | Opcional: ficha [04](../exercicios/04-claude-md-e-memoria.md) |
| [05. Skills, plugins, MCP e hooks](05-skills-plugins-mcp-e-hooks.md) | Como estender o Claude Code com skills, subagentes, plugins e MCP, e como frear o que ele faz | Opcional: fichas [05](../exercicios/05-plugins-e-skills.md) e [06](../exercicios/06-mcps.md) |
| [06. Formato de trabalho](06-formato-de-trabalho.md) | Do framework pesado às peças soltas, o fluxo das skills, issue e worktree | Ficha [08](../exercicios/08-implementar-em-paralelo.md) |
| [07. O projeto da turma](07-o-projeto-da-turma.md) | O relatório FinOps: regras, arquitetura, "não sei" e o que o ensaio ensinou | Fichas [07](../exercicios/07-hook-freio.md), [08](../exercicios/08-implementar-em-paralelo.md) e [09](../exercicios/09-rodar-e-revisar.md) |
| [08. Próximos passos](08-proximos-passos.md) | Automação, segurança e onde aprender mais | — |
| [Glossário e mapa de arquivos](glossario.md) | Onde cada arquivo do Claude Code fica, como editar, e os termos de A a Z com o link oficial | — |

## Como usar

- **No workshop:** abra a parte da vez num segundo monitor ou no celular, enquanto o instrutor demonstra.
- **Depois:** use o índice como consulta. Os comandos estão prontos para copiar.
- **Com o próprio Claude:** peça "explique a parte 04 do guia com um exemplo do meu projeto". O guia está no repositório, e o Claude lê.

O vocabulário segue o glossário do projeto, em [`CONTEXT.md`](../CONTEXT.md). A documentação oficial do Claude Code fica em https://code.claude.com/docs.
