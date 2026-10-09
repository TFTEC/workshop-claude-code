# 05: Modo anonimizado

**What to build:** Com `-Anonimizar`, o aluno mostra o relatório FinOps numa tela compartilhada sem expor o ambiente da empresa: nenhum nome de recurso, de grupo de recursos, ID ou IP aparece em nenhum arquivo de saída.

**Blocked by:** 01 (motor e primeira regra)

**Status:** ready-for-agent

**Tempo:** 25 min (estimado)

- [ ] Cada recurso, grupo de recursos e subscription vira um rótulo estável dentro da execução: o mesmo nome dá sempre o mesmo rótulo. Os recursos usam o rótulo da regra (`disco-01`, `ip-01`; `recurso-01` quando a regra não tem rótulo). Os grupos viram `rg-01` e a subscription vira `sub-01`, também no topo do HTML.
- [ ] Nos detalhes, um valor igual a um nome original vira o rótulo dele. Um valor com cara de ID de recurso do Azure (`/subscriptions/...`), um GUID ou um IP (v4 ou v6) vira `<oculto>`. O ensaio mostrou que o IP público da regra FIN-02 escapava.
- [ ] Os valores em R$ arredondam para a dezena, com **piso de R$ 10** para qualquer valor positivo: nunca aparece 0 para algo que custa. O "não sei" continua "não sei".
- [ ] O HTML mostra um selo visível "Modo anonimizado".
- [ ] Os testes juntam os nomes de todos os dados fictícios, de todas as regras, e confirmam que nenhum aparece em nenhum arquivo da pasta de saída, nem no resumo da tela. Sem `-Anonimizar`, os nomes aparecem.
- [ ] A mudança no motor é localizada: um passo depois de montar os achados e antes de gravar as saídas.
