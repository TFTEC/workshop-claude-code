# Exercício 5: plugins e skills

> **Prática opcional, para depois do workshop:** na manhã do workshop o instrutor demonstra estas funcionalidades ao vivo; use esta ficha para repetir no seu ritmo.

**Horário:** 11h15 · **Tempo:** 25 minutos

**Objetivo:** instalar um plugin do marketplace oficial olhando o custo de contexto antes, usar uma skill dele e criar uma skill sua.

**Feature:** `/plugin`, o marketplace oficial `claude-plugins-official`, `claude plugin details`, skills de plugin (`/plugin:skill`), skills do projeto em `.claude/skills/`, `/reload-skills` e `/skills`.

## Antes de começar

- **Skill:** um arquivo `SKILL.md` com instruções que o Claude usa quando a tarefa pede, ou quando você chama pelo nome, como `/gerar-runbook`. Só o nome e a descrição ficam no contexto o tempo todo; o corpo da skill só entra quando ela roda.
- **Plugin:** um pacote que instala de uma vez skills, agentes, hooks e servidores MCP. Ele vem de um **marketplace**. O marketplace oficial da Anthropic, `claude-plugins-official`, já vem configurado na primeira sessão do Claude Code no terminal.
- **Custo de contexto:** todo plugin ligado soma tokens em **toda** mensagem, mesmo quando você não usa nada dele. Por isso você olha o custo antes de instalar.

À tarde, a turma usa as skills oficiais do Matt Pocock (`grill-with-docs`, `to-spec`, `to-tickets` e outras). Este repositório já traz, em `docs/agents/`, os arquivos que elas pedem. Neste exercício, você as instala.

Abra o Claude no terminal, na pasta do repositório. Deixe também um **segundo terminal PowerShell** aberto na mesma pasta: alguns passos rodam fora do Claude. No VS Code, use **Terminal > New Terminal** de novo.

## Passos

1. **Navegue no marketplace.** No Claude, rode:

   ```text
   /plugin
   ```

   O painel abre na aba **Discover**, com os plugins dos seus marketplaces. Digite `azure` para filtrar e veja o que existe. Depois apague e digite `matt`: aparece o `mattpocock-skills`. Aperte Enter para ver a descrição e o que ele instala. Feche com **Esc**.

   > **Não instale o plugin `azure` hoje de manhã.** Ele liga o Azure MCP sem o modo somente leitura, e o hook-freio só existe à tarde. O exercício 6 mostra como ligar o Azure MCP só para leitura.

2. **Veja o custo e instale as skills oficiais do Matt Pocock.** Rode:

   ```text
   /plugin install mattpocock-skills@claude-plugins-official
   ```

   Esse comando não instala na hora: ele abre os detalhes do plugin. Leia a seção **Context cost**:
   - **Every turn:** o que o plugin soma a cada mensagem que você manda;
   - **When invoked:** o que as skills dele somam quando rodam.

   Anote o número do **Every turn**. Depois escolha **Install for you (user scope)**. À tarde, você usa essas skills neste repositório e nas worktrees, por isso o escopo de usuário. No fim, o Claude mostra um resumo:
   - `Plugin is now active.`: pronto, pode usar;
   - `Run /reload-plugins to apply.`: rode `/reload-plugins`.

3. **Meça o custo pelo terminal.** No **segundo terminal**, rode:

   ```powershell
   claude plugin details mattpocock-skills
   ```

   A linha **Always-on** mostra os tokens que o plugin soma a toda sessão. A tabela **Per-component** mostra quanto cada skill pesa sempre (**always-on**) e quanto pesa quando roda (**on-invoke**). Veja qual skill pesa mais.

4. **Use uma skill do plugin.** De volta ao Claude, digite `/matt` e veja as skills listadas como `/mattpocock-skills:<nome>`. Rode a entrevista do `grill-me` numa ideia pequena:

   ```text
   /mattpocock-skills:grill-me Quero um script PowerShell que me avise quando um disco do Azure ficar sem VM.
   ```

   O Claude faz perguntas numeradas, cada uma com uma resposta recomendada. Responda a primeira rodada; se concordar com tudo, escreva `aceito as recomendações`. Depois de uma ou duas rodadas, aperte **Esc** para parar. Não precisa ir até o fim.

5. **Crie a pasta da sua skill.** No **segundo terminal**:

   ```powershell
   New-Item -ItemType Directory -Force .claude/skills/gerar-runbook
   code .claude/skills/gerar-runbook/SKILL.md
   ```

   No macOS, troque a primeira linha por `mkdir -p .claude/skills/gerar-runbook`.

6. **Escreva a skill `gerar-runbook`.** No editor que abriu, escreva o `SKILL.md` com duas partes:
   1. **Frontmatter**, entre duas linhas `---`, logo no começo do arquivo:
      - `name: gerar-runbook`
      - `description:` uma frase que diz o que a skill faz e quando usar.
   2. **Corpo**, depois do frontmatter: o pedido para o Claude. Ele deve:
      - escrever um runbook de troubleshooting em markdown para o serviço Azure informado em `$ARGUMENTS` (o Claude Code troca `$ARGUMENTS` pelo texto que você digita depois do comando);
      - usar seções fixas, como sintomas, primeiras verificações, causas comuns, correção e quando escalar;
      - **não executar nenhum comando**, só escrever.

   O esqueleto é este:

   ```markdown
   ---
   name: gerar-runbook
   description: <o que a skill faz e quando usar>
   ---

   <o pedido para o Claude, com $ARGUMENTS no lugar do serviço Azure>
   ```

   <details>
   <summary>Se quiser conferir: um <code>SKILL.md</code> completo</summary>

   ```markdown
   ---
   name: gerar-runbook
   description: Gera um runbook de troubleshooting em markdown para um serviço Azure. Use quando o aluno pedir um runbook, um roteiro de diagnóstico ou um passo a passo de troubleshooting de um serviço Azure.
   ---

   Escreva um runbook de troubleshooting em markdown para este serviço Azure: $ARGUMENTS

   Se nenhum serviço foi informado, pergunte qual é antes de escrever.

   Use estas seções, nesta ordem:

   1. **Sintomas:** o que a equipe vê quando o serviço tem problema.
   2. **Primeiras verificações:** comandos de leitura do Azure CLI (`show`, `list`), cada um com uma linha sobre o que mostra.
   3. **Causas comuns:** da mais provável para a menos provável, cada uma com o jeito de confirmar.
   4. **Correção:** o que fazer em cada causa. Marque com **[altera o ambiente]** todo passo que cria, altera, reinicia ou apaga recurso.
   5. **Quando escalar:** quando abrir um chamado no suporte da Microsoft e o que anexar.

   Regras:

   - Responda em português, com frases curtas.
   - Não execute nenhum comando. Só escreva o runbook na conversa.
   - Use comandos `az` que existem. Se não tiver certeza de um comando, diga isso em vez de inventar.
   ```

   </details>

   Salve o arquivo.

7. **Carregue e use a sua skill.** A pasta `.claude/skills/` não existia quando a sessão começou, então peça ao Claude para procurar skills de novo:

   ```text
   /reload-skills
   ```

   Digite `/gerar` e veja a sua skill na lista. Rode:

   ```text
   /gerar-runbook Azure App Service
   ```

   O Claude escreve o runbook na conversa, com as seções que você definiu. Daqui para a frente, se você editar o `SKILL.md`, a mudança vale na hora, sem `/reload-skills`.

8. **Compare o peso das skills.** Rode:

   ```text
   /skills
   ```

   Ache a `gerar-runbook` e as skills do `mattpocock-skills`. Aperte `t` para ordenar por tokens. Feche com **Esc**.

**Pronto quando:** o `mattpocock-skills` aparece na aba **Installed** do `/plugin`; você anotou o custo dele (**Every turn** ou **Always-on**); fez pelo menos uma rodada do `grill-me`; e o `/gerar-runbook Azure App Service` devolveu um runbook com as seções que você escreveu.

**Desafio extra** (para quem terminou antes)

- Ponha uma dica de argumento na sua skill. Acrescente ao frontmatter a linha `argument-hint: <serviço Azure>`, salve e digite `/gerar-runbook ` (com espaço): a dica aparece.
- Faça a skill gravar o runbook num arquivo `runbooks/<serviço>.md`, em vez de só responder na conversa. Teste com `/gerar-runbook Azure Key Vault`.
- Veja o custo de outro plugin sem instalar: rode `/plugin install microsoft-docs@claude-plugins-official`, leia o **Context cost** e feche com **Esc**. Esse plugin traz o MCP do Microsoft Learn, que você conecta à mão no exercício 6.

**Travou?**

- **O `/plugin` não mostra o `mattpocock-skills`:** adicione o marketplace oficial com `/plugin marketplace add anthropics/claude-plugins-official` e tente de novo.
- **O painel do `/plugin` não colabora:** instale pelo segundo terminal com `claude plugin install mattpocock-skills@claude-plugins-official`. Depois, no Claude, rode `/reload-plugins`.
- **O `claude plugin details` dá erro:** ele roda no PowerShell, não dentro do Claude, e o plugin precisa estar instalado. Confira com `claude plugin list`.
- **O `/gerar-runbook` não aparece:** rode `/reload-skills`. Confira o caminho no segundo terminal com `Get-ChildItem -Recurse .claude/skills`: tem que ser `.claude/skills/gerar-runbook/SKILL.md`, com `SKILL` em maiúsculas e sem `.txt` no fim. A primeira linha do arquivo precisa ser `---`.
- **O plano bateu no limite de uso:** pule o passo 4. O `grill-me` volta à tarde, na demo do `grill-with-docs`.
- **Ficou sem tempo:** pule os passos 3 e 8. Se a skill não sair, copie o `SKILL.md` do bloco **Se quiser conferir** e siga do passo 7.
