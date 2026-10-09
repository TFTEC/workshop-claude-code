# Exercício 4: CLAUDE.md e memória

> **Prática opcional, para depois do workshop:** na manhã do workshop o instrutor demonstra estas funcionalidades ao vivo; use esta ficha para repetir no seu ritmo.

**Horário:** 10h50 · **Tempo:** 25 minutos

**Objetivo:** entender quais arquivos de instrução o Claude Code carrega, quando carrega cada um e como conferir isso.

**Feature:** `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`, regras em `.claude/rules/` (com e sem `paths`), `/context`, `/memory` e a opção **Project instructions** do `/config`.

## Antes de começar

Este repositório já traz uma **camada de agente de exemplo**: os arquivos que orientam o Claude, e não o projeto em si.

| Arquivo | Quem escreve | Vai para o git? | Quando carrega |
|---|---|---|---|
| `CLAUDE.md` | A equipe | Sim | No começo de toda sessão |
| `.claude/rules/combinados.md` | A equipe | Sim | No começo de toda sessão (não tem `paths`) |
| `.claude/rules/powershell-do-relatorio.md` | A equipe | Sim | Só quando o Claude lê ou edita um arquivo que casa com `relatorio/**/*.ps1` ou `relatorio/**/*.psd1` |
| `CLAUDE.local.md` | Você | Não (já está no `.gitignore`) | No começo de toda sessão, depois do `CLAUDE.md` |
| `AGENTS.md` | A equipe | Sim | No padrão, **nunca** aqui: o Claude Code só lê o `AGENTS.md` quando a pasta não tem `CLAUDE.md` nem `CLAUDE.local.md` |

> Esses arquivos são **pedidos** ao Claude, não impedimentos. Ele costuma seguir, mas nada o obriga. Quem **impede** um comando de escrita no Azure é o hook-freio, que você cria à tarde.

Faça o exercício no **terminal**, na pasta do repositório. O `/config` não abre no painel do Claude Code dentro do VS Code; se você usa o VS Code, rode `claude` no terminal integrado (menu **Terminal > New Terminal**).

## Passos

1. **Veja o que carregou.** Se o Claude já está aberto, saia com `/exit`. Abra de novo, para começar uma sessão limpa:

   ```powershell
   claude
   ```

   Depois rode:

   ```text
   /context
   ```

   Embaixo da grade colorida, procure a lista **Memory files**. Se ela não aparecer, rode `/context all`. Na lista estão o `CLAUDE.md` e o `.claude/rules/combinados.md`. Podem aparecer também o seu `CLAUDE.md` pessoal (`~/.claude/CLAUDE.md`) e a memória automática, se você já tiver. **Não estão** na lista: o `AGENTS.md` e a regra `powershell-do-relatorio.md`.

2. **Veja os comentários que não gastam contexto.** Abra o `CLAUDE.md` no editor:

   ```text
   !code CLAUDE.md
   ```

   O arquivo começa com um bloco `<!-- ... -->`, um comentário HTML com notas para humanos. O Claude Code remove esses comentários antes de colocar o arquivo no contexto. Confira:

   ```text
   Sem abrir nenhum arquivo, responda: as instruções de projeto que você recebeu citam o hook-freio?
   ```

   A resposta é "não": o hook-freio só aparece dentro do comentário.

3. **Crie o seu `CLAUDE.local.md`.** Troque `Ana` pelo seu nome e rode as duas linhas, uma de cada vez:

   ```text
   !echo "- Meu nome é Ana. Me chame pelo meu nome nas respostas." > CLAUDE.local.md
   ```

   ```text
   !echo "- Quando me mostrar um comando, use a sintaxe do PowerShell 7." >> CLAUDE.local.md
   ```

   O arquivo só carrega no começo da sessão. Saia com `/exit`, abra de novo com `claude` e rode `/context`. O `CLAUDE.local.md` agora aparece em **Memory files**. Mande:

   ```text
   oi, tudo bem?
   ```

   O Claude responde usando o seu nome. Esse arquivo é só seu: o `.gitignore` deixa ele fora do git, e ninguém da turma recebe as suas preferências.

4. **Veja o `AGENTS.md` sendo ignorado.** Abra o `AGENTS.md` no editor (`!code AGENTS.md`) e leia a última seção: ela pede que toda resposta termine com a linha `(AGENTS.md carregado)`. Repare que a resposta do passo 3 **não** terminou com essa linha. O motivo: a pasta tem `CLAUDE.md` e `CLAUDE.local.md`, e, no padrão, qualquer um deles faz o Claude Code ignorar o `AGENTS.md`.

5. **Carregue o `AGENTS.md` pelo `/config`.**
   1. Rode:

      ```text
      /config
      ```

   2. O painel abre na aba **Config**. Digite `instructions` para filtrar a lista, ou desça com as setas, até **Project instructions**. Aperte Enter.
   3. Escolha `claude-md-and-agents-md` e aperte Enter. Feche o painel com **Esc**.
   4. A mudança vale a partir da próxima mensagem. Mande:

      ```text
      oi de novo
      ```

      A resposta agora termina com `(AGENTS.md carregado)`. Rode `/context`: o `AGENTS.md` entrou em **Memory files**, junto com o `CLAUDE.md`. É o mesmo conteúdo em dobro, pagando tokens duas vezes.

6. **Volte ao padrão. Não pule este passo.** O `/config` grava essa opção nas suas configurações de usuário (`~/.claude/settings.json`), e ela vale para **todos** os seus projetos, não só para este.
   1. Rode `/config`, vá de novo até **Project instructions** e escolha `claude-md-or-agents-md`, que é o padrão. Feche com **Esc**.
   2. Saia com `/exit` e abra de novo com `claude`. Mande:

      ```text
      oi pela última vez
      ```

      A linha `(AGENTS.md carregado)` sumiu. Se quiser, confira no `/context`: o `AGENTS.md` saiu de **Memory files**.

7. **Use o `/memory`.** Rode:

   ```text
   /memory
   ```

   A lista mostra os arquivos de memória do usuário e do projeto, entre eles o `CLAUDE.md` e o seu `CLAUDE.local.md`. Ela também tem a chave da **memória automática** (as notas que o próprio Claude escreve) e a opção de abrir a pasta dessas notas. Escolha o `CLAUDE.local.md`: ele abre no editor. Feche o editor sem mudar nada e aperte **Esc** no Claude.

8. **Veja a regra com `paths` carregar só quando precisa.** Abra a regra no editor (`!code .claude/rules/powershell-do-relatorio.md`): o topo tem um bloco `paths:` com os padrões `relatorio/**/*.ps1` e `relatorio/**/*.psd1`. Lembre que ela **não** estava no `/context` do passo 1. Agora peça:

   ```text
   Leia o arquivo relatorio/exemplo.ps1 e me diga o que ele faz.
   ```

   Enquanto o Claude lê, o terminal mostra uma linha curta avisando que carregou a `.claude/rules/powershell-do-relatorio.md`. Confira o efeito:

   ```text
   Que convenções de PowerShell você deve seguir quando editar esse arquivo?
   ```

   O Claude lista as convenções da regra, como `Set-StrictMode` e verbos aprovados. A regra só gastou contexto quando o trabalho tocou em PowerShell do relatório.

**Pronto quando:** você viu o `CLAUDE.md` e o `combinados.md` no `/context`; criou o `CLAUDE.local.md` e o Claude passou a usar o seu nome; viu a linha `(AGENTS.md carregado)` aparecer só depois de trocar o **Project instructions**; voltou ao `claude-md-or-agents-md` e a linha sumiu; e viu a regra do PowerShell carregar só depois de o Claude ler o `relatorio/exemplo.ps1`.

**Desafio extra** (para quem terminou antes)

- Carregue o `AGENTS.md` sem mexer no `/config`, com um import. Acrescente uma linha ao seu `CLAUDE.local.md`:

  ```text
  !echo "@AGENTS.md" >> CLAUDE.local.md
  ```

  Saia com `/exit`, abra com `claude` e mande uma mensagem: a linha `(AGENTS.md carregado)` volta. É assim que um único `AGENTS.md` serve o Claude Code e os outros agentes. No Windows, prefira esse import a um link simbólico. No fim, abra o `CLAUDE.local.md` pelo `/memory` e apague a linha `@AGENTS.md`.
- Teste a memória automática. Peça `lembre que eu prefiro respostas em tabela quando comparar opções`. Depois rode `/memory`, escolha a pasta da memória automática e veja a nota que o Claude escreveu.

**Travou?**

- **O `/config` não mostra Project instructions:** rode `claude --version` no PowerShell. Precisa ser 2.1.277 ou mais nova; atualize com `claude update`. Se acabou de atualizar, saia e abra o Claude de novo: em alguns casos a opção só aparece na sessão seguinte. Lembre que o `/config` só abre no terminal, não no painel do VS Code.
- **O `CLAUDE.local.md` não aparece no `/context`:** confira o nome com `!ls`. Ele precisa estar na raiz do repositório, com esse nome exato. Depois de criar, é preciso sair com `/exit` e abrir de novo.
- **Aparece um `CLAUDE.md` de outra pasta no `/context`:** o Claude Code carrega também os `CLAUDE.md` das pastas acima da atual. Não atrapalha o exercício, mas mostra por que vale clonar o repositório numa pasta própria.
- **A linha `(AGENTS.md carregado)` não some depois do passo 6:** abra o `/config` e confira se o **Project instructions** está em `claude-md-or-agents-md`. Se você fez o desafio extra, confira também se apagou a linha `@AGENTS.md` do `CLAUDE.local.md`. Depois, saia e abra de novo.
- **A regra do PowerShell não carregou:** abra o Claude na raiz do repositório, porque os padrões do `paths` partem dela. Peça de novo, de forma explícita: `use a ferramenta Read para ler relatorio/exemplo.ps1`.
- **Ficou sem tempo:** pule os passos 2 e 7. **Nunca pule o passo 6.**
