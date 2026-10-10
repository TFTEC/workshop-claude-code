# Exercício 2: modelo, effort e tokens

> **Prática opcional, para depois do workshop:** na manhã do workshop o instrutor demonstra estas funcionalidades ao vivo; use esta ficha para repetir no seu ritmo.

**Horário:** 9h50 · **Tempo:** 21 minutos

**Objetivo:** rodar a mesma tarefa pequena com modelos e níveis de effort diferentes e ver, nos números, o que gasta tokens.

**Feature:** `/model`, `/effort`, `/context`, `/usage` (o mesmo que `/cost`) e `/compact`. O `/fast` não tem demo: o instrutor só comenta.

## Antes de começar: custo

> **Cada rodada gasta uma fatia do limite de uso do seu plano.** A tarefa é pequena de propósito: as três rodadas juntas gastam pouco. Mesmo assim:
>
> - **Plano com limite menor (Pro) ou limite quase no fim:** faça só as rodadas 1 e 3. Antes de começar, rode `/usage` e veja quanto da barra da sessão você já usou.
> - **Se aparecer `Usage limit reached`:** o Claude Code espera o limite renovar e continua sozinho. Não ligue créditos extras (usage credits) só por causa do workshop. Acompanhe pela tela do instrutor e anote os números dele.
> - **Não rode `/fast`** e cuidado com o atalho **Alt+O**, que liga e desliga o fast mode. Ele é cobrado à parte, só em créditos extras. Veja o fim desta ficha.

Três palavras que esta ficha usa:

- **Token:** o pedaço de texto que o modelo lê e escreve. Uma palavra costuma virar um ou mais tokens. O plano e a API medem o uso em tokens.
- **Contexto:** tudo o que o Claude está "vendo" na conversa: suas mensagens, as respostas, os arquivos lidos e as instruções do projeto. **Cada mensagem nova reenvia o contexto inteiro.** Por isso conversa longa gasta mais.
- **Effort:** quanto o modelo pensa antes de responder. Effort baixo é mais rápido e gasta menos. Effort alto pensa mais, confere mais e gasta mais.

## Passos

Anote os números de cada rodada num bloco de notas, nesta tabela:

| Rodada | Modelo | Effort | Demorou (aprox.) | Tokens no `/context` | Custo estimado no `/usage` | Achou o bug e a linha certa? |
|---|---|---|---|---|---|---|
| 1 | `haiku` | `low` | | | | |
| 2 | `opus` | `low` | | | | |
| 3 | `opus` | `high` | | | | |

A rodada 2 troca só o modelo. A rodada 3 troca só o effort. Mudando uma coisa por vez, você sabe o que causou a diferença.

1. No terminal do Claude (o mesmo do exercício 1), comece do zero:

   ```text
   /clear
   ```

2. Veja o que você tem hoje. Rode `/model` sozinho para abrir a lista de modelos. Repare nos nomes (`opus`, `sonnet`, `haiku`) e no preço de cada um, quando aparecer. Aperte **Esc** para fechar sem trocar nada. Depois confira o effort atual:

   ```text
   /effort status
   ```

3. **Rodada 1: modelo pequeno, effort baixo.** Rode os dois comandos, um de cada vez. Se o Claude Code pedir para confirmar a troca, confirme.

   ```text
   /model haiku
   ```

   ```text
   /effort low
   ```

   Agora mande a tarefa. **Use exatamente este texto nas três rodadas:**

   ```text
   Leia @exercicios/material/verifica-disco.ps1 e @exercicios/material/discos.csv. Em até 6 linhas, diga o que o script faz, qual é o bug e qual linha do CSV provoca o bug. Não altere nenhum arquivo.
   ```

   Quando ele terminar, olhe o contexto e o uso. Anote os números na tabela:

   ```text
   /context
   ```

   ```text
   /usage
   ```

   - O `/context` mostra uma grade colorida com o que ocupa o contexto e o total de tokens em uso.
   - O `/usage` mostra os tokens da sessão por modelo e um **custo estimado em dólar**. Esse valor é o que a conversa custaria na API, a preço de tabela. **No plano de assinatura, você não paga esse valor.** O que conta para você são as barras de uso do plano, que aparecem na mesma tela. Aperte Esc para fechar.

4. **Rodada 2: modelo grande, effort baixo.** O `/clear` zera a conversa e também os totais do `/usage`. Assim, cada rodada começa do zero.

   ```text
   /clear
   ```

   ```text
   /model opus
   ```

   ```text
   /effort low
   ```

   Mande a mesma tarefa da rodada 1, rode `/context` e `/usage` e anote.

5. **Rodada 3: modelo grande, effort alto.** Fica no `opus` e troca só o effort:

   ```text
   /clear
   ```

   ```text
   /effort high
   ```

   Mande a mesma tarefa, rode `/context` e `/usage` e anote.

6. **Compare a tabela.** Responda para você mesmo:
   - Qual rodada demorou mais? Qual gastou mais tokens?
   - O `haiku` achou a linha certa do CSV (`srv-arquivos-01`, disco com tamanho 0)?
   - Para uma tarefa pequena como esta, valeu a pena o effort alto?

   Regra prática: comece com o padrão. Suba o effort em trabalho onde errar custa caro, como corrigir um bug num script de produção. Desça o effort, ou use um modelo menor, em perguntas rápidas que você mesmo vai revisar.

7. **Entenda o `/compact`.** Ainda na conversa da rodada 3, rode:

   ```text
   /compact
   ```

   ```text
   /context
   ```

   O `/compact` troca a conversa por um resumo dela e libera espaço no contexto. A conversa continua, só que mais leve. O Claude Code também faz isso sozinho quando o contexto está quase cheio. Compare com o `/clear`:
   - **`/compact`:** mantém o fio da conversa, mas é um pedido ao modelo, que lê a conversa inteira para resumir. Em conversa grande, isso gasta.
   - **`/clear`:** não custa nada, mas começa do zero.

   Para guiar o resumo, passe uma instrução: `/compact mantenha só o bug e a linha do CSV`.

8. **Volte ao padrão.** O `/model` e o `/effort` digitados assim ficam salvos para as próximas sessões. Desfaça antes de seguir:

   ```text
   /effort auto
   ```

   ```text
   /model default
   ```

   O `/effort auto` limpa o effort salvo para o modelo ativo. O `/model default` volta ao modelo padrão da sua conta. Confira o modelo no `/status` ou no topo da tela, e o effort no `/effort status`.

   O effort fica salvo por modelo. O `haiku` continua com o `low` da rodada 1. Se um dia você voltar a usar o `haiku`, rode `/effort auto` com ele ativo.

**Pronto quando:** a tabela tem as três rodadas (ou as rodadas 1 e 3, no plano com limite menor), você sabe dizer qual combinação gastou mais e por quê, rodou o `/compact` e voltou ao padrão com `/effort auto` e `/model default`.

**Desafio extra** (para quem terminou antes)

- Repita uma rodada **sem mudar o seu padrão**. Rode `/model` sozinho, escolha o modelo com as setas para cima e para baixo, ajuste o effort com as setas para os lados e aperte **s**. O **s** aplica a escolha só nesta sessão.
- Mande a tarefa com a palavra `ultrathink` no texto. Ela pede um raciocínio mais profundo só naquela mensagem, sem mudar o effort da sessão. Compare o tempo e os tokens.
- Experimente **Alt+P**: troca o modelo sem apagar o que você já digitou.

**Travou?**

- **`/model haiku` não aceitou:** a sua organização pode ter restringido os modelos. Use `/model sonnet` no lugar do `haiku`.
- **Não sabe em que modelo ou effort está:** `/status` mostra o modelo, `/effort status` mostra o effort, e o topo da tela mostra os dois.
- **Esqueceu de voltar ao padrão:** rode `/effort auto` e `/model default` a qualquer momento, até no fim do dia.
- **Bateu o limite de uso:** pare, acompanhe pela tela do instrutor e copie os números dele para a sua tabela. Se o limite renovar a tempo, siga normalmente.
- **Ficou sem tempo:** faça só as rodadas 1 e 3 e o passo 8.

## `/fast`: só comentado, sem demo

O fast mode deixa o Opus até 2,5 vezes mais rápido, com a mesma qualidade, mas cobra mais por token. Nos planos de assinatura, ele **só funciona com créditos extras** e gasta deles **mesmo que ainda sobre limite no seu plano**. Por isso, no workshop, só o instrutor mostra.

- Quando está ligado, aparece um `↯` ao lado do campo de digitar.
- Se você ligou sem querer (por exemplo, com **Alt+O**), rode `/fast`, aperte **Espaço** para desligar e **Enter** para confirmar.
- Se os créditos extras não estiverem ligados na sua conta, o `/fast` só mostra a mensagem `Fast mode requires usage credits` e não liga.
