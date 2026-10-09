# 03: Regras FIN-05 a FIN-07 e o limiar do snapshot

**What to build:** O relatório FinOps aponta, com os dados fictícios, três regras novas:
- **FIN-05:** snapshot com mais de N dias, com N vindo do parâmetro `-DiasSnapshot`;
- **FIN-06:** Log Analytics com retenção acima de 90 dias ou sem limite diário;
- **FIN-07:** a economia que o Azure Advisor já recomenda.

**Blocked by:** 01 (motor e primeira regra)

**Status:** ready-for-agent

**Tempo:** 25 min (estimado)

- [ ] Cada regra é um arquivo novo no catálogo, com título reescrito em português, severidade e rótulo (`snapshot`, `workspace`, `recomendacao`).
- [ ] O `-DiasSnapshot` aceita de 1 a 3650, com padrão 30, e recusa 0 ou negativo sem gravar nada. O valor entra na KQL e no título de FIN-05 por um marcador que o motor preenche. O motor não conhece a regra pelo nome.
- [ ] O HTML mostra a KQL de cada regra. Com `-DiasSnapshot 45`, a KQL de FIN-05 mostra `ago(45d)` e o título acompanha.
- [ ] A KQL de FIN-06 aponta a retenção acima de 90 dias e também o limite diário ausente (`-1` ou vazio).
- [ ] A KQL de FIN-07 lê as recomendações de custo do Advisor. Ela projeta como `name` o recurso afetado e guarda a economia e a moeda que o Advisor informa, para o ticket 06.
- [ ] As KQL não têm comentário `//`, usam aspas simples e calculam com `tobool(...)` toda coluna booleana (por exemplo, se o snapshot é incremental).
- [ ] Os testes cobrem cada regra, a resposta vazia e o `-DiasSnapshot` refletido no HTML.
