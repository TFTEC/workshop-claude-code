# Exercício 9: rodar no seu ambiente e revisar com code-review

**Horário:** 16h20 · **Tempo:** 20 minutos

**Objetivo:** rodar o relatório FinOps que você implementou na sua própria subscription, gerar a versão anonimizada para mostrar na empresa, entender a diferença entre economia estimada e "não sei" e revisar o código com a skill `code-review` do Matt Pocock.

**Feature:** a fonte `Azure` e o modo anonimizado do relatório FinOps, e a skill `/mattpocock-skills:code-review`, que revisa em dois eixos (Standards e Spec) com dois subagentes em paralelo.

## Antes de começar

- **O freio continua ligado.** No Claude, rode `/hooks` e confira o freio em `PreToolUse`. Se ele não aparecer, volte à ficha 7 antes de qualquer outro passo.
- **Onde rodar.** Na pasta do repositório onde o seu relatório está completo. Se ele ficou numa worktree da ficha 8, abra o Claude e o segundo terminal nessa pasta.
- **Quem roda o relatório é você, no segundo terminal**, não o Claude. Assim, os nomes reais dos recursos e os custos da sua empresa não entram na conversa com o Claude. No macOS, digite `pwsh` no terminal para entrar no PowerShell 7 antes dos comandos.
- **O freio não enxerga dentro de um script.** Ele lê só a linha de comando: `pwsh -File ./relatorio/...` passa, e os `az` que o script chama por dentro não passam pelo freio. Quem garante que o relatório só lê é o papel **Reader** e a revisão do código. Por isso, o passo 1 confere o script antes de rodar.
- **A pasta `saida/` está no `.gitignore`.** O relatório sem anonimizar tem nomes de recursos e custos reais: não faça commit dele e não mostre essa tela na transmissão.

Os comandos usam `./relatorio/Invoke-RelatorioFinOps.ps1`. Se o seu script tem outro nome, use o seu.

## Passos

1. **Confira o que o script chama no Azure.** No Claude, mande:

   ```text
   Sem rodar nada, confira o meu relatório FinOps e responda numa lista curta: (1) quais comandos az ele chama, com arquivo e linha; (2) se ele chama algo fora do az, como Invoke-RestMethod, e com qual método; (3) se ele manda a KQL para o az graph query numa linha só; (4) se alguma KQL das regras tem comentário //.
   ```

   O esperado: só `az account show`, `az extension show` e `az graph query`; um GET na Retail Prices API (`prices.azure.com`); a KQL numa linha só; e nenhum `//` nas regras. Se aparecer qualquer comando de escrita, **não rode**: peça a correção ao Claude ou use o gabarito (ver **Travou?**).

   > **Por que a KQL numa linha só?** No Windows, o `az` é um `az.cmd`, e o `cmd.exe` corta o argumento na primeira quebra de linha. Uma KQL de várias linhas chega ao Azure cortada, sem o `--subscriptions` que vinha depois, e consulta **todas** as subscriptions do seu login. Pelo mesmo motivo, a KQL das regras não usa comentário `//` (numa linha só, ele apagaria o resto da consulta) e usa aspas simples nas strings.

2. **Pegue o ID da subscription.** No segundo terminal:

   ```powershell
   az account list --output table
   ```

   Copie o `SubscriptionId` da subscription em que você tem o papel Reader.

3. **Rode o relatório na sua subscription.** No segundo terminal, troque `<id-da-subscription>` pelo ID, sem os sinais `< >`:

   ```powershell
   pwsh -File ./relatorio/Invoke-RelatorioFinOps.ps1 -Fonte Azure -SubscriptionId <id-da-subscription>
   ```

   O script confere o Azure CLI, a extensão `resource-graph`, o login e a subscription; depois roda a KQL de cada regra e mostra um resumo na tela. Numa subscription pequena, isso leva alguns segundos. No fim, ele grava `saida/achados.json` e `saida/relatorio-finops.html`. Se ele parar com uma mensagem, veja a tabela do **Travou?**.

4. **Abra o HTML.**

   ```powershell
   Invoke-Item saida/relatorio-finops.html
   ```

   No macOS, use `open saida/relatorio-finops.html`. O arquivo não depende de nada de fora e abre direto no navegador.

5. **Leia a economia estimada e o "não sei".** O topo do HTML separa duas coisas:
   - **Economia estimada (R$ por mês):** a soma só dos achados com preço confiável. O valor vem do próprio Advisor (`FIN-07`) ou do preço de tabela da Retail Prices API (disco, IP público e App Service Plan);
   - **achados sem estimativa (não sei):** quantos ficaram sem preço. "Não sei" **não é zero**. É um desperdício que existe, mas cujo valor o relatório não sabe calcular sem inventar. A VM desligada, o snapshot e o Log Analytics ficam sempre com "não sei". Um disco ou um plano com SKU fora da tabela de preços também.

   Escolha um achado com "não sei" e leia o motivo, que aparece embaixo dele. Lembre também que o preço é de tabela, sem desconto de contrato, reserva ou savings plan, e por isso a economia real pode ser menor. Antes de levar um número para a empresa, confira o recurso no portal.

   Se uma regra mostra "Nenhum achado", isso é um resultado, não um erro: a subscription pode estar limpa naquele ponto.

6. **Gere a versão anonimizada.** No segundo terminal:

   ```powershell
   pwsh -File ./relatorio/Invoke-RelatorioFinOps.ps1 -Fonte Azure -SubscriptionId <id-da-subscription> -Anonimizar -Saida saida/anonimizado
   Invoke-Item saida/anonimizado/relatorio-finops.html
   ```

   O `-Saida saida/anonimizado` grava esta versão numa pasta à parte, sem apagar a do passo 3. Compare as duas:
   - o HTML anonimizado mostra o selo **Modo anonimizado**;
   - os recursos viram `disco-01`, `ip-01` e assim por diante; os grupos de recursos viram `rg-01`; a subscription vira `sub-01`;
   - os valores em reais vêm arredondados para a dezena mais próxima;
   - "não sei" continua "não sei".

   Agora confirme que nenhum nome real ficou para trás. Troque `<nome-de-um-resource-group-seu>` por um nome que aparece no relatório do passo 3 (se ele não tiver achados, pegue um nome em `az group list --output table`):

   ```powershell
   Select-String -Path saida/anonimizado/* -Pattern '<nome-de-um-resource-group-seu>' -SimpleMatch
   Select-String -Path saida/anonimizado/* -Pattern '<id-da-subscription>' -SimpleMatch
   ```

   Os dois comandos não podem mostrar nada. Esta é a versão que você pode mostrar numa reunião.

7. **Ponha o seu trabalho em commit.** A `code-review` revisa a diferença entre um ponto fixo e o seu último commit: o que não está em commit fica de fora. No segundo terminal:

   ```powershell
   git status
   ```

   A pasta `saida/` não pode aparecer, porque está no `.gitignore`. Se aparecerem arquivos seus, faça o commit:

   ```powershell
   git add -A
   git commit -m "Relatório FinOps da turma"
   ```

   Confira o que vai entrar na revisão:

   ```powershell
   git log --oneline origin/main..HEAD
   ```

   Aparecem os seus commits desde o clone de manhã, inclusive o do freio. Se a lista vier vazia, veja o **Travou?**.

8. **Revise com a `code-review`.** No Claude, mande:

   ```text
   /mattpocock-skills:code-review ponto fixo origin/main; a spec está em .scratch/relatorio-finops/spec.md e os tickets em .scratch/relatorio-finops/issues/; os padrões de código do relatório estão em .claude/rules/powershell-do-relatorio.md
   ```

   - **Use o nome completo, `/mattpocock-skills:code-review`.** O Claude Code tem também um `/code-review` próprio, que procura bugs no diff atual. É outra skill.
   - **O ponto fixo** é a primeira coisa que a skill pede: um commit, uma branch ou uma tag. Ela compara o seu `HEAD` com ele (`git diff origin/main...HEAD`). Aqui, o ponto fixo é `origin/main`, o repositório como você clonou de manhã. Sem ponto fixo, ela pergunta.
   - **A spec:** a skill procura nas mensagens de commit, no caminho que você passou ou em `.scratch/`. Se não achar, ela pergunta.
   - **Os padrões:** a skill procura no repositório os documentos que dizem como escrever o código. Aqui, é a regra de PowerShell do relatório.

   A skill roda dois subagentes em paralelo, um por eixo, e mostra os dois relatórios lado a lado:
   - **`## Standards`:** o código segue os padrões do repositório? Além dos padrões, ela usa uma lista fixa de "cheiros de código", como nome que não diz o que faz e código duplicado. Os cheiros são sempre sugestão, nunca erro;
   - **`## Spec`:** o código faz o que a spec e os tickets pediram? Ela aponta o que faltou, o que veio sem ser pedido e o que parece feito, mas errado.

   No fim, uma linha resume quantos achados cada eixo teve e o pior de cada um. A skill **só revisa**: não muda nenhum arquivo. Ela leva alguns minutos e gasta mais tokens que uma pergunta comum, porque roda dois subagentes.

9. **Leia como revisor.** Escolha um achado de cada eixo e responda para você mesmo: concordo? É problema de verdade ou é gosto? Anote o que você corrigiria primeiro. Revisar o que o agente escreveu é o seu trabalho, não o do agente.

**Pronto quando:** o relatório rodou com `-Fonte Azure` na sua subscription e o HTML abriu; você sabe explicar, com um achado do seu relatório, por que ele ficou com "não sei" (ou que nenhum ficou); a versão anonimizada abriu com o selo **Modo anonimizado** e o `Select-String` não achou nenhum nome real; e a `code-review` devolveu as seções `## Standards` e `## Spec`.

**Desafio extra** (para quem terminou antes)

- **Corrija um achado da revisão.** Peça ao Claude para corrigir só um ponto:

  ```text
  Corrija só o achado <descreva o achado> do eixo Spec. Depois rode os testes Pester do relatório.
  ```

  Rode o relatório de novo no segundo terminal e faça o commit.
- **Compare com a revisão nativa.** Antes do commit da correção, rode `/code-review`, a revisão do próprio Claude Code, que procura bugs no diff que ainda não está em commit. Compare com a do Matt: uma procura bugs, a outra confere padrões e spec.
- **Revise o gabarito.** Com o seu trabalho em commit, rode `git switch gabarito` no segundo terminal e mande a mesma `/mattpocock-skills:code-review` do passo 8. Compare os achados com os do seu código. Volte com `git switch main`.
- **Rode numa segunda subscription** em que você tem o papel Reader e compare os dois relatórios anonimizados.

**Travou?**

- **O relatório parou com uma mensagem.** Estas são as mensagens do gabarito; as do seu script podem ter outras palavras:

  | A mensagem começa com | O que fazer |
  |---|---|
  | Não achei o Azure CLI | Instale o Azure CLI (https://aka.ms/installazurecli) e abra um terminal novo. |
  | Falta a extensão resource-graph | Rode `az extension add --name resource-graph` no segundo terminal. |
  | O Azure CLI não está logado | Rode `az login`. |
  | Não achei a subscription | Confira o ID com `az account list --output table` e se a sua conta tem o papel Reader nessa subscription. Se o acesso é recente, rode `az login` de novo. |
  | A consulta da regra FIN-xx falhou | A mensagem traz o motivo que o Azure deu. Se for permissão (`AuthorizationFailed`), confira o papel Reader. Se for a KQL, teste a consulta no Resource Graph Explorer do portal. |
  | A regra FIN-xx recebeu só N de M linhas | A KQL usa `limit`, `take` ou `sample`, e aí o Azure não pagina. Tire-os da KQL. |

- **O relatório trouxe recursos de outras subscriptions, ou a KQL deu erro de sintaxe no Windows:** é o corte do `az.cmd` na primeira quebra de linha (ver passo 1). Peça ao Claude: `Faça o script mandar a KQL para o az graph query numa linha só e tire os comentários // das regras.` Rode de novo.
- **O seu relatório não ficou pronto** (falta a fonte `Azure`, falta o `-Anonimizar` ou ele dá erro no meio): rode o gabarito, para sair com o relatório de qualquer jeito. No segundo terminal, guarde o seu trabalho e troque de branch:

  ```powershell
  git add -A
  git commit -m "Meu relatório, em andamento"
  git switch gabarito
  ```

  Depois rode os passos 3 a 6 com o gabarito, com os mesmos comandos:

  ```powershell
  pwsh -File ./relatorio/Invoke-RelatorioFinOps.ps1 -Fonte Azure -SubscriptionId <id-da-subscription>
  pwsh -File ./relatorio/Invoke-RelatorioFinOps.ps1 -Fonte Azure -SubscriptionId <id-da-subscription> -Anonimizar -Saida saida/anonimizado
  ```

  A branch `gabarito` também traz o freio, e o `relatorio/README.md` dela explica cada parâmetro. Para voltar ao seu trabalho, rode `git switch main`.
- **Sem acesso ao Azure** (sem o papel Reader, ou a rede da empresa bloqueia): rode com os dados fictícios. No gabarito, o comando é este; o GUID todo de zeros é de mentira, de propósito:

  ```powershell
  pwsh -File ./relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Fonte Arquivo
  ```

  No seu script, se ele pedir a pasta dos dados, acrescente `-PastaDados` com a pasta dos dados fictícios.
- **A `code-review` disse que o diff está vazio:** o seu trabalho não está em commit (refaça o passo 7), ou você está na pasta ou na branch errada. Confira com `git branch --show-current` e `git log --oneline origin/main..HEAD`.
- **O `/mattpocock-skills:code-review` não aparece:** o plugin não está instalado. No segundo terminal, rode `claude plugin install mattpocock-skills@claude-plugins-official`; depois, no Claude, rode `/reload-plugins`.
- **A revisão veio sem `## Standards` e `## Spec`:** você rodou o `/code-review` do Claude Code. Mande de novo com o nome completo, `/mattpocock-skills:code-review`.
- **A skill pediu para rodar `/setup-matt-pocock-skills`:** não precisa. O repositório já traz esse setup em `docs/agents/`. Confira se o Claude está aberto na raiz do repositório (ou da worktree), e não numa subpasta.
- **O freio barrou um comando durante a revisão:** ele é conservador e barra texto que só parece escrita, como um `grep "az vm stop"`. Peça ao Claude para usar a ferramenta Grep em vez do terminal. Não desligue o freio.
- **Ficou sem tempo:** o essencial são os passos 3, 4 e 6: rodar, abrir e anonimizar. A revisão dos passos 7 e 8 pode ficar para depois do workshop, com os mesmos comandos.
