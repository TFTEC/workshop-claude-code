# Índice de processos da operação

Cada processo que as sessões executam tem um documento vivo aqui. Antes de agir num processo, leia o documento dele. O repositório é a fonte da verdade do "como fazer" (decisão do dono, 28/09/2026, spec #76): a memória local da máquina guarda só preferências do dono e o "onde paramos", e não chega a outras worktrees, máquinas ou rotinas na nuvem.

"Pendente (#N)" = o documento ainda não existe; a issue entre parênteses é quem vai escrevê-lo. Até lá, siga o que a issue descreve e pergunte ao dono se faltar algo.

## Fluxo de trabalho

- Escolha da skill no começo de cada pedido: seção "Escolha da skill" do [CLAUDE.md](../../CLAUDE.md.exemplo)
- Issue tracker (GitHub, via `gh`): [issue-tracker.md](issue-tracker.md)
- Labels de triagem: [triage-labels.md](triage-labels.md)
- Vocabulário e ADRs: [domain.md](domain.md)
- Coordenação de sessões e worktrees, issue como unidade de trabalho e registro do aprendizado: [coordenacao-de-sessoes.md](coordenacao-de-sessoes.md)
- Retrato do estado real na partida da sessão (hook `SessionStart`), como ler e como desligar: [retrato-da-partida.md](retrato-da-partida.md)
- Skills do Matt Pocock pelo fork em `claude-plugins/` (os fluxos ao alcance do agente, como o dono aplica e desfaz, versão nova do autor): [skills-do-matt-pocock.md](skills-do-matt-pocock.md)

Nesta cópia sanitizada ficaram de fora dois documentos desta seção: a faxina semanal (worktrees, branches, sessões e versões) e as permissões do auto mode (onde vive cada regra, como o dono aplica o modelo e o que o classificador barra). No original, cada um é um item da lista acima, com link.

## Operação

Nesta cópia sanitizada ficaram de fora os treze itens de operação (doze documentos e uma skill do projeto), porque descrevem contas, painéis e ambientes reais. No original, cada um é um item desta seção, no mesmo formato dos de cima: o nome do processo, entre parênteses o que o documento cobre, e o link. Os assuntos: painéis web pelo Chrome da extensão; anúncios (leitura do dia anterior e alteração de campanhas, em duas plataformas); automação e CRM; e-mail marketing; chatbot de mensagens; LMS; SQL de ops e deploy; rastreio de links de venda; tracking do lead; alertas do Teams; e o merge de um site desenhado fora do repositório.

## Como manter este índice

Documento novo entra aqui na mesma PR que o cria, e a linha "pendente (#N)" vira link. Esta seção fica em prosa de propósito: todo item de lista deste arquivo é lido como processo.

O guarda `scripts/agentes/guarda-docs.test.mjs` falha quando um link aponta para arquivo que não existe, quando um item não tem link nem "pendente (#N)", quando o `CLAUDE.md` deixa de apontar para este índice ou passa de 200 linhas. Ele também confere o `.claude/settings.json`: o hook `SessionStart` tem de chamar o script do retrato da partida, e o arquivo não pode carregar chave de permissão. No original, o guarda tem ainda regras que leem o conteúdo de um documento (as contas de anúncio listadas em dois lugares, o modo de permissão em vigor, os hosts da CSP dos Sites), uma exceção à decisão de teste da spec #76 (documento em prosa sem teste de conteúdo): cada uma é dado repetido em dois lugares, e a cópia que diverge faz a sessão agir sobre o dado errado. O fork das skills tem guarda próprio, com as regras em [skills-do-matt-pocock.md](skills-do-matt-pocock.md#guarda). Rodar: `node --test scripts/agentes/*.test.mjs`.
