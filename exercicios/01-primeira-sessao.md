# Exercício 1: primeira sessão

**Horário:** 9h30 · **Tempo:** 20 minutos

**Objetivo:** abrir o Claude Code no repositório do aluno e usar os quatro gestos básicos de uma sessão: pedir, apontar um arquivo, rodar um comando e mostrar um erro.

**Feature:** pedido em linguagem natural, `@arquivo`, `!comando`, colar imagem e `/clear`.

## Antes de começar

- Você já clonou o repositório do aluno (veja o [README](../README.md)).
- Neste exercício, o Claude **só lê**. Nenhum arquivo precisa mudar.
- Hoje o editor é o VS Code, e o Claude Code roda no **terminal integrado** do VS Code. É lá que funcionam o `!` e todos os atalhos desta ficha.

## Passos

1. Abra a pasta do repositório no VS Code. No PowerShell, dentro da pasta que você clonou:

   ```powershell
   cd workshop-claude-code
   code .
   ```

2. No VS Code, abra o terminal integrado pelo menu **Terminal > New Terminal** (no VS Code em português, **Terminal > Novo Terminal**). Ele já abre na pasta do repositório. Inicie o Claude Code:

   ```powershell
   claude
   ```

   Se ele perguntar se você confia na pasta, confirme. Repare em duas coisas na tela:
   - no topo, o modelo em uso e o nível de effort (por exemplo, `with medium effort`). Você mexe nisso no exercício 2;
   - embaixo do campo de digitar, o modo de permissão (`⏵⏵ auto mode on`). Você mexe nisso no exercício 3.

3. **Peça algo em linguagem natural.** Digite e aperte Enter:

   ```text
   Resuma o README deste repositório em 5 tópicos curtos.
   ```

   O Claude decide sozinho abrir o `README.md` para ler. Aparece uma linha na tela mostrando essa leitura.

4. **Aponte um arquivo com `@`.** Digite `@check`, espere a lista de sugestões e aperte Tab para completar o nome. Depois termine a frase:

   ```text
   @checklist-pre-workshop.md Quais ferramentas o checklist pede e qual comando confere cada uma? Responda numa tabela.
   ```

   Com o `@`, o conteúdo do arquivo entra direto na conversa. O Claude não precisa procurar.

5. **Rode um comando com `!`.** Com o `!` no começo, o comando roda direto no terminal, sem passar pelo Claude. A saída entra na conversa, e o Claude comenta o resultado logo em seguida:

   ```text
   !git status
   ```

   ```text
   !git log --oneline -5
   ```

   > **No Windows, o `!` roda no Git Bash**, não no PowerShell. Por isso `!git status` e `!ls` funcionam, mas `!Get-ChildItem` dá erro de comando não encontrado.

6. **Provoque um erro e mostre o print para o Claude.**
   1. Abra um segundo terminal no VS Code: no painel do terminal, clique no **+**. Neste terminal, você está no PowerShell, fora do Claude.
   2. Rode o script de prática. Ele tem um bug de propósito:

      ```powershell
      pwsh -File .\exercicios\material\verifica-disco.ps1
      ```

      Aparecem algumas linhas e um erro em vermelho.
   3. Tire um print só da área do erro: aperte **Win+Shift+S** e selecione a área. O print vai para a área de transferência.
   4. Volte ao terminal do Claude (na lista de terminais, à direita do painel, clique no primeiro) e aperte **Alt+V**. Aparece `[Image #1]` no campo de digitar. Complete a mensagem e aperte Enter:

      ```text
      Explique este erro em linguagem simples e diga qual linha do CSV provoca o erro. Não altere nenhum arquivo.
      ```

   > **No macOS:** o print que vai para a área de transferência é **Cmd+Ctrl+Shift+4**, e o atalho para colar a imagem no Claude Code é **Ctrl+V**.

7. **Limpe a conversa com `/clear`.**

   ```text
   /clear
   ```

   O `/clear` começa uma conversa nova, com o contexto vazio. Para provar, pergunte:

   ```text
   O que eu te pedi antes desta mensagem?
   ```

   O Claude não sabe, porque a conversa anterior saiu do contexto. Use `/clear` sempre que trocar de assunto: conversa velha gasta tokens em toda mensagem nova. Se precisar voltar, `/resume` reabre a conversa anterior.

**Pronto quando:** o Claude resumiu o README, respondeu sobre o checklist usando o `@`, comentou a saída do `!git status`, explicou o erro a partir do print e, depois do `/clear`, não lembrou da conversa anterior.

**Desafio extra** (para quem terminou antes)

- Com o campo de digitar vazio, digite `?` e descubra dois atalhos que esta ficha não mostrou.
- Aponte uma pasta inteira, em vez de um arquivo:

  ```text
  O que tem em @exercicios/material/ e para que serve cada arquivo?
  ```

- Aperte **Ctrl+O** para abrir a transcrição detalhada e ver tudo o que o Claude fez por baixo. Aperte Esc para sair.

**Travou?**

- **`claude` não é reconhecido no terminal do VS Code:** feche e abra o VS Code, para ele ler o `PATH` novo. Se continuar, rode `claude doctor` e mostre a saída para o instrutor.
- **O Alt+V não colou a imagem:** confira se o print foi para a área de transferência (o Win+Shift+S faz isso). Se ainda não colar, arraste o arquivo do print para dentro do terminal do Claude (no Windows 11, o print também fica salvo em **Imagens > Capturas de Tela**). Como último recurso, rode o script pelo próprio Claude, e a saída do erro entra direto na conversa:

  ```text
  !pwsh -File exercicios/material/verifica-disco.ps1
  ```

- **`pwsh` não é reconhecido:** o PowerShell 7 não está instalado. Use o Windows PowerShell no lugar: `powershell -ExecutionPolicy Bypass -File .\exercicios\material\verifica-disco.ps1`.
- **O Claude alterou o script:** devolva o arquivo ao original no terminal do PowerShell com `git restore exercicios/material/verifica-disco.ps1`.
- **Ficou para trás:** pule o passo 4 e faça os passos 5, 6 e 7. São eles que você vai usar o dia todo.
