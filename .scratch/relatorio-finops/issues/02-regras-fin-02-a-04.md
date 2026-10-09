# 02: Regras FIN-02 a FIN-04

**What to build:** O relatório FinOps aponta, com os dados fictícios, três regras novas, sem nenhuma mudança no motor:
- **FIN-02:** IP público que não está ligado a nada;
- **FIN-03:** VM desligada que continua pagando pelos discos;
- **FIN-04:** plano do App Service pago e sem nenhum app.

**Blocked by:** 01 (motor e primeira regra)

**Status:** ready-for-agent

**Tempo:** 25 min (estimado)

- [ ] Cada regra é um arquivo novo no catálogo, com título reescrito em português, severidade e rótulo (`ip`, `vm`, `plano`).
- [ ] A KQL de FIN-02 tira os IPs de NAT Gateway, que estão em uso.
- [ ] A KQL de FIN-03 junta a VM desalocada ou parada com os discos dela (quantidade e GB).
- [ ] A KQL de FIN-04 tira as camadas sem custo fixo: Free, Shared e as de consumo das Functions.
- [ ] As KQL projetam `name`, `resourceGroup`, `subscriptionId` e `location`, não têm comentário `//` e usam aspas simples.
- [ ] Toda coluna que a regra vai usar como booleano é calculada com `tobool(...)`. No ensaio, o Resource Graph devolveu como `1` ou `0` uma expressão booleana calculada sem `tobool`.
- [ ] As colunas que o ticket 06 vai usar para achar o preço já estão na KQL: em FIN-02, a camada e a versão do IP; em FIN-04, o sistema operacional e o número de instâncias.
- [ ] Os testes cobrem cada regra com os dados fictícios e com a resposta vazia.
