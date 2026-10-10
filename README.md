# Workshop Claude Code na prática — TFTEC Masters

Este é o repositório do aluno do workshop de Claude Code da TFTEC Masters: sábado, 10/10/2026, das 9h às 12h e das 13h30 às 17h (horário de Brasília), online e ao vivo. De manhã, o instrutor demonstra ao vivo como funciona cada funcionalidade do Claude Code; acompanhe na sua máquina se quiser. À tarde, a turma constrói um projeto de ponta a ponta: um relatório FinOps que lê uma subscription Azure sua e aponta oportunidades de economia.

> **O workshop só lê o Azure.** Nada é criado, alterado ou apagado na sua subscription; basta o papel **Reader**. À tarde, antes de apontar o Claude para o Azure, você cria o hook-freio, que bloqueia qualquer comando de escrita.

## Como clonar

```powershell
git clone https://github.com/TFTEC/workshop-claude-code workshop-claude-code
cd workshop-claude-code
claude
```

## Ordem do dia

1. **Antes de sábado: checklist pré-workshop.** Siga o [checklist-pre-workshop.md](checklist-pre-workshop.md) até sexta, 09/10, às 22h.
2. **Manhã: demonstrações.** O instrutor mostra como funciona cada funcionalidade; o guia em `guia/` (partes 01 a 05) explica cada uma com calma. As fichas de `exercicios/01` a `06` são prática opcional, para repetir depois no seu ritmo.
3. **Tarde: relatório FinOps.** A spec e os tickets prontos estão em `.scratch/relatorio-finops/`, e o vocabulário do relatório está no `CONTEXT.md`. Comece pelo ticket 01. Depois dele, os tickets 02 a 05 podem andar em paralelo. Sem acesso a uma subscription? Use a fonte `Arquivo` com os dados fictícios de `dados-ficticios/`. Se travar, compare com a branch `gabarito`.

## Guia do aluno

O material de leitura, com os conceitos de cada bloco explicados e exemplos prontos para copiar, está em [`guia/`](guia/README.md). Use durante o workshop e para consultar depois. Para uma consulta rápida, o [glossário](guia/glossario.md) mostra onde cada arquivo do Claude Code fica, como editar, e os termos de A a Z com o link oficial.

## Deck

Os slides dos blocos de teoria estão em `deck/` e publicados em https://claude.ai/artifact/Vo2mCF9HR3942Z8of6bCLP.
