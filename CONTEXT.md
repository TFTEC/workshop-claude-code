# Relatório FinOps

O projeto da tarde do workshop: um relatório que lê uma subscription Azure, sem alterar nada, e aponta oportunidades de economia de acordo com regras FinOps. Este glossário é o vocabulário que o Claude e os tickets usam.

## Language

### O relatório

**Relatório FinOps**:
O script que lê a subscription-alvo, aplica as regras FinOps e grava a lista de achados e uma página HTML.
_Avoid_: inventário, dashboard, painel

**Subscription-alvo**:
A única subscription Azure que uma execução do relatório lê, passada por parâmetro.
_Avoid_: ambiente, tenant, conta

**Regra FinOps**:
Uma verificação nomeada (FIN-01, FIN-02...) que aponta um tipo de desperdício, como um disco que não está ligado a nenhuma VM.
_Avoid_: política (confunde com Azure Policy), recomendação (confunde com Azure Advisor), check

**Catálogo de regras**:
O conjunto das regras FinOps, um arquivo por regra, com ID, título, severidade, rótulo, KQL e a forma de estimar a economia. Para incluir uma regra, basta um arquivo novo no catálogo, sem mexer no motor.
_Avoid_: lista de regras, configuração

**Achado**:
Um recurso que uma regra FinOps apontou, com a regra, o recurso, o grupo de recursos, a severidade, os detalhes e a economia.
_Avoid_: alerta, finding, problema

**Regra bônus**:
Uma regra FinOps opcional para quem terminar o núcleo antes da hora.
_Avoid_: extra, desafio

### A economia

**Economia estimada**:
Quanto um achado custa por mês, em R$, quando há um preço confiável para ele.
_Avoid_: custo, gasto, desperdício (como número)

**Não sei**:
O valor de economia de um achado sem preço confiável. Sempre vem acompanhado do motivo e nunca é mostrado como 0.
_Avoid_: zero, N/A, indisponível

**Tabela de preços**:
Os preços de varejo dos medidores do Azure. Com a fonte Azure, eles vêm da Retail Prices API, que é pública. Com a fonte Arquivo, vêm de um arquivo no mesmo formato.
_Avoid_: lista de preços, preçário

**Preço de tabela**:
O preço de varejo de um medidor, sem desconto de contrato, reserva ou savings plan.
_Avoid_: preço real, custo

**Custo real**:
O que a subscription de fato pagou por um recurso nos últimos 30 dias, segundo o Cost Management. Exige um papel além do Reader.
_Avoid_: fatura, preço

### Como o relatório lê o Azure

**Fonte**:
De onde vêm os dados de uma execução: `Azure`, que lê a subscription-alvo ao vivo com o Azure CLI, ou `Arquivo`, que lê os dados fictícios.
_Avoid_: modo, origem

**Dados fictícios**:
Arquivos com a resposta que a KQL de cada regra daria, no formato do `az graph query`, com nomes inventados. Servem aos testes e a quem não tem acesso a uma subscription.
_Avoid_: mock, dados de teste, exemplo

### Mostrar o relatório

**Modo anonimizado**:
A execução que troca nomes de recursos, grupos de recursos, IDs e IPs por rótulos e arredonda os valores, para que o relatório possa ir numa tela compartilhada.
_Avoid_: modo demo, modo seguro

**Rótulo**:
O nome estável que substitui um nome real no modo anonimizado, como `disco-01` ou `rg-01`.
_Avoid_: apelido, máscara

### Segurança

**Hook-freio**:
O hook do Claude Code que barra qualquer comando que altere o Azure antes de ele rodar. É a segunda proteção; a primeira é o papel Reader.
_Avoid_: guarda, trava, bloqueio
