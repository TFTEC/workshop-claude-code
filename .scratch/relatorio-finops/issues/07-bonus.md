# 07: Regras bônus e custo real (opcional)

**What to build:** O aluno que terminou o núcleo antes da hora acrescenta regras bônus ao relatório FinOps. Quem tem o papel Cost Management Reader também pode trocar o preço de tabela pelo custo real dos últimos 30 dias.

**Blocked by:** 06 (economia estimada e "não sei")

**Status:** ready-for-agent

**Tempo:** 30 min (estimado)

- [ ] **Regras bônus no catálogo**, com rótulo:
  - Load Balancer vazio (sem pools ou sem regras);
  - App Gateway sem configuração (sem listeners, regras ou pools);
  - NIC sem VM, sem as NICs de Private Endpoint e de outros serviços gerenciados;
  - recursos sem as tags de custo (`CostCenter`, `Owner`, `Environment`).
- [ ] A regra de tags **agrupa por tipo de recurso**: um achado por tipo, com a contagem e as tags que faltam, para não inundar o relatório num ambiente grande. As chaves de tag diferenciam maiúsculas de minúsculas.
- [ ] A economia das regras bônus é conservadora: "não sei", com o motivo, quando o medidor não for inequívoco. A NIC não tem custo, e isso vai no motivo, nunca como 0. A regra de tags é informativa.
- [ ] **Custo real (opcional):** com `-CustoReal`, o relatório consulta o Cost Management, com o custo real dos últimos 30 dias agrupado por recurso, e troca a economia pelo custo real dos achados que aparecerem lá. O HTML marca a origem: custo real ou preço de tabela. Sem permissão, ele segue com o preço de tabela ou o "não sei" e avisa uma vez. Sem o switch, nenhuma chamada ao Cost Management acontece.
- [ ] A consulta de custo é o único POST permitido. O hook-freio do exercício 07 deixa passar só esse POST ao Cost Management.
- [ ] O modo anonimizado continua sem vazar nomes, IDs nem IPs, inclusive nos achados novos.
- [ ] Os testes cobrem cada regra bônus, o agrupamento por tipo, o custo real e o caso sem permissão.
