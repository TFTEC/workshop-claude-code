# Skills do Matt Pocock (fork em `claude-plugins/`)

Serve para quem vai aplicar ou desfazer o fork do plugin `mattpocock-skills`, mudar a descrição de um fluxo ou trazer uma versão nova do autor. O plugin oficial (licença MIT) trava 14 skills de fluxo com `disable-model-invocation: true`, e só o dono, digitando o comando, conseguia rodá-las. O fork mora em `claude-plugins/`, como o marketplace local `tftec`, com o mesmo nome de plugin: os comandos continuam `/mattpocock-skills:<skill>`, e o agente passa a chamar os fluxos pelo Skill tool (#132). A pasta não se chama `plugins/` porque, no glossário do projeto, Plugin são as ações do chat do produto.

## Quando o agente chama um fluxo

A descrição de cada fluxo diz que ele entra só pelo pedido do dono ("Use só quando o dono pedir…"), com o nome do fluxo ou com as palavras dele, ou pela indicação do `ask-matt` ("…ou quando o ask-matt indicar este fluxo"). O `ask-matt`, que é o mapa, entra quando o dono pede um caminho entre as skills ou pergunta qual usar. O agente escolhe o fluxo pela seção "Escolha da skill" do [CLAUDE.md](../../CLAUDE.md.exemplo) ou pelo `ask-matt`; no meio de outra tarefa, o assunto bater não basta.

Se o Skill tool recusar um fluxo, o fork não está aplicado naquela máquina: o agente entrega ao dono o comando pronto para digitar, como antes.

As 14: `ask-matt`, `grill-with-docs`, `grill-me`, `to-spec`, `to-tickets`, `implement`, `triage`, `wayfinder`, `improve-codebase-architecture`, `setup-matt-pocock-skills`, `handoff`, `teach`, `to-questionnaire` e `wait-what`. As 11 que o autor já deixa ao alcance do agente (`tdd`, `code-review`, `diagnosing-bugs` e as demais) e as experimentais de `skills/in-progress/`, fora do manifesto, ficam como no original.

## Wizard nesta máquina

O script do `wizard` precisa de um terminal com teclado. Em 06/10/2026 (#163) o dono rodou um pelo `!` da sessão e o script passou direto:
- cada `ask` e `confirm` leu vazio, e todas as respostas viraram "não";
- o `open_url` não achou o navegador.

No mesmo teste, o `ENV_FILE="${ENV_FILE:-…}"` escrito depois do marcador não valeu, porque a biblioteca do modelo já define `ENV_FILE=.env` antes dele, e as respostas caíram num `.env` da worktree. Por isso:
- Para passo do dono no painel, o agente leva o Chrome da extensão até a tela que só o dono resolve (chave de acesso, aceite de termos) e pede só aquele clique.
- Script de wizard vai para o dono rodar num terminal dele, fora do Claude Code.
- Num wizard, o `ENV_FILE` se atribui direto, sem `:-`.

**Exceção: wizard cuja única pergunta é um `[y/N]`.** Esse pode ir pelo `!`, com a resposta no pipe: `! yes y | bash <script>`. Antes de entregar, leia cada `read` do script; se houver `ask` ou `ask_secret`, ele vai para o terminal do dono. Foi assim que um passo da #4 rodou em 06/10, na quarta tentativa. As três anteriores esbarraram em armadilhas do Git Bash que valem para todo script com `az`:
- **O Git Bash converte argumento que começa com `/`** em caminho do Windows. O `--scopes /subscriptions/…` do `az ad sp create-for-rbac` virou `C:/Program Files/Git/subscriptions/…`. O Azure criou o app e o service principal, mas recusou o papel com `MissingSubscription`. Prefixe só aquela chamada com `MSYS2_ARG_CONV_EXCL="/subscriptions"`. Não use o `MSYS_NO_PATHCONV=1`, que desliga a conversão de tudo: um `AZURE_CONFIG_DIR=/tmp/…` passaria cru ao `az` e iria parar em `C:\tmp\…`, com o cache de login do service principal.
- **O `-o tsv` de uma lista** (`--query "[appId, password, tenant]"`) **sai com um valor por linha, terminado em `\r\n`.** O `read -r a b c <<< "$saida"` fica só com o primeiro valor, e a senha que o Azure acabou de gerar se perde. Leia linha a linha e tire o `\r`: `… -o tsv | tr -d '\r'`, depois `{ read -r a; read -r b; read -r c; } <<< "$saida"`.
- **Rodar de novo é seguro.** O `create-for-rbac` com o nome de um app que já existe faz o patch, troca o segredo pelo novo e avisa "Role assignment already exists".

## O que o fork muda e o que fica de fora

- Muda só o cabeçalho das 14: sai a trava, entra a descrição em português para o agente. O original traz uma linha para o dono ler no menu de comandos; skill que o agente chama precisa de descrição com os gatilhos, como manda o `SKILL-MECHANICS.md` do `writing-for-agents`, no próprio plugin. O corpo de cada `SKILL.md` é o do autor.
- O resto é cópia fiel da versão registrada em `claude-plugins/mattpocock-skills/origem.json`, com repositório, commit, versão, licença e o hash de cada arquivo: manifesto, licença, `README.md`, `CHANGELOG.md` e skills.
- Fica de fora o que é de quem desenvolve as skills no repositório do autor:
  - o `CLAUDE.md`, o `AGENTS.md` e o `CONTEXT.md` dele. Aqui dentro, o `CLAUDE.md` entraria nas nossas sessões como instrução da pasta, e o `CONTEXT.md` concorreria com o nosso glossário;
  - o ferramental: `docs/`, `scripts/`, `package.json`, CI e changesets.
- Ficam como no original os `agents/openai.yaml`, que são do Codex e o Claude Code não lê, e os `README.md`, que ainda separam "User-invoked" e "Model-invoked" como o autor.

O marketplace de pasta local carrega o plugin no lugar, a cada partida ou `/reload-plugins`, sem subir versão ([doc oficial](https://code.claude.com/docs/en/plugins/loading.md), "In-place and copied plugins"). A cópia que o `install` grava em `~/.claude/plugins/cache/tftec/` é só registro. Por isso o fork vale como está na pasta do checkout principal, que fica na `main`: uma branch trocada ali muda as skills de toda sessão. A faxina semanal (documento fora desta cópia) mostra o fork como "EM DIA ... carrega no lugar".

## Como o dono aplica

Uma vez por máquina, depois do merge. O `!` roda no Git Bash, dentro da sessão.

1. **Checkout principal em dia.** O [retrato da partida](retrato-da-partida.md#avanço-do-checkout-principal) leva o checkout principal até a `origin/main`.
   *Pronto quando:* `C:\Projetos\<projeto>\claude-plugins\mattpocock-skills\origem.json` existe.
2. **Registrar o marketplace, instalar o fork e desligar o oficial.**
   ```bash
   ! claude plugin marketplace add /c/Projetos/<projeto>/claude-plugins
   ! claude plugin install mattpocock-skills@tftec
   ! claude plugin disable mattpocock-skills@claude-plugins-official
   ```
   *Pronto quando:* `! claude plugin list` mostra `mattpocock-skills@tftec` com "enabled" e o oficial com "disabled".
3. **Recarregar.** `/reload-plugins` na sessão aberta; sessão nova já parte com o fork.
   *Pronto quando:* a lista de skills do agente traz `mattpocock-skills:implement` e `mattpocock-skills:wayfinder`, e o contexto do hook `skill-router` não traz mais "Skills reservadas ao dono".

O hook `skill-router` (`~/.claude/hooks/skill-router.mjs`, do dono, fora do repositório) anuncia a cada pedido as skills travadas que acha em `~/.claude/plugins/cache`. A cópia do oficial fica lá depois do `disable`, então desde 01/10 (#132) ele só lê plugin com `true` no `enabledPlugins` do settings do usuário, do projeto e do local. Com o hook de antes, guardado em `skill-router.mjs.bak-2026-10-01`, as 14 continuariam anunciadas como reservadas. Mudar o hook é passo do dono, fora do auto mode (documento de permissões, fora desta cópia: "O agente não altera as próprias permissões").

## Como desfazer

```bash
! claude plugin disable mattpocock-skills@tftec
! claude plugin enable mattpocock-skills@claude-plugins-official
```

Depois, `/reload-plugins`. Para tirar de vez: `! claude plugin uninstall mattpocock-skills@tftec` e `! claude plugin marketplace remove tftec`.

*Pronto quando:* `! claude plugin list` mostra o oficial com "enabled" e o fork desligado ou fora, e o hook volta a listar as 14 como reservadas.

## Mudar a descrição de um fluxo

PR no `SKILL.md` do fork, só no cabeçalho, com a descrição dizendo "Use só quando o dono pedir" e, fora o `ask-matt`, "ou quando o ask-matt indicar este fluxo". Vale depois do merge, quando o checkout principal avança, na próxima sessão ou no `/reload-plugins`. O corpo das skills fica igual ao do autor: o guarda barra mudança nele, e ela se perderia na próxima versão; melhoria no corpo vai como issue ou PR em [mattpocock/skills](https://github.com/mattpocock/skills).

## Trazer uma versão nova do autor

1. **Original.** Uma pasta com a versão nova: o cache do plugin oficial (`~/.claude/plugins/cache/claude-plugins-official/mattpocock-skills/<versão>`), quando já tem a versão, ou um clone de https://github.com/mattpocock/skills. O commit está em `<pasta>/.git/HEAD`, no cache, ou em `<pasta>/.git/refs/heads/main`, num clone.
   *Pronto quando:* a pasta tem `.claude-plugin/plugin.json` com a versão nova, e você tem o commit de 40 caracteres.
2. **Trazer, numa worktree.**
   ```bash
   node scripts/agentes/fork-de-skills.mjs <pasta> <commit>
   ```
   O script troca no fork o que vem do plugin, mantém o nosso cabeçalho nas skills que o original traz travadas e o fork tem destravadas, tira o que o autor removeu e regrava o `origem.json`. Ele para se a licença deixar de ser MIT.
   *Pronto quando:* a saída lista as 14 em "Com o cabeçalho do fork" e nenhuma em "Do manifesto, chegam travadas".
3. **Ler o que mudou.** O diff do `CHANGELOG.md` no próprio PR. Skill nova em "chegam travadas" pode ser fluxo, e destravá-la é decisão do dono; destravada, ela ganha o cabeçalho com a regra e entra em `FLUXOS` no guarda. Campo novo no cabeçalho de um dos 14 no original, como um `argument-hint`, entra à mão, porque o script mantém o nosso cabeçalho inteiro.
   *Pronto quando:* cada skill de "chegam travadas" tem decisão, e o cabeçalho das 14 tem os campos do original.
4. **Conferir e abrir o PR.** `node --test scripts/agentes/*.test.mjs` e `claude plugin validate claude-plugins --strict`.
   *Pronto quando:* os dois passam e o PR cita a versão e o commit novos.

## Guarda

`scripts/agentes/fork-de-skills.test.mjs` (fora desta cópia) falha quando:
- o marketplace deixa de declarar o `mattpocock-skills` com o nome do plugin oficial;
- o `origem.json` perde a origem ou a versão do manifesto;
- a licença MIT do autor sai do fork;
- um arquivo do fork difere do original registrado, ou nas 14 o corpo difere;
- volta a trava numa das 14, ou a descrição perde a regra de uso;
- o script, numa versão nova, perde o nosso cabeçalho ou deixa para trás o que o autor tirou.

Rodar: `node --test scripts/agentes/*.test.mjs`.
