# Exercício 8: implementar em paralelo

**Horário:** 15h20 · **Tempo:** 60 minutos (estimado — ajustar no ensaio)

**Objetivo:** construir o relatório FinOps a partir dos tickets prontos, com o fluxo do formato enxuto: primeiro o motor, numa sessão normal; depois vários tickets ao mesmo tempo, cada um na sua worktree; e por fim juntar tudo na `main`.

**Feature:** a skill `/mattpocock-skills:implement` com TDD, worktrees (`claude -w`), sessões em segundo plano e agent view (`claude agents`), Remote Control (`/remote-control`) e `git merge`.

## Antes de começar

Esta ficha usa só a **fonte `Arquivo`**, com os dados fictícios de `dados-ficticios/`. O relatório roda no Azure da sua empresa só na ficha 9. Assim, você implementa sem tocar em nada real.

Confira quatro coisas no **segundo terminal**, na raiz do repositório:

1. **O freio está em commit** (ficha 7). Tem que aparecer o commit do freio:

   ```powershell
   git log --oneline -3
   ```

   Sem ele, **pare** e volte à ficha 7. As worktrees nascem do que está em commit: uma worktree criada antes do commit nasce **sem freio**.

2. **As worktrees partem dos seus commits.** Por padrão, o Claude Code cria a worktree a partir da `main` do GitHub, que não tem os seus commits: nem o freio, nem o motor que você vai fazer agora. Abra o `.claude/settings.json` e acrescente a chave `worktree` no nível de cima, ao lado de `hooks`:

   ```json
   {
     "worktree": { "baseRef": "head" },
     "hooks": { "...": "o freio, como está" }
   }
   ```

   Com `"baseRef": "head"`, a worktree nasce do seu `HEAD` local. Guarde no Git:

   ```powershell
   git add .claude/settings.json
   git commit -m "Worktrees partem do HEAD local"
   ```

3. **O Pester 5 está instalado** no PowerShell 7. Os testes dos tickets usam o Pester 5, e o Windows traz o 3.4:

   ```powershell
   pwsh -NoProfile -Command "Get-Module Pester -ListAvailable | Select-Object Version"
   ```

   Se não aparecer nenhuma versão `5.`, instale (leva um minuto):

   ```powershell
   pwsh -NoProfile -Command "Install-Module Pester -MaximumVersion 5.99.99 -Scope CurrentUser -Force -SkipPublisherCheck"
   ```

4. **As skills oficiais do Matt Pocock estão instaladas** (ficha 5): o `/mattpocock-skills:implement` aparece quando você digita `/mattpocock-skills:` no Claude.

O mapa dos tickets prontos, em `.scratch/relatorio-finops/issues/`:

| Ticket | O que entrega | Depende de | Tempo (estimado) |
|---|---|---|---|
| 01 | Motor + FIN-01, da fonte `Arquivo` até o HTML | — | 30 min |
| 02 | Regras FIN-02 a FIN-04 | 01 | 25 min |
| 03 | Regras FIN-05 a FIN-07 e o `-DiasSnapshot` | 01 | 25 min |
| 04 | Fonte `Azure` | 01 | 30 min |
| 05 | Modo anonimizado | 01 | 25 min |
| 06 | Economia e "não sei" | 02 e 03 | 30 min |
| 07 | Bônus e custo real | 06 | 30 min |

Depois do 01, os tickets **02 a 05 não dependem um do outro**: é aí que entra o paralelo.

## Passos

1. **Implemente o ticket 01 na sessão principal.** Abra o Claude na raiz do repositório, já na `main`, e digite:

   ```text
   /mattpocock-skills:implement .scratch/relatorio-finops/issues/01-motor-e-primeira-regra.md
   ```

   Essa skill só roda quando **você** a digita: o Claude não a chama sozinho. Ela lê o ticket e a spec, escreve um teste por vez antes do código (TDD, com a skill `tdd`), roda os testes, revisa o próprio trabalho e faz commit na branch atual. Acompanhe e aprove as edições.

2. **Enquanto o 01 roda, acompanhe pelo celular.** Na mesma sessão, digite:

   ```text
   /remote-control
   ```

   Na primeira vez, escolha **Enable Remote Control**. Rode `/remote-control` de novo para ver o painel com o link e o **QR code**. Escaneie com o app Claude no celular. A conversa aparece nos dois lugares: mande uma pergunta pelo celular, por exemplo "em que passo do ticket você está?", e veja a resposta no terminal. Se você ainda não tem o app, `/mobile` mostra um QR code da loja.

   > O Remote Control exige login no claude.ai com os planos **Pro, Max, Team ou Enterprise**. Com chave de API ele não funciona. No Team e no Enterprise, um Owner precisa ligar a opção nas configurações de admin. Sem isso, pule este passo e acompanhe tudo pelo agent view, no passo 5.

3. **Confira o 01 antes de seguir.** No segundo terminal:

   ```powershell
   git log --oneline -3
   pwsh -NoProfile -Command "Invoke-Pester -Path testes -Output Detailed"
   pwsh -NoProfile -File relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Fonte Arquivo
   ```

   O commit do 01 aparece, os testes passam, e a pasta `saida/` tem o `achados.json` e o `relatorio-finops.html`. Só siga com o 01 em commit: os próximos tickets partem dele.

4. **Mande os tickets 02 e 03 para o segundo plano.** Abra o agent view num terminal novo:

   ```powershell
   claude agents
   ```

   No campo de despachar, digite o pedido e aperte **Enter**. Cada pedido vira uma sessão em segundo plano:

   ```text
   /mattpocock-skills:implement .scratch/relatorio-finops/issues/02-regras-fin-02-a-04.md — use a fonte Arquivo, faça commit na branch da sua worktree e não faça push.
   ```

   ```text
   /mattpocock-skills:implement .scratch/relatorio-finops/issues/03-regras-fin-05-a-07.md — use a fonte Arquivo, faça commit na branch da sua worktree e não faça push.
   ```

   Antes de editar, cada sessão em segundo plano entra sozinha numa worktree própria, em `.claude/worktrees/`. As duas leem o mesmo repositório, mas cada uma escreve na sua cópia, sem pisar uma na outra.

   > **"Não faça push"** é de propósito: sem esse pedido, uma sessão em segundo plano pode tentar um push quando o repositório tem remoto, e você não tem permissão de escrita no repositório do workshop. Os commits ficam só na sua máquina.

   Também dá para começar uma sessão em segundo plano direto do terminal, com um nome: `claude --bg --name fin-02 "Implemente o ticket .scratch/relatorio-finops/issues/02-regras-fin-02-a-04.md com TDD, faça commit na branch da sua worktree e não faça push."`.

5. **Acompanhe no agent view.** As sessões aparecem agrupadas pelo estado: `Pinned`, `Ready for review`, `Needs input`, `Working` e `Completed`.
   - **↑ e ↓** andam pelas linhas.
   - **Espaço** abre a espiada, com a última saída ou a pergunta da sessão. Digite a resposta e aperte **Enter** para responder sem sair do painel.
   - **Enter** ou **→** entra na conversa inteira. **←**, com o campo vazio, volta para a tabela.
   - Pergunta de permissão não se responde pela espiada: entre na conversa com **→**.

   > O agent view está em *research preview*: os atalhos podem mudar.

6. **Faça os tickets 04 e 05 em worktrees, em primeiro plano.** Abra mais dois terminais na raiz do repositório:

   ```powershell
   claude -w fin-04
   ```

   ```powershell
   claude -w fin-05
   ```

   O `-w` cria a worktree em `.claude/worktrees/fin-04/`, numa branch nova chamada `worktree-fin-04`, e já abre o Claude lá dentro. Na primeira mensagem de cada uma, **confira a base**:

   ```text
   !git log --oneline -3
   ```

   Têm que aparecer os commits do freio e do ticket 01. Se não aparecerem, veja o **Travou?**. Depois, em cada uma:

   ```text
   /mattpocock-skills:implement .scratch/relatorio-finops/issues/04-fonte-azure.md
   ```

   ```text
   /mattpocock-skills:implement .scratch/relatorio-finops/issues/05-modo-anonimizado.md
   ```

   O ticket 04 escreve a leitura do Azure, mas nesta ficha você testa só com o az falso dos testes. O Azure de verdade fica para a ficha 9.

   > **Quatro sessões ao mesmo tempo gastam o seu limite de uso mais rápido.** No plano Pro, prefira duas por vez: o 02 e o 03 primeiro, e depois o 04 e o 05.

7. **Feche as worktrees guardando o trabalho.** Quando cada sessão em primeiro plano terminar o ticket, com commit, saia com `/exit`. Se o Claude perguntar, escolha **manter** a worktree: a branch dela ainda não está na `main`. As sessões em segundo plano ficam em `Completed` no agent view, com o commit feito.

8. **Junte tudo na `main`.** Volte à sessão principal, na raiz do repositório e na `main`. Veja as branches das worktrees:

   ```text
   !git worktree list
   ```

   Depois, peça ao Claude:

   ```text
   Junte na main, uma de cada vez, as branches das worktrees dos tickets 02, 03, 04 e 05, com git merge. Depois de cada merge, rode os testes Pester. Se der conflito, pare e me mostre.
   ```

   **Por que `git merge`:** é um comando por branch, com o nome da branch, sem precisar copiar o hash de cada commit, como no `cherry-pick`. Os tickets 02 e 03 só acrescentam arquivos, então quase nunca dão conflito. O 04 e o 05 mexem os dois no motor: se der conflito, digite `/mattpocock-skills:resolving-merge-conflicts`, e o Claude resolve com você, mostrando o que mudou de cada lado.

9. **Rode o relatório completo com a fonte `Arquivo`.** No segundo terminal:

   ```powershell
   pwsh -NoProfile -Command "Invoke-Pester -Path testes -Output Detailed"
   pwsh -NoProfile -File relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Fonte Arquivo
   pwsh -NoProfile -File relatorio/Invoke-RelatorioFinOps.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -Fonte Arquivo -Anonimizar -Saida saida/anonimizado
   start saida/relatorio-finops.html
   ```

   No macOS, troque o `start` por `open`. O HTML mostra as regras FIN-01 a FIN-07 com os dados fictícios. O anonimizado mostra o selo "Modo anonimizado" e os rótulos no lugar dos nomes.

10. **Se der tempo, siga para o 06 e o 07.** O 06 depende do 02 e do 03, e o 07 depende do 06. Os dois ficam na sessão principal, um depois do outro:

    ```text
    /mattpocock-skills:implement .scratch/relatorio-finops/issues/06-economia-e-nao-sei.md
    ```

**Pronto quando:** o `git log --oneline` da `main` mostra os commits dos tickets 01 a 05; os testes Pester passam; o HTML com a fonte `Arquivo` mostra as regras FIN-01 a FIN-07; o anonimizado mostra o selo; e pelo menos uma sessão em segundo plano apareceu como `Completed` no agent view.

**Desafio extra** (para quem terminou antes)

- **Subagentes em worktrees, numa sessão só.** Em vez de abrir uma sessão por ticket, peça numa sessão só: `Implemente os tickets 06 e 07 em sequência, cada um com um subagente na sua própria worktree, com TDD e commit, sem push.` O Claude divide o trabalho entre subagentes, e cada um edita a sua cópia.
- **Limpe as worktrees que já entraram na `main`.** Peça ao Claude a lista com `git worktree list` e remova as que já foram juntadas, uma por uma, com `git worktree remove .claude/worktrees/<nome>`. No agent view, apagar uma sessão também apaga a worktree dela, **inclusive o que não estiver em commit**. Se a worktree tiver commits que não foram enviados (o caso desta ficha, sem push), a remoção é recusada e a worktree fica: aí use `git worktree remove`, com `--force` se houver mudanças sem commit.
- **Compare com o gabarito.** Peça: `Compare o meu relatorio/ com o da branch origin/gabarito e liste as diferenças de comportamento, não de estilo.`

**Travou?**

- **O ticket 01 não terminou a tempo:** copie da branch `gabarito` o motor e o catálogo, e siga a partir do passo 4. No segundo terminal:

  ```powershell
  git checkout origin/gabarito -- relatorio/ testes/
  git commit -m "Motor do gabarito"
  ```

  O motor do gabarito já faz tudo: com ele, os tickets 02 a 05 viram leitura e conferência do que já existe. Use isso só para não ficar parado.
- **Um ticket parado travou:** copie da branch `gabarito` só os arquivos daquele ticket, por exemplo as regras do ticket 02: `git checkout origin/gabarito -- relatorio/regras/FIN-02.psd1 relatorio/regras/FIN-03.psd1 relatorio/regras/FIN-04.psd1`.
- **O `!git log` da worktree não mostra o freio nem o ticket 01:** a worktree nasceu da `main` do GitHub. Confira o `"worktree": { "baseRef": "head" }` no `.claude/settings.json` e se ele está em commit. Depois saia da sessão, escolha **remover** a worktree e crie de novo com `claude -w`.
- **A sessão em segundo plano pediu login do GitHub ou tentou fazer push:** responda que não é para fazer push, só commit na branch da worktree.
- **Deu conflito no merge e você não quer resolver agora:** peça ao Claude `git merge --abort`. A `main` volta a como estava, e a branch do ticket continua guardada para depois.
- **O Claude disse que o freio barrou um comando de `git`:** o freio barra texto que parece escrita no Azure, até numa mensagem de commit. Peça para refazer o commit com outra mensagem.
- **`/mattpocock-skills:implement` não aparece:** as skills oficiais não estão instaladas. Volte à ficha 5, ou rode `claude plugin install mattpocock-skills@claude-plugins-official` no terminal e reabra o Claude.
- **Os testes não rodam (`Invoke-Pester` não existe ou dá erro de sintaxe):** o PowerShell está usando o Pester 3.4. Instale o Pester 5 (passo 3 do "Antes de começar") e rode os testes com `pwsh`, nunca com `powershell`.
- **O limite de uso do plano acabou:** pare as sessões em segundo plano no agent view e siga com uma sessão só, um ticket por vez.
- **Rodou com a fonte `Azure` e algo estranho aconteceu:** as lições do ensaio estão na spec. No Git Bash, um argumento que começa com `/` vira caminho de arquivo, e o `az.cmd` do Windows corta a KQL na primeira quebra de linha. Por isso a ficha usa só a fonte `Arquivo`: o Azure de verdade fica para a ficha 9.
