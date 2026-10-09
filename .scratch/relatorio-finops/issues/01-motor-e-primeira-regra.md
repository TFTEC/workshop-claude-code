# 01: Motor do relatório e a primeira regra (FIN-01)

**What to build:** Com a fonte `Arquivo`, o relatório FinOps lê os dados fictícios da regra FIN-01 (disco que não está ligado a nenhuma VM) e grava `achados.json` e um `relatorio-finops.html` que abre no navegador. É o primeiro tracer bullet: as regras ficam num catálogo, um arquivo por regra, e o motor não conhece nenhuma regra pelo nome. Para incluir uma regra nova, basta um arquivo novo.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

**Tempo:** 30 min (estimado)

- [ ] O ponto de entrada aceita `-SubscriptionId`, `-Fonte` (`Arquivo` ou `Azure`), `-PastaDados` e `-Saida`, com os nomes e os padrões do contrato da spec. Com a fonte `Azure`, por enquanto, o script para com uma mensagem clara de "ainda não implementado" e não grava nada.
- [ ] Ele lê o catálogo de regras, um arquivo por regra, com ID, título, severidade, rótulo, KQL e economia, e roda só a FIN-01 neste ticket.
- [ ] Com a fonte `Arquivo`, ele lê o JSON da regra no formato do `az graph query` (`count`, `data`, `skip_token`, `total_records`).
- [ ] Cada achado traz regra, título, severidade, recurso, grupo de recursos, subscription, local e detalhes. Os detalhes são as outras colunas da KQL.
- [ ] Ele grava `achados.json` e um `relatorio-finops.html` autocontido, sem CDN e sem nada de fora, em português, com o resumo por regra e os achados agrupados. Os valores são escapados, para que nenhum nome vire código na página.
- [ ] A resposta vazia, que fica nos dados fictícios sem achados, gera `[]` e "Nenhum achado".
- [ ] Se faltar o JSON de uma regra, o script para e diz qual arquivo falta. Ele não conclui "sem desperdício".
- [ ] Os testes Pester 5 passam pelo ponto de entrada público, sem testar função interna.
- [ ] Os scripts ficam em UTF-8 com BOM e rodam no PowerShell 7.
