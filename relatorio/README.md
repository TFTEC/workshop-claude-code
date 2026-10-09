# Relatório FinOps

Lê uma subscription Azure **só com leitura** e aponta desperdício segundo as regras FinOps. Cada regra vira uma lista de achados, e o relatório sai num HTML que abre direto no navegador.

## Como rodar

Na raiz do repositório, com PowerShell 7 (`pwsh`):

```powershell
./relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Fonte Arquivo
```

Depois, abra `saida/relatorio-finops.html` no navegador.

Para rodar os testes, use Pester 5:

```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path testes/relatorio.Tests.ps1 -Output Detailed"
```

Os ajudantes comuns dos testes (rodar o relatório, ler o `achados.json` e o HTML, copiar os dados fictícios) ficam em `testes/Comum.ps1`, que cada arquivo de teste carrega por dot-source no `BeforeAll`.

## Parâmetros

| Parâmetro | Obrigatório | O que é |
|---|---|---|
| `-SubscriptionId` | Sim | A subscription-alvo. Aparece no topo do HTML. |
| `-Fonte` | Sim | De onde vêm os dados: `Arquivo` (JSON salvo) ou `Azure` (leitura ao vivo com o Azure CLI; ver [Fonte Azure](#fonte-azure)). |
| `-PastaDados` | Não | Com a fonte `Arquivo`, a pasta com um JSON por regra e a tabela de preços `precos.json`. Padrão: `testes/dados`, que tem os dados e os preços fictícios. |
| `-Saida` | Não | A pasta onde ficam `achados.json` e `relatorio-finops.html`. É criada se não existir. Padrão: `saida`, que já está no `.gitignore`. |
| `-TabelaDePrecos` | Não | Um JSON com os preços, no formato da resposta da Retail Prices API. Vale para as duas fontes e substitui tanto o `precos.json` da pasta de dados quanto a API. Ver [Economia e "não sei"](#economia-e-não-sei). |
| `-CustoReal` | Não | Liga o custo real dos últimos 30 dias por recurso, do Cost Management. Ver [Custo real (opcional)](#custo-real-opcional). |

## O que sai

- **`achados.json`**: a lista de achados. Cada achado traz `Regra`, `Titulo`, `Severidade`, `Recurso`, `GrupoDeRecursos`, `Subscription`, `Local`, `IdDoRecurso` (o ID do recurso no Azure, a coluna `id` da KQL), `Economia` (R$ por mês, ou `null`), `EconomiaStatus` (`estimada` ou `nao-sei`), `EconomiaMotivo` (por que ficou "não sei"), `EconomiaOrigem` (de onde veio o valor: `preco-de-tabela`, `advisor` ou `custo-real`; `null` no "não sei") e `Detalhes`, que guarda as outras colunas da KQL, como o SKU e o tamanho do disco.
- **`relatorio-finops.html`**: um arquivo só, sem CDN e sem nada de fora. Mostra no topo a economia estimada por mês e, à parte, quantos achados ficaram com "não sei"; depois, o resumo por regra e os achados agrupados por regra, com a severidade destacada e a coluna "Economia/mês". Embaixo de cada valor, a origem dele: "preço de tabela", "Advisor" ou "custo real, últimos 30 dias". Os valores são escapados, para que nenhum nome vire código na página.

## Regras

O catálogo tem 11 regras, um arquivo por regra em `relatorio/regras/`: as 7 do núcleo e 4 bônus (`FIN-08` a `FIN-11`), para quem terminar o núcleo antes da hora.

| Regra | O que procura | Severidade | Rótulo | Economia | Com `-CustoReal` |
|---|---|---|---|---|---|
| `FIN-01` | Disco que não está ligado a nenhuma VM | Alta | `disco` | Preço de tabela do tier do disco | Custo real |
| `FIN-02` | IP público que não está ligado a nada. O IP de NAT Gateway fica de fora, porque está em uso. | Média | `ip` | Preço de tabela do IP estático regional | Custo real |
| `FIN-03` | VM desligada que continua pagando pelos discos | Média | `vm` | "Não sei" | Fica como está |
| `FIN-04` | Plano do App Service pago e sem nenhum app. Ficam de fora as camadas sem custo fixo: Free, Shared e as de consumo. | Alta | `plano` | Preço de tabela da instância x instâncias | Custo real |
| `FIN-05` | Snapshot com mais de 30 dias. O limiar vem de `-DiasSnapshot`. | Baixa | `snapshot` | "Não sei" | Custo real |
| `FIN-06` | Log Analytics guardando dados por mais de 90 dias ou sem limite diário | Média | `workspace` | "Não sei" | Fica como está |
| `FIN-07` | Economia que o Azure Advisor já recomenda. A economia que o Advisor informa fica nas colunas `economiaAdvisor` e `moeda`. | Média | `recomendacao` | O valor do próprio Advisor, em BRL. Em outra moeda, "não sei", com o valor e a moeda no motivo | Fica como está |
| `FIN-08` (bônus) | Load Balancer sem pool de back-end ou sem regras. As regras somam as de balanceamento, as de NAT de entrada e as de saída: um Load Balancer só com regra de saída está em uso. | Média | `lb` | "Não sei": o Standard cobra pelas regras e pelos dados processados, e não por existir | Custo real |
| `FIN-09` (bônus) | Application Gateway sem listener, sem regra ou sem pool de back-end. A coluna `estado` mostra se ele está parado (e aí não cobra). | Alta | `appgw` | "Não sei": a cobrança depende da camada (v1 ou v2), das unidades de capacidade e do mínimo de instâncias | Custo real |
| `FIN-10` (bônus) | NIC que não está ligada a nenhuma VM. Ficam de fora as NICs em uso por outro serviço: de Private Endpoint, de Private Link Service, de BareMetal (`hostedWorkloads`, `workloadType`) e as gerenciadas por outro recurso (`managedBy`). | Baixa | `nic` | "Não sei": a NIC não é cobrada. A coluna `temIpPublico` diz se ela segura um IP público, que cobra à parte e não aparece em `FIN-02`. | Fica como está |
| `FIN-11` (bônus) | Recursos sem as tags de custo `CostCenter`, `Owner` e `Environment`, **um achado por tipo de recurso** (ver abaixo) | Baixa | `tipo` | "Não sei": tag faltando não é desperdício por si só | Fica como está |

O `Rotulo` é o prefixo do nome do recurso no modo anonimizado: `disco-01`, `ip-01`... Em `FIN-11`, o "recurso" do achado é o tipo, que vira `tipo-01`.

As 11 KQL rodaram sem erro contra o Azure real no ensaio de 09/10, num lab com um recurso por regra do núcleo; as bônus foram validadas na sintaxe. Os filtros que o lab não exercita, como a exclusão dos IPs de NAT Gateway e das NICs de outros serviços, seguem sem validação com dado real. Em `FIN-08` e `FIN-09`, o pool que existe mas ficou vazio (a VM foi apagada) não entra: contar os membros de cada pool fica para depois.

**Booleano na KQL:** uma coluna booleana calculada na KQL (`nuncaAnexado`, `temIpPublico`) leva `tobool(...)`, para deixar claro o tipo (o `tobool` entrou depois do ensaio e ainda não rodou no Azure real). Mesmo assim, o Resource Graph pode devolvê-la como `1` ou `0`, e não como `true` ou `false` (foi o que aconteceu no ensaio). Por isso, quando o catálogo compara uma coluna com `$true` ou `$false` (em `SoQuando`), o script aceita `$true`/`$false`, `1`/`0`, `"1"`/`"0"` e `"true"`/`"false"`, sem diferenciar maiúsculas.

### Decisão: as tags de custo (`FIN-11`)

- **Um achado por tipo de recurso, e não por recurso.** Num ambiente grande, quase todo recurso fica sem alguma tag, e um achado por recurso inundaria o relatório. A KQL agrupa por tipo e devolve, em cada linha, quantos recursos do tipo têm problema (`recursos`), quantos estão sem cada tag (`semCostCenter`, `semOwner`, `semEnvironment`), quais tags faltam em pelo menos um deles (`tagsQueFaltam`) e quantos têm alguma tag com outra grafia (`outraGrafia`). O achado não tem grupo de recursos nem ID: ele vale para a subscription toda.
- **Maiúsculas e minúsculas na chave.** Para as operações do Azure, a chave da tag não diferencia maiúsculas: `costcenter` é a mesma tag que `CostCenter`. Mas o Azure guarda a grafia de cada recurso, e é ela que aparece no relatório de custo. Na KQL, `tags['CostCenter']` diferencia maiúsculas e não acharia `costcenter`. Por isso a regra junta as chaves do recurso num texto e compara de dois jeitos: com `contains`, que não diferencia, para saber se a tag existe com qualquer grafia (sem ela, o recurso conta como sem a tag); e com `contains_cs`, que diferencia, para separar a tag escrita com outra grafia. Essa tag não conta como falta, mas aparece em `outraGrafia`, porque divide o relatório de custo em duas.

### O limiar do snapshot: `-DiasSnapshot`

| Parâmetro | Obrigatório | O que é |
|---|---|---|
| `-DiasSnapshot` | Não | A idade, em dias, a partir da qual um snapshot vira achado em `FIN-05`. Aceita de 1 a 3650. Padrão: 30. |

```powershell
./relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Fonte Arquivo -DiasSnapshot 45
```

O número entra na regra por um marcador. A KQL de `FIN-05` traz `ago({{DiasSnapshot}}d)`, e o título traz `{{DiasSnapshot}}`. Ao ler o catálogo, o script troca cada `{{Nome}}` pelo valor do parâmetro de mesmo nome. Com `-DiasSnapshot 45`, a KQL mostrada no HTML fica `ago(45d)` e o título vira "Snapshot com mais de 45 dias". Para outra regra ganhar um número ajustável, crie o parâmetro no script e acrescente-o em `$ParametrosDasRegras`.

Os testes das regras do núcleo ficam em `testes/relatorio.regras.Tests.ps1`; os das regras bônus e do custo real, em `testes/relatorio.bonus.Tests.ps1`.

## Economia e "não sei"

**Regra de ouro:** quando não há preço confiável, o achado mostra "não sei", nunca 0 nem um valor chutado. O topo do HTML separa a economia estimada (a soma dos achados com preço) da contagem de achados com "não sei", e a tela repete as duas frases.

O campo `Economia` de cada regra diz como estimar, de uma de três formas:

- **`'advisor'`** (`FIN-07`): usa o valor que o próprio Advisor informa, na coluna `Coluna`, e só quando a coluna `ColunaDaMoeda` diz `BRL`. O relatório não converte moeda: em outra moeda, o achado fica com "não sei", e o motivo mostra o valor e a moeda informados (por exemplo, "USD 12,34 informados pelo Advisor por mês, em outra moeda"), sem somar ao total em R$. Sem a moeda, o motivo diz que o Advisor não a informou.
- **`'preco-de-tabela'`** (`FIN-01`, `FIN-02`, `FIN-04`): monta o medidor da Retail Prices API com as colunas do achado e converte o preço para R$ por mês: por hora, x 730; `1/Month`, direto; por GB por mês, x a coluna de `Quantidade`. `Quantidade` também multiplica as instâncias do plano. `SoQuando` diz quais valores de coluna a regra sabe precificar, e `DePara` troca o valor de uma coluna por um pedaço do nome do medidor, por tabela (`Valores`) ou por faixas de número (`Faixas`). `MotivoSeNao` (opcional) dá, para uma coluna do `SoQuando`, o motivo verdadeiro do "não sei" quando ela traz um valor legível que a regra não precifica: em `FIN-01`, o disco nunca anexado, que o Azure ainda não cobra. Sem ele, o motivo é "Medidor ambíguo".
- **`'nao-sei'`** (`FIN-03`, `FIN-05`, `FIN-06`): a regra não tem preço confiável, e `Motivo` diz por quê. A forma curta `Economia = 'nao-sei'` também vale.

O achado fica com "não sei", e o motivo aparece embaixo, quando: uma coluna de `SoQuando` ou de `DePara` vem com um valor fora da lista ou vazia (medidor ambíguo, ou o `MotivoSeNao` da coluna); a tabela não tem o medidor; tem mais de um preço para ele, preço em faixas de consumo, preço zero ou em outra moeda; ou a unidade não é por hora, por mês ou por GB por mês. Um erro de digitação no campo `Economia` (uma forma que não existe, `preco-de-tabela` sem `Medidor`, um `MotivoSeNao` de coluna que não está no `SoQuando`) faz o relatório parar e dizer qual regra corrigir.

**De onde vêm os preços:**

| Situação | Preços |
|---|---|
| `-TabelaDePrecos <arquivo>` | O arquivo, com qualquer fonte. É o ponto de injeção dos testes. |
| Fonte `Arquivo` | `precos.json` da pasta de dados. O de `testes/dados/` é fictício, com valores redondos. Sem esse arquivo, os achados de preço de tabela ficam com "não sei" e a tela avisa. |
| Fonte `Azure` | A Retail Prices API (`https://prices.azure.com/api/retail/prices`), pública e sem login: só GET, em BRL, com `priceType eq 'Consumption'`, juntando as páginas pelo `NextPageLink`. Cada medidor é pedido uma vez por execução. Se a API recusar por excesso de pedidos (429), o script tenta de novo (ver abaixo). Se ela falhar, os achados ficam com "não sei" e a tela avisa. |

O preço é de tabela: sem desconto de contrato, reserva ou savings plan.

**429 (Too Many Requests):** a Retail Prices API e o Cost Management limitam quantos pedidos aceitam por minuto; no ensaio de 09/10, os dois responderam 429, e a API pediu `Retry-After: 60`. O script faz no máximo **3 tentativas** por pedido. Entre elas, espera o que o cabeçalho `Retry-After` pede, até 60 s; sem ele (o `az rest` do custo real não o mostra), a espera cresce: 5 s e depois 10 s. A tela avisa cada espera. Se a Retail Prices API recusar as 3, o relatório não pede mais nenhum preço naquela execução, e os achados de preço de tabela ficam com "não sei"; se o Cost Management recusar as 3, o relatório segue sem o custo real e avisa. Nos testes, a espera não dorme: um Mock de `Start-Sleep` só confere quanto o script pediu para esperar.

**Decisões e limites, a validar no ensaio:**

- **Disco (`FIN-01`):** o Azure cobra pelo menor tier que comporta o tamanho (200 GB de Premium SSD é P15). As faixas vêm da documentação oficial dos tipos de disco: P e E de 1 a 80, a partir de 4 GB; o HDD começa no S4 (32 GB), então um HDD de até 16 GB cai num S1 a S3 que não existe e fica "não sei". Premium SSD v2 e Ultra (cobrados por GB, IOPS e vazão) ficam "não sei". O disco criado vazio e nunca anexado não é cobrado, segundo a página de preços dos discos; a KQL marca esse caso em `nuncaAnexado`, e ele fica "não sei", com o motivo de que o disco nunca foi anexado e por isso ainda não cobra (o `MotivoSeNao` da regra). Se alguém trocou a camada de desempenho (performance tier) de um Premium SSD, a cobrança é pela camada escolhida, e a estimativa sai menor que a real.
- **IP (`FIN-02`):** só o IP estático da camada Regional. O IP Global tem outro medidor, e o IP dinâmico sem associação pode nem estar cobrando.
- **App Service Plan (`FIN-04`):** só Basic, Standard, Premium v2 e Premium v3, em Windows ou Linux. Isolated, Elastic Premium e contêiner Windows ficam "não sei". O filtro não leva o `meterName`, porque o nome do medidor muda de um produto para outro (ver abaixo): o produto, o SKU e a região já apontam um preço de consumo só, e, se a API trouxer mais de um, o achado fica com "não sei".
- **Snapshot (`FIN-05`): "não sei", até o completo.** A página de preços dos discos diz que o snapshot completo é cobrado pelo espaço usado do disco, e o incremental, pelo que mudou. O Resource Graph não informa esse espaço; o `tamanhoGB` é o tamanho do disco de origem, e multiplicar por ele inflaria a economia.
- **Advisor (`FIN-07`):** falta confirmar no ensaio se o `savingsAmount` é mensal; o relatório trata como mensal.

**O que foi conferido na Retail Prices API real** (duas consultas GET em BRL, em `brazilsouth`, em 08/10/2026): o disco tem `serviceName` `Storage`, `productName` `Premium SSD Managed Disks`, `Standard SSD Managed Disks` ou `Standard HDD Managed Disks`, `skuName` como `P10 LRS` e `meterName` como `P10 LRS Disk`, em `1/Month`. O mesmo `P10 LRS Disk` aparece também em `Premium Page Blob`, e há os medidores `Disk Mount` e `Disk Operations`: por isso o filtro leva `productName` e `meterName`. O IP tem `serviceName` `Virtual Network`, `productName` `IP Addresses`, `skuName` `Standard`, `Basic` ou `Global` e `meterName` como `Standard IPv4 Static Public IP`, em `1 Hour`. O App Service tem `productName` como `Azure App Service Premium v3 Plan` e `Azure App Service Premium v3 Plan - Linux`, `skuName` `P1 v3` (com espaço) e `meterName` `P1 v3 App`, em `1 Hour`. Na resposta, o tipo de preço vem no campo `type`; no filtro, ele se chama `priceType`.

Em 09/10, depois do ensaio no lab, mais consultas GET em BRL conferiram os medidores do lab:

- **Disco Standard HDD de 32 GB em `eastus`:** `productName` `Standard HDD Managed Disks`, `skuName` `S4 LRS`, `meterName` `S4 LRS Disk`, em `1/Month`, como a regra monta.
- **IP público Standard estático IPv4 em `eastus`:** `productName` `IP Addresses`, `skuName` `Standard`, `meterName` `Standard IPv4 Static Public IP`, em `1 Hour`, como a regra monta.
- **Plano B1 Linux em `westus2`:** `productName` `Azure App Service Basic Plan - Linux`, `skuName` `B1` e `meterName` **`B1`**, sem o " App", em `1 Hour`. É o único produto do App Service em que o medidor é só o SKU: no Basic Windows ele é `B1 App`, e no Standard, no Premium v2 e no Premium v3, em Windows ou Linux, também termina em " App" (conferido em `westus2`; o Basic Linux, em todas as regiões). Por isso o filtro de `FIN-04` deixou o `meterName` de fora.
- **P0v3:** a API escreve `skuName` `P0v3` e `meterName` `P0v3 App`, sem espaço, ao contrário do `P1 v3`. O de-para de `FIN-04` foi corrigido.

Os testes ficam em `testes/relatorio.economia.Tests.ps1`. Os da Retail Prices API de verdade (a fonte `Azure` sem `-TabelaDePrecos`) ficam em `testes/relatorio.azure.Tests.ps1`, com um Mock de `Invoke-RestMethod` no lugar da API.

## Custo real (opcional)

Com `-CustoReal`, o relatório lê o que cada recurso custou de verdade nos últimos 30 dias e usa esse valor no lugar do preço de tabela ou do "não sei":

```powershell
./relatorio/Invoke-RelatorioFinOps.ps1 -Fonte Azure -SubscriptionId <id-da-subscription> -CustoReal
```

- **De onde vem:** com a fonte `Azure`, da consulta de custo do Cost Management: `az rest --method post --url https://management.azure.com/subscriptions/<id>/providers/Microsoft.CostManagement/query?api-version=2025-03-01 --body @<arquivo>`. É um POST, mas só lê, e o hook-freio deixa passar exatamente essa consulta. O corpo pede o custo real (`ActualCost`), de `Custom` com os 30 dias completos antes de hoje (UTC), somado (`PreTaxCost`, `Sum`) e agrupado por `ResourceId`, com `granularity` `None`. Ele vai num arquivo temporário, porque, no Windows, o `cmd.exe` do `az.cmd` estraga as aspas de um JSON passado direto. Quando o resultado não cabe numa página, o script pede a seguinte com o mesmo POST e o skip token do `nextLink` em `--url-parameters`. Com a fonte `Arquivo`, vem de `<PastaDados>/custo-real.json`, no formato da resposta dessa consulta (`properties.columns` e `properties.rows`); o de `testes/dados/` é fictício.
- **Como casa com o achado:** pelo ID do recurso. Toda regra com um recurso por linha projeta `id` na KQL, que vira `IdDoRecurso`. O Cost Management devolve o ID em minúsculas, e por isso a comparação não diferencia maiúsculas.
- **Onde vale:** só nas regras em que o custo do recurso é o próprio desperdício, marcadas com `CustoReal = $true` no campo `Economia`: `FIN-01`, `FIN-02`, `FIN-04`, `FIN-05`, `FIN-08` e `FIN-09`. Nas outras, o achado fica como está: em `FIN-03`, os discos da VM são recursos à parte, e a VM desalocada quase não custa; em `FIN-06`, o custo do workspace não é o que se economiza mudando a retenção; em `FIN-07`, o Advisor já diz qual parte do custo dá para economizar; a NIC (`FIN-10`) não é cobrada; e `FIN-11` agrupa por tipo, sem ID.
- **Origem marcada:** o achado com custo real fica com `EconomiaOrigem` `custo-real`, e o HTML mostra "custo real, últimos 30 dias" embaixo do valor, contra "preço de tabela" ou "Advisor" nos outros. O topo do HTML diz de onde veio o custo real, e a tela, quantos achados o usaram.
- **Nunca 0:** recurso que não aparece no Cost Management, ou que aparece com custo 0, fica com o que tinha (preço de tabela ou "não sei"). Custo em outra moeda também, com um aviso: o relatório não converte moeda.
- **Sem permissão:** ler custo pede o papel **Cost Management Reader** (Leitor de Gerenciamento de Custos), além do Reader. Sem ele (erro 401, 403 ou `AuthorizationFailed`), ou com qualquer outra falha da consulta, o relatório segue com o preço de tabela ou "não sei" e avisa uma vez, na tela e no topo do HTML, que o custo real não foi lido. O aviso não leva ID, caminho do Azure nem e-mail, para valer também no modo anonimizado.
- **429 (Too Many Requests):** o Cost Management também limita os pedidos. O script tenta de novo, com a mesma política da Retail Prices API (ver [Economia e "não sei"](#economia-e-não-sei)): 3 tentativas, com 5 s e 10 s de espera. Se as 3 derem 429, o aviso diz isso.
- **Sem `-CustoReal`:** nenhuma consulta de custo é feita, e nenhum achado usa o custo real.

A conferir no ensaio: a `api-version` (a referência oficial lista a 2025-03-01 e versões mais novas), o nome da coluna de custo (`PreTaxCost`; o script também aceita `Cost`), a dimensão `ResourceId` e o skip token em `--url-parameters`.

## Fonte Azure

Lê a subscription ao vivo, só com leitura. Para cada regra, o script roda a KQL com `az graph query`, com escopo na subscription passada e 1.000 linhas por página, e junta as páginas pelo skip token. O motor recebe as linhas no mesmo formato da fonte `Arquivo`.

**Pré-requisitos:** o Azure CLI, a extensão `resource-graph`, o `az login` feito e o papel Reader (Leitor) na subscription.

```powershell
./relatorio/Invoke-RelatorioFinOps.ps1 -Fonte Azure -SubscriptionId <id-da-subscription>
```

O script só roda `az extension show`, `az account show` e `az graph query` e, só com `-CustoReal`, o POST da consulta de custo (ver [Custo real (opcional)](#custo-real-opcional)). Os preços não passam pelo `az`: vêm de GET direto na Retail Prices API, pública. Antes da primeira regra, ele confere o que costuma faltar e, se faltar algo, para com uma destas mensagens:

| A mensagem começa com | O que fazer |
|---|---|
| Não achei o Azure CLI | Instale o Azure CLI (https://aka.ms/installazurecli) e abra um terminal novo. |
| Falta a extensão resource-graph | Rode `az extension add --name resource-graph` no seu terminal. |
| O Azure CLI não está logado | Rode `az login`. |
| Não achei a subscription | Confira o ID com `az account list -o table` e se a sua conta tem o papel Reader nessa subscription. Se o acesso é recente, rode `az login` de novo. |
| A consulta da regra FIN-xx falhou | A mensagem traz o motivo que o Azure deu. Se for permissão (`AuthorizationFailed`), confira o papel Reader. Se for a KQL, teste-a no Resource Graph Explorer do portal. |
| A regra FIN-xx recebeu só N de M linhas | A KQL usa `limit`, `take` ou `sample`, e aí o Azure não pagina. Tire-os da KQL. |

Na KQL das regras, não use comentário `//` e use aspas simples nas strings. O script manda a KQL numa linha só, porque, no Windows, o `az` é um `az.cmd`, e o `cmd.exe` corta o argumento na primeira quebra de linha.

Os testes da fonte Azure ficam em `testes/relatorio.azure.Tests.ps1` (e os do custo real, em `testes/relatorio.bonus.Tests.ps1`) e não usam o Azure. Eles põem na frente do PATH um az falso (`testes/az-falso/az.ps1`), com respostas enlatadas, e conferem que o script só chamou comandos de leitura. O az falso só aceita, além dos três comandos de leitura, o POST na consulta de custo do Cost Management; qualquer outro `az rest` falha. Os preços vêm da tabela fictícia, por `-TabelaDePrecos`; o teste da Retail Prices API usa um Mock de `Invoke-RestMethod`, que também sabe responder 429. Os cenários `custo-429-uma-vez` e `custo-429-sempre` do az falso respondem 429 à consulta de custo. As respostas enlatadas de `testes/az-falso/` repetem as linhas de `testes/dados/`, porque um teste compara o `achados.json` das duas fontes: ao mudar uma, mude a outra. Em `FIN-01`, as duas trazem `nuncaAnexado` como `0` em dois discos e como `false` no outro, porque o Resource Graph devolveu o booleano como número no ensaio.

## Como acrescentar uma regra

Para incluir uma regra, basta acrescentar arquivos. O script não muda.

1. Copie `relatorio/regras/FIN-01.psd1` para `relatorio/regras/FIN-xx.psd1` e troque `Id`, `Titulo`, `Severidade` (`Alta`, `Média` ou `Baixa`), `Rotulo` (o prefixo do recurso no modo anonimizado, como `disco`), `Kql` e `Economia`.
2. Escolha a forma da `Economia` (ver [Economia e "não sei"](#economia-e-não-sei)). Na dúvida, use `@{ Forma = 'nao-sei'; Motivo = '...' }`: é melhor "não sei" que um valor chutado. Com `'preco-de-tabela'`, confira na Retail Prices API os nomes exatos do medidor (`productName`, `skuName`, `meterName`), projete na KQL as colunas que escolhem o medidor (SKU, sistema, camada) e ponha em `SoQuando` ou `DePara` só os valores que você sabe precificar. Se um valor de `SoQuando` que fica de fora tem um motivo conhecido, escreva-o em `MotivoSeNao`. Com `'advisor'`, diga a coluna do valor e a da moeda.
3. Faça a KQL projetar `id`, `name`, `resourceGroup`, `subscriptionId` e, se existir, `location`. Uma coluna booleana calculada na KQL leva `tobool(...)`. O `id` é o que casa o achado com o custo real; se o custo do recurso é o próprio desperdício, acrescente `CustoReal = $true` no campo `Economia` (ver [Custo real (opcional)](#custo-real-opcional)). As outras colunas viram `Detalhes`, então dê a elas nomes curtos em português, como `tamanhoGB`.
4. Crie `testes/dados/FIN-xx.json` com a resposta que o Azure daria à KQL, no formato de `az graph query -o json`: `count`, `data` (uma linha por recurso, com as colunas do `project`), `skip_token` e `total_records`. Com `'preco-de-tabela'`, acrescente em `testes/dados/precos.json` os itens fictícios do medidor e confira a conta num teste de `testes/relatorio.economia.Tests.ps1`.
5. Crie `testes/dados-sem-achados/FIN-xx.json` com a resposta vazia: `count` 0 e `data` vazio.
6. Acrescente a regra na tabela `$regrasDoNucleo` de `testes/relatorio.regras.Tests.ps1` (ou, se for bônus, em `$regrasBonus` de `testes/relatorio.bonus.Tests.ps1`), com o título, a severidade e os recursos que o JSON fictício traz. Copie o JSON também para `testes/az-falso/paginado/`, que precisa repetir `testes/dados/`.

Se faltar o JSON de alguma regra, o script para e diz qual arquivo falta. Ele nunca conclui que "não há desperdício" só porque não achou os dados.

## Decisão: o caso "não dispara" com a fonte `Arquivo`

No Azure, quem escolhe os recursos é a KQL. A KQL de `FIN-01`, por exemplo, só devolve os discos com `diskState` igual a `Unattached`. Por isso, o JSON fictício é **a resposta da KQL**, e não o inventário inteiro da subscription. O script não refaz o filtro, então a regra fica num lugar só: a KQL.

Daí sai a forma de testar os dois casos:

- **Dispara:** `testes/dados/FIN-01.json` traz três discos soltos, e cada um vira um achado.
- **Não dispara:** `testes/dados-sem-achados/FIN-01.json` é a resposta vazia, que é o que o Azure devolve quando todos os discos estão anexados a uma VM. Nesse caso, o relatório grava `achados.json` como `[]` e o HTML mostra a regra com "Nenhum achado".

Com isso, os testes automáticos não validam o filtro da KQL. Ele só é validado no ensaio, contra uma subscription real.

## Modo anonimizado

Para mostrar o relatório numa tela compartilhada, acrescente `-Anonimizar`:

```powershell
./relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Fonte Arquivo -Anonimizar
```

- **Rótulos estáveis dentro da execução:** o mesmo nome original sempre vira o mesmo rótulo. Os recursos usam o prefixo do campo `Rotulo` da regra (`disco-01`, `disco-02`), ou `recurso` quando a regra não tem esse campo. Os grupos de recursos viram `rg-01`, `rg-02`. As subscriptions viram `sub-01` e seguintes, a começar pela do `-SubscriptionId`, que é a que aparece no topo do HTML.
- **ID do recurso:** o `IdDoRecurso` leva a subscription, o grupo e o nome, e vira `<oculto>` inteiro. O custo real casa com o achado antes do mascaramento.
- **Detalhes:** um valor igual a um nome original vira o rótulo desse nome. Um valor com um nome original no meio, com cara de ID do Azure (`/subscriptions/...`, `/providers/...`), com um GUID ou com um endereço IP, IPv4 ou IPv6 (o IP público de `FIN-02`, o IP privado de `FIN-10`), vira `<oculto>`.
- **Valores em reais:** são arredondados para a dezena mais próxima (123,45 vira 120; 125 vira 130), com piso de 10 para valor positivo (3,20 vira 10), para o relatório nunca mostrar 0 para algo que custa. "Não sei" continua "não sei", e o total do topo soma os valores já arredondados. O valor que o Advisor informou em outra moeda, mostrado no motivo do "não sei", também vai para a dezena. O script reconhece um valor em reais pelo nome: um número cuja coluna tem `economia`, `custo`, `preco` ou `valor` no nome.
- **Selo:** o HTML mostra o selo "Modo anonimizado", e o resumo na tela também avisa.

O mascaramento roda depois de montar os achados e antes de gravar qualquer arquivo, então nem `achados.json`, nem o HTML, nem o resumo na tela levam um nome original. Os testes ficam em `testes/relatorio.anonimizado.Tests.ps1`, com os dados de `testes/dados-anonimizado/`.

Cuidado ao escrever a KQL: o script só sabe que um texto é nome quando ele veio em `name`, `resourceGroup` ou `subscriptionId`. Se a regra precisar citar outro recurso nos detalhes, projete o ID completo, que vira `<oculto>`, e não só o nome.

## PowerShell 5.1

O script foi rodado à mão no Windows PowerShell 5.1 com a fonte `Arquivo` e funcionou: deu os mesmos achados, com as duas diferenças de aparência listadas abaixo. Com `-CustoReal`, também rodou no 5.1, com a fonte `Arquivo` e com a fonte `Azure` pelo az falso, e deu os mesmos achados do PowerShell 7. Os testes Pester exigem o PowerShell 7. Para continuar rodando no 5.1, siga estes cuidados:

- **Salve `.ps1` e `.psd1` com acento em UTF-8 com BOM.** Sem BOM, o 5.1 lê o arquivo como ANSI, os acentos saem errados e o script pode nem abrir.
- **No 5.1, `$PSScriptRoot` chega vazio dentro do `param()`.** Por isso, o padrão de `-PastaDados` é calculado no corpo do script.
- **No 5.1, o HTTPS pode não ligar o TLS 1.2 sozinho.** Antes de chamar a Retail Prices API, o script liga.
- **O valor em reais é formatado à mão** (`R$ 1.234,56`), sem depender da cultura da máquina.
- **Não use recursos que só existem no 7:** `??`, `? :`, `ConvertTo-Json -AsArray`, `Join-Path` com três caminhos, `ConvertFrom-Json -DateKind` e `ForEach-Object -Parallel`.
- **Duas diferenças só de aparência:** no 5.1, as datas aparecem no HTML como texto ISO (`2025-06-12T18:45:00Z`), e não como `12/06/2025`, e o `achados.json` sai com outra indentação.
