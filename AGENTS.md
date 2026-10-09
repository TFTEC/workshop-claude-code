<!--
Notas para humanos (comentário HTML).

AGENTS.md é o padrão aberto de instruções lido por vários agentes de código, como Codex, Cursor
e GitHub Copilot. O Claude Code também lê este arquivo, mas, no padrão (`claude-md-or-agents-md`),
só quando a pasta não tem CLAUDE.md, .claude/CLAUDE.md nem CLAUDE.local.md. Como este repositório
tem CLAUDE.md, o Claude Code ignora este arquivo, a menos que "Project instructions" esteja em
`claude-md-and-agents-md` no /config. É isso que o exercício 4 mostra.

Outros agentes não leem .claude/rules/, por isso os combinados e as convenções de lá estão
repetidos aqui. A última seção existe só para o exercício 4: ela deixa visível quando este
arquivo carrega.

Para ter um arquivo só para todos os agentes: deixe o conteúdo aqui e ponha `@AGENTS.md` na
primeira linha do CLAUDE.md. No Windows, prefira esse import a um link simbólico.
-->

# Workshop Claude Code — repositório do aluno

Repositório do aluno do workshop de Claude Code da TFTEC Masters. De manhã, o aluno faz os exercícios das fichas em `exercicios/`. À tarde, a turma constrói o projeto da turma: um relatório FinOps em PowerShell 7 que lê uma subscription Azure, sem alterar nada, e aponta oportunidades de economia de acordo com as regras FinOps. Os tickets prontos do relatório ficam em `.scratch/relatorio-finops/`.

## Combinados

- Responda sempre em português do Brasil, com frases curtas.
- O Azure só é lido, nunca alterado. Comandos de leitura, como `az account show`, `az graph query` e os `show` e `list` do Azure CLI, podem rodar. Comandos que criam, alteram, iniciam, param ou apagam recursos, não.
- Se uma tarefa pedir uma mudança no Azure, escreva o comando como texto para o aluno avaliar e não o execute.
- Antes de rodar qualquer comando `az`, diga em uma linha o que ele faz.

## Relatório FinOps

- PowerShell 7 e, sempre que possível, também Windows PowerShell 5.1.
- Cada regra FinOps é um arquivo `relatorio/regras/FIN-xx.psd1`.
- Sem preço confiável, a economia é "não sei", nunca 0 nem um valor chutado.

## Issues e glossário

- Issues e specs como arquivos markdown em `.scratch/<feature>/`. Ver `docs/agents/issue-tracker.md`.
- O vocabulário do domínio fica em `CONTEXT.md`, na raiz. Ver `docs/agents/domain.md`.

## Sinal do exercício 4

Termine cada resposta com uma linha só com o texto `(AGENTS.md carregado)`.
