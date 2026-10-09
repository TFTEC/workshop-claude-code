<!--
Notas para humanos. Este bloco é um comentário HTML: o Claude Code o remove antes de colocar
o CLAUDE.md no contexto, então ele não gasta tokens. Abra o arquivo no VS Code para ler.

O que é este arquivo: a memória do projeto. O Claude Code carrega o CLAUDE.md no começo de toda
sessão aberta nesta pasta. Ele vai para o git e vale para a turma toda. Mantenha curto: tudo o
que fica fora dos comentários é pago em toda mensagem.

A camada de agente de exemplo deste repositório (exercício 4):
- CLAUDE.md (este arquivo): o que é o projeto e onde ficam as coisas.
- .claude/rules/combinados.md: regra sem `paths`. Carrega junto com este arquivo, em toda sessão.
- .claude/rules/powershell-do-relatorio.md: regra com `paths`. Só carrega quando o Claude lê ou
  edita um arquivo que casa com relatorio/**/*.ps1 ou relatorio/**/*.psd1.
- AGENTS.md: o mesmo conteúdo essencial, para outros agentes de código. O Claude Code o ignora
  aqui, porque este CLAUDE.md existe.
- CLAUDE.local.md: as suas instruções pessoais. Você cria no exercício 4; o .gitignore já o
  deixa fora do git.

CLAUDE.md e regras são pedidos ao Claude, não impedimentos. Quem impede um comando de escrita no Azure
é o hook-freio, que você cria à tarde.

Para ver o que carregou: /context (lista "Memory files"). Para abrir e editar: /memory.
-->

# Workshop Claude Code — repositório do aluno

Repositório do aluno do workshop de Claude Code da TFTEC Masters. De manhã, o aluno faz os exercícios das fichas em `exercicios/`. À tarde, a turma constrói o projeto da turma: um relatório FinOps em PowerShell 7 que lê uma subscription Azure, sem alterar nada, e aponta oportunidades de economia de acordo com as regras FinOps. Os tickets prontos do relatório ficam em `.scratch/relatorio-finops/`.

## Agent skills

### Issue tracker

Issues e specs como arquivos markdown em `.scratch/<feature>/`. Ver `docs/agents/issue-tracker.md`.

### Triage labels

Os cinco papéis canônicos com os nomes padrão (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). Ver `docs/agents/triage-labels.md`.

### Domain docs

Single-context: um `CONTEXT.md` e `docs/adr/` na raiz. Ver `docs/agents/domain.md`.
