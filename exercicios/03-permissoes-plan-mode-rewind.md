# Exercício 3: permissões, auto mode, plan mode e rewind

**Horário:** 10h15 · **Tempo:** 25 minutos

**Objetivo:** controlar quanto o Claude faz sozinho, planejar antes de editar, aprovar ou recusar uma edição e desfazer o que ele mudou.

**Feature:** modos de permissão com Shift+Tab, plan mode, aprovar e recusar uma edição, rewind com Esc Esc ou `/rewind`.

## Antes de começar

O **modo de permissão** decide o que o Claude pode fazer sem pedir a sua aprovação. O modo atual fica **sempre visível embaixo do campo de digitar**:

| O que aparece na tela | Nome técnico | O que o Claude faz sem perguntar |
|---|---|---|
| `⏸ manual mode on` (em cinza) | `default` | Só lê. Pergunta antes de editar um arquivo ou rodar a maioria dos comandos. |
| `⏵⏵ accept edits on` | `acceptEdits` | Lê, edita arquivos da pasta e roda comandos simples de arquivo, como `mkdir`, `mv`, `cp` e até `rm`. Pergunta antes dos outros comandos. |
| `⏸ plan mode on` | `plan` | Lê e pesquisa, mas não edita. Termina com um plano para você aprovar. |
| `⏵⏵ auto mode on` | `auto` | Faz tudo sem perguntar. Um segundo modelo, o **classificador**, revisa as ações antes de rodar e bloqueia o que foge do seu pedido. |

> **Desde a versão 2.1.283, na configuração padrão, o Claude Code abre no auto mode** no terminal e no VS Code. Por isso você viu `⏵⏵ auto mode on` nos exercícios 1 e 2. O auto mode diminui as perguntas, mas não garante segurança: o Claude pode editar arquivos sem você ver antes. Neste exercício, você aprende a trocar de modo quando quiser revisar tudo.

Confira se a pasta está limpa antes de começar. No terminal do Claude:

```text
!git status
```

Tem que aparecer `nothing to commit, working tree clean` (ou a mesma frase em português, se o seu Git estiver em português). Se aparecer algum arquivo alterado, veja o **Travou?** no fim da ficha.

## Passos

1. **Dê uma volta pelos modos.** Comece do zero com `/clear`. Depois, com o campo de digitar vazio, aperte **Shift+Tab** quatro vezes, devagar. A cada vez, olhe a linha embaixo do campo:

   `auto mode on` → `manual mode on` → `accept edits on` → `plan mode on` → `auto mode on`

   Se o auto mode não aparecer no ciclo, a sua organização desligou esse modo. Siga o exercício com os outros três.

2. **Entre no plan mode.** Aperte Shift+Tab até aparecer `⏸ plan mode on`. Mande o pedido:

   ```text
   Planeje duas mudanças em @exercicios/material/verifica-disco.ps1: (1) corrigir o erro de divisão por zero quando o disco tem tamanho 0, avisando qual disco foi pulado; (2) trocar o 15 fixo por um parâmetro -LimitePercentual, com padrão 15. Mantenha as mensagens em português.
   ```

   O Claude lê os arquivos e escreve um plano, mas não edita nada. No fim, ele pergunta o que fazer:
   - **Yes, and use auto mode:** aprova e passa para o auto mode (sem auto mode disponível, aparece **Yes, auto-accept edits**);
   - **Yes, manually approve edits:** aprova e pede a sua aprovação em cada edição;
   - **No, keep planning:** continua planejando, com o ajuste que você pedir.

3. **Ajuste o plano antes de aprovar.** Escolha **No, keep planning** e peça:

   ```text
   No aviso do disco pulado, use Write-Warning e mostre o nome do servidor e o disco.
   ```

   Quando o plano novo aparecer, escolha **Yes, manually approve edits**. A linha embaixo do campo muda para `⏸ manual mode on`.

4. **Recuse a primeira edição e aprove a segunda.** O Claude mostra a mudança proposta no arquivo (o diff, em vermelho e verde) e pergunta se pode aplicar.
   1. Na primeira proposta, vá até **No**, aperte **Tab** para abrir o campo de comentário e escreva:

      ```text
      Antes de editar, explique em uma frase o que muda nesta parte.
      ```

      Aperte Enter. O Claude recebe o seu comentário como motivo da recusa e continua.
   2. Na próxima proposta, escolha **Yes**. Aprove as próximas também, até ele terminar.

   > Recusar com **Esc**, ou com **No** sem comentário, para a vez do Claude. Com um comentário, ele entende o motivo e segue.

5. **Teste o script corrigido.** Se o Claude pedir para rodar o script, aprove. Se não, rode você mesmo:

   ```text
   !pwsh -File exercicios/material/verifica-disco.ps1
   ```

   O erro em vermelho sumiu, e aparece um aviso sobre o `srv-arquivos-01`. Veja o que mudou:

   ```text
   !git status
   ```

6. **Peça uma cópia feita por comando de terminal.** Esta etapa prepara o teste do limite do rewind:

   ```text
   Crie uma cópia de exercicios/material/verifica-disco.ps1 chamada copia-verifica-disco.ps1, na mesma pasta, usando um comando de terminal (Copy-Item ou cp), não a ferramenta de edição de arquivos.
   ```

   Aprove o comando quando ele pedir.

7. **Desfaça com o rewind.** Com o campo de digitar **vazio**, aperte **Esc** duas vezes (Esc Esc). Se preferir, digite `/rewind`. O menu lista as mensagens que você mandou nesta conversa.
   1. Escolha a mensagem do passo 2, a que começa com "Planeje duas mudanças". Ignore a linha `/resume ... (previous session)` no topo: ela é da conversa de antes do `/clear`.
   2. Escolha **Restore code**. Esta opção volta os arquivos ao estado de antes daquela mensagem e mantém a conversa.
   3. Confira:

      ```text
      !git status
      ```

   O `verifica-disco.ps1` voltou ao original, com o bug. Mas o `copia-verifica-disco.ps1` **continua lá**, como arquivo novo (`untracked`).

   **Por quê?** O rewind só desfaz o que o Claude mudou com as ferramentas de edição de arquivo. O que ele fez **rodando um comando no terminal** não volta: criar, copiar, mover ou apagar arquivo com `cp`, `mv`, `rm`, `Copy-Item`, `Move-Item` ou `Remove-Item`. O rewind também não substitui o Git: para guardar versões de verdade, faça commit.

8. **Limpe e volte ao auto mode.** Apague a cópia você mesmo:

   ```text
   !rm exercicios/material/copia-verifica-disco.ps1
   ```

   ```text
   !git status
   ```

   Tem que aparecer `working tree clean` de novo. Por fim, aperte **Shift+Tab** até ver `⏵⏵ auto mode on`, ou fique no modo que preferir.

**Pronto quando:** você passou pelos quatro modos vendo o nome de cada um na tela, ajustou e aprovou um plano, recusou uma edição com comentário e aprovou outra, viu o script rodar sem erro, desfez a edição com o rewind, viu a cópia sobreviver ao rewind e terminou com o `git status` limpo.

**Desafio extra** (para quem terminou antes)

- Abra o Claude Code já no plan mode, sem precisar do Shift+Tab: saia com `/exit` e rode `claude --permission-mode plan`.
- Use o `/plan` no começo da mensagem. Ele entra no plan mode e já começa a planejar a tarefa:

  ```text
  /plan adicionar ao script um parâmetro -Arquivo obrigatório
  ```

  Quando o plano aparecer, aperte **Ctrl+G** para abrir o plano no editor e mudar o texto você mesmo antes de aprovar.
- Rode `/permissions` e veja as regras de permissão do projeto. Feche com Esc.

**Travou?**

- **O Shift+Tab não troca o modo:** no Windows, tente **Alt+M**. Em alguns terminais, ele faz o papel do Shift+Tab.
- **O Esc Esc apagou o texto em vez de abrir o menu:** o campo de digitar não estava vazio. Aperte Esc Esc de novo com ele vazio, ou digite `/rewind`.
- **O Claude editou sem perguntar:** você estava no auto mode ou no accept edits. Olhe a linha embaixo do campo. Para desfazer, use o passo 7.
- **O menu do rewind não mostra Restore code:** você escolheu uma mensagem depois da qual o Claude não editou nada. Escolha a mensagem do passo 2.
- **A pasta não ficou limpa:** devolva o script ao original e apague a cópia no terminal do PowerShell:

  ```powershell
  git restore exercicios/material/verifica-disco.ps1
  Remove-Item .\exercicios\material\copia-verifica-disco.ps1
  ```

- **Ficou sem tempo:** pule os passos 3 e 6. Os passos 1, 2, 4 e 7 são o essencial.
