# 06: Economia estimada e "não sei"

**What to build:** Cada achado do relatório FinOps traz a economia estimada em R$ por mês ou "não sei", sempre com o motivo, e nunca 0 nem um valor chutado. O topo do HTML mostra o total estimado e, separado, quantos achados ficaram com "não sei".

**Blocked by:** 02 (regras FIN-02 a FIN-04), 03 (regras FIN-05 a FIN-07)

**Status:** ready-for-agent

**Tempo:** 30 min (estimado)

- [ ] A forma de estimar fica no catálogo, por regra:
  - **Advisor (FIN-07):** o valor do próprio Advisor;
  - **Preço de tabela (FIN-01 disco, FIN-02 IP, FIN-04 plano):** o preço da Retail Prices API;
  - **"Não sei" (FIN-03, FIN-05, FIN-06):** com o motivo escrito.
- [ ] O preço de tabela vem da Retail Prices API: GET público, em BRL, com `priceType` `Consumption`, um pedido por medidor e cache dentro da execução. A conversão para R$ por mês é: por hora × 730; por mês, direto; por GB por mês × GB.
- [ ] Quando a API responde **429 (Too Many Requests)**, o relatório espera e tenta de novo, com espera crescente e respeitando o `Retry-After` quando ele vier. Só depois de algumas tentativas ele cai para "não sei" e avisa uma vez na tela. No ensaio, um 429 sem nova tentativa deixou todos os achados com "não sei".
- [ ] Com a fonte `Arquivo`, os preços vêm da tabela de preços fictícia, no mesmo formato da API. Os testes não dependem da rede.
- [ ] **Disco:** o tier sai do SKU e do tamanho, sempre o menor que comporta o disco, com as faixas da documentação oficial. Um disco criado vazio e **nunca anexado** fica com "não sei" e o motivo "o Azure ainda não cobra por ele, porque nunca foi anexado", e não como "medidor ambíguo". Um disco que já foi anexado e foi solto tem preço.
- [ ] O motor normaliza `1`, `0`, `"true"` e `"false"` antes de comparar uma coluna booleana da KQL. Os dados fictícios têm `true`/`false`, mas o Resource Graph de verdade devolveu `1`/`0`. Um teste cobre os dois.
- [ ] **Advisor em outra moeda:** "não sei", mostrando nos detalhes o valor e a moeda informados, sem somar ao total em R$.
- [ ] Medidor ambíguo, mais de um preço, preço zero ou preço em outra moeda também dão "não sei", com o motivo.
- [ ] O HTML tem a coluna "Economia/mês", com "R$ 1.234,56" ou "não sei" e o motivo. A tela e o HTML usam as mesmas frases do resumo.
- [ ] Os testes cobrem a economia com preço, o "não sei" de cada caso, o 429 com nova tentativa (com Mock da chamada HTTP) e o total separado.
