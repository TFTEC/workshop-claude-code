Status: ready-for-agent

# Spec: relatório FinOps

## Problem Statement

Quem cuida de um ambiente Azure grande sabe que existe dinheiro parado nele:
- discos que ninguém usa;
- IPs públicos sem nada ligado;
- VMs desligadas que ainda pagam pelos discos;
- planos de App Service sem nenhum app;
- snapshots esquecidos;
- workspaces guardando dados demais.

Achar tudo isso no portal, recurso por recurso, leva horas. Mostrar o resultado na empresa também é delicado: o relatório não pode expor nomes de recursos nem inventar números. E quem faz a análise não quer correr o risco de um comando de escrita apagar algo no Azure da empresa.

## Solution

Um relatório FinOps em PowerShell 7 que lê uma subscription-alvo **só com leitura**, aplica um catálogo de regras FinOps e grava a lista de achados e uma página HTML que abre direto no navegador.

- **Economia:** cada achado traz a economia estimada em R$ por mês ou "não sei", sempre com o motivo, nunca 0.
- **Modo anonimizado:** troca nomes, IDs e IPs por rótulos, para mostrar o relatório numa reunião.
- **Fontes:** a fonte `Azure` lê a subscription ao vivo; a fonte `Arquivo` usa os dados fictícios, para testar e para quem não tem acesso a uma subscription.
- **Hook-freio:** antes de tudo, ele já está ativo (exercício 07) e barra qualquer comando de escrita no Azure.

## User Stories

1. Como aluno, quero rodar o relatório na minha subscription com um comando só, para ver o desperdício sem abrir o portal.
2. Como aluno, quero que o relatório só leia o Azure, para poder rodá-lo no ambiente da empresa sem risco.
3. Como aluno, quero que o hook-freio esteja ativo antes de qualquer passo que toque no Azure, para que nenhum comando de escrita passe.
4. Como aluno, quero ver os discos que não estão ligados a nenhuma VM, para apagá-los ou reaproveitá-los.
5. Como aluno, quero ver os IPs públicos que não estão ligados a nada, sem os IPs de NAT Gateway, que estão em uso.
6. Como aluno, quero ver as VMs desligadas que continuam pagando pelos discos.
7. Como aluno, quero ver os planos de App Service pagos e sem nenhum app.
8. Como aluno, quero ver os snapshots mais velhos que um número de dias que eu escolho.
9. Como aluno, quero ver os workspaces de Log Analytics com retenção longa ou sem limite diário.
10. Como aluno, quero ver a economia que o Azure Advisor já recomenda.
11. Como aluno, quero a economia de cada achado em R$ por mês quando houver preço confiável.
12. Como aluno, quero "não sei" com o motivo quando não houver preço confiável, para não levar à empresa um número inventado.
13. Como aluno, quero que o disco criado vazio e nunca anexado apareça com "não sei" e o motivo certo, porque o Azure ainda não cobra por ele.
14. Como aluno, quero ver no topo do HTML o total estimado e, à parte, quantos achados ficaram com "não sei".
15. Como aluno, quero o modo anonimizado, para mostrar o HTML numa tela compartilhada sem expor nomes de recursos, de grupos de recursos, IDs nem IPs.
16. Como aluno, quero que o mesmo recurso tenha sempre o mesmo rótulo dentro de uma execução, para conseguir ler o relatório anonimizado.
17. Como aluno, quero rodar o relatório com os dados fictícios, para testar sem Azure.
18. Como aluno, quero mensagens claras em português quando faltar o Azure CLI, a extensão `resource-graph`, o login ou o papel Reader.
19. Como aluno, quero que o relatório leia todas as páginas do Resource Graph quando uma regra tiver mais de 1.000 linhas.
20. Como aluno, quero incluir uma regra nova só com um arquivo no catálogo, sem mexer no motor.
21. Como aluno, quero que o relatório não desista dos preços na primeira resposta 429 da API, mas tente de novo, esperando um pouco mais a cada vez.
22. Como aluno que terminou antes, quero as regras bônus (Load Balancer e App Gateway vazios, NIC sem VM, recursos sem as tags de custo) e o custo real dos últimos 30 dias.
23. Como aluno, quero revisar o meu código com `/mattpocock-skills:code-review` contra esta spec.

## Implementation Decisions

### Contrato, que as fichas 07 e 09 já usam

- **Ponto de entrada:** o script `relatorio/Invoke-RelatorioFinOps.ps1`.
  - `-SubscriptionId` (obrigatório): a subscription-alvo.
  - `-Fonte` (obrigatório): `Arquivo` ou `Azure`.
  - `-PastaDados`: com a fonte `Arquivo`, a pasta com um JSON por regra. O padrão é a pasta de dados fictícios do repositório.
  - `-Saida`: padrão `saida`, criada se não existir.
  - `-Anonimizar`: liga o modo anonimizado.
  - `-DiasSnapshot`: de 1 a 3650, com padrão 30.
- **Saídas:** `achados.json` e `relatorio-finops.html`, que é autocontido: sem CDN e sem nada de fora.
- **Catálogo:** um arquivo `relatorio/regras/FIN-xx.psd1` por regra FinOps, com ID, título reescrito em português, severidade (Alta, Média ou Baixa), rótulo, KQL e a forma de estimar a economia.

### Como o relatório funciona

- **Achado:** cada um tem regra, título, severidade, recurso, grupo de recursos, subscription, local, detalhes (as outras colunas da KQL), economia (R$/mês ou nada), status da economia (estimada ou "não sei") e o motivo.
- **Fonte `Arquivo`:** cada JSON é a **resposta da KQL** daquela regra, no formato do `az graph query` (`count`, `data`, `skip_token`, `total_records`). O caso "não dispara" é a resposta vazia. O filtro da KQL só se valida contra o Azure de verdade.
- **Fonte `Azure`:**
  - só roda `az extension show`, `az account show` e `az graph query`, este com escopo na subscription-alvo, 1.000 linhas por página e paginação pelo skip token;
  - entrega ao motor o mesmo formato da fonte `Arquivo`;
  - o único POST permitido é a consulta de custo real (bônus).
- **KQL:**
  - vai ao `az` **numa linha só**: no Windows, o `az` é um `az.cmd`, e o `cmd.exe` corta o argumento na primeira quebra de linha, o que faria a consulta perder o escopo da subscription;
  - não pode ter comentário `//`;
  - usa aspas simples nas strings;
  - projeta `name`, `resourceGroup`, `subscriptionId` e, se existir, `location`.
- **Booleano calculado na KQL volta do Resource Graph como 1 ou 0, e não como true ou false** (visto no ensaio). Use `tobool(...)` na KQL, e o motor normaliza 1, 0, "true" e "false" antes de comparar.
- **Economia, de uma de três formas:**
  - o valor do próprio Advisor, só em BRL;
  - o preço de tabela da Retail Prices API (GET público, em BRL, um pedido por medidor, com cache, nova tentativa com espera crescente quando vier 429), convertido para R$/mês: por hora × 730; por mês, direto; por GB por mês × GB;
  - "não sei", com o motivo.
  - Sem preço confiável, o resultado é "não sei", nunca 0. O medidor ambíguo também é "não sei".
- **Disco criado vazio e nunca anexado:** fica com "não sei" e o motivo "o Azure ainda não cobra por ele, porque nunca foi anexado". Não pode aparecer como "medidor ambíguo".
- **Advisor em outra moeda:** o "não sei" mostra nos detalhes o valor e a moeda que o Advisor informou, mas esse valor não entra no total em R$.
- **Modo anonimizado:**
  - rótulos estáveis por execução (`disco-01`, `rg-01`, `sub-01`), com o prefixo vindo do rótulo da regra;
  - nos detalhes, valor igual a um nome original vira o rótulo dele; ID de recurso do Azure, GUID e IP (v4 e v6) viram `<oculto>`;
  - valor em R$ arredonda para a dezena, com **piso de R$ 10** para qualquer valor positivo;
  - nenhum arquivo de saída grava um nome original;
  - o HTML mostra um selo "Modo anonimizado".
- **Arquivos:** os scripts ficam em UTF-8 com BOM (por causa do Windows PowerShell 5.1). As saídas, em UTF-8 sem BOM.

## Testing Decisions

- **Bom teste:** exercita só o comportamento externo, pelo ponto de entrada público, e confere a saída observável (achados.json, HTML, exit code, mensagem). Não testa função interna nem a forma da KQL.
- **Seam do relatório:** o script, com a fonte `Arquivo` e os dados fictícios. Os testes (Pester 5, no PowerShell 7) cobrem:
  - os achados de cada regra e a resposta vazia;
  - a economia com preço e o "não sei";
  - o total separado;
  - o HTML autocontido e com os valores escapados;
  - a ausência de qualquer nome original nos arquivos do modo anonimizado.
- **Seam da fonte Azure:** um `az` falso na frente do PATH, com respostas enlatadas, que registra cada chamada. O teste falha se o script chamar algo fora da lista de leitura.
- **Seam da API de preços:** um Mock da chamada HTTP, para testar o 429 e a paginação sem rede.
- **Seam do hook-freio** (exercício 07): o script do hook, alimentado com o JSON do `PreToolUse`. Escrita no Azure dá exit 2 e leitura dá exit 0.
- **Azure de verdade:** a KQL contra o Azure de verdade não entra nos testes automáticos. Ela é validada rodando o relatório na própria subscription.

## Out of Scope

- Regras que dependem de métricas do Azure Monitor (CPU, DTU) e regras de "sem reserva".
- Converter moeda.
- Qualquer comando que altere o Azure, inclusive "corrigir" um achado.
- Rodar em mais de uma subscription por execução.

## Further Notes

- **Ordem dos tickets:**
  1. o 01 primeiro;
  2. depois o 02, o 03, o 04 e o 05, em paralelo, cada um na sua worktree;
  3. o 06 quando o 02 e o 03 estiverem prontos;
  4. o 07 (bônus) por último.
  
  No workshop, a meta até as 16h20 é o 01 e pelo menos dois dos paralelos. O 06 e o 07 ficam para quem andar rápido ou para depois.
- **Git Bash do Windows:** um argumento que começa com `/` (como o ID de um recurso do Azure) vira caminho de arquivo. Se o Claude testar comandos `az` com IDs pela ferramenta Bash, use `MSYS_NO_PATHCONV=1`. O relatório roda no PowerShell e não sofre disso.
- **Travou?** A branch `gabarito` tem a versão completa e testada: `git switch gabarito`.
