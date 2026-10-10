# Guia do workshop: o dia inteiro, passo a passo

Este é o roteiro do workshop de Claude Code da TFTEC Masters, do começo ao fim, para você **acompanhar no dia e repetir depois na sua máquina**. Cada bloco diz o que acontece, traz os comandos prontos para copiar e aponta onde ler mais.

- **Os conceitos** estão explicados no [guia do aluno](guia/README.md), em partes curtas.
- **Os termos e os caminhos dos arquivos** estão no [glossário e mapa de arquivos](guia/glossario.md).
- **A prática** está nas fichas, em [`exercicios/`](exercicios/).
- **Os slides** estão em `deck/`, e o link do deck publicado fica no [README](README.md).

Os comandos foram conferidos no Claude Code 2.1.296, em 10/10/2026, no Windows com PowerShell 7. Se a sua tela estiver diferente, confira a versão com `claude --version` e o [glossário](guia/glossario.md#leia-mais).

## O dia

| Horário | Bloco | Ler | Praticar |
|---|---|---|---|
| Antes | Instalar e testar o ambiente | — | [Checklist pré-workshop](checklist-pre-workshop.md) |
| 9h00 | Abertura e destravar o checklist | [01](guia/01-o-que-e-o-claude-code.md) | — |
| 9h15 | Onde o Claude Code roda (superfícies) | [01](guia/01-o-que-e-o-claude-code.md) | — |
| 9h30 | Demo 1: primeira sessão | [02](guia/02-sessao-contexto-e-custo.md) | [Ficha 01](exercicios/01-primeira-sessao.md) (opcional) |
| 9h50 | Demo 2: contexto, tokens, modelo e effort | [02](guia/02-sessao-contexto-e-custo.md) | [Ficha 02](exercicios/02-modelo-effort-tokens.md) (opcional) |
| 10h11 | Demo 3: permissões, regras, plan mode e rewind | [03](guia/03-permissoes-plan-mode-e-rewind.md) | [Ficha 03](exercicios/03-permissoes-plan-mode-rewind.md) (opcional) |
| 10h40 | Intervalo | | |
| 10h50 | Demo 4: memória, instruções e onde cada arquivo fica | [04](guia/04-memoria-e-instrucoes.md) e [glossário](guia/glossario.md) | [Ficha 04](exercicios/04-claude-md-e-memoria.md) (opcional) |
| 11h15 | Demo 5: skills, subagentes e plugins | [05](guia/05-skills-plugins-mcp-e-hooks.md) | [Ficha 05](exercicios/05-plugins-e-skills.md) (opcional) |
| 11h45 | Demos 6 e 7: MCP e hooks | [05](guia/05-skills-plugins-mcp-e-hooks.md) | [Ficha 06](exercicios/06-mcps.md) (opcional) |
| 12h00 | Almoço | | |
| 13h30 | Peças soltas → receita pronta: como organizar o trabalho | [06](guia/06-formato-de-trabalho.md) | — |
| 14h00 | Hook-freio: o Claude nunca escreve no Azure | [05](guia/05-skills-plugins-mcp-e-hooks.md#hooks) e [07](guia/07-o-projeto-da-turma.md) | [Ficha 07](exercicios/07-hook-freio.md) |
| 14h20 | `grill-with-docs` ao vivo sobre o relatório FinOps | [06](guia/06-formato-de-trabalho.md) | — |
| 14h50 | `to-spec` e `to-tickets` | [06](guia/06-formato-de-trabalho.md) | — |
| 15h10 | Intervalo | | |
| 15h20 | Implementar em paralelo | [06](guia/06-formato-de-trabalho.md) e [07](guia/07-o-projeto-da-turma.md) | [Ficha 08](exercicios/08-implementar-em-paralelo.md) |
| 16h20 | Rodar no seu ambiente e revisar | [07](guia/07-o-projeto-da-turma.md) | [Ficha 09](exercicios/09-rodar-e-revisar.md) |
| 16h40 | Automação e encerramento | [08](guia/08-proximos-passos.md) | — |

**De manhã**, o instrutor demonstra cada funcionalidade num projeto neutro, sem ligação com o relatório FinOps. Acompanhe na sua máquina se quiser, ou só assista e repita depois com este guia. **À tarde**, a turma constrói o relatório FinOps com as fichas 07, 08 e 09.

---

## Manhã: como cada funcionalidade funciona

### Monte a pasta da demo (para repetir em casa)

As demos usam uma pasta neutra, `C:\demo\manha`, com um script que mostra o uso de disco de cada servidor e tem **um bug de propósito**: uma divisão por zero. No PowerShell 7 (`pwsh`), cole os blocos na ordem.

**1. O projeto:**

```powershell
New-Item -ItemType Directory -Force C:\demo\manha | Out-Null
Set-Location C:\demo\manha

@'
# Inventário de servidores (projeto de demonstração)

Um script que lê `servidores.csv` e mostra o uso de disco de cada servidor.
'@ | Set-Content -Encoding utf8 README.md

@'
nome,disco_total_gb,disco_usado_gb
srv-web-01,128,96
srv-app-01,256,120
srv-bkp-01,0,0
srv-db-01,512,470
'@ | Set-Content -Encoding utf8 servidores.csv

@'
# Mostra o percentual de uso de disco de cada servidor do CSV.
$servidores = Import-Csv (Join-Path $PSScriptRoot 'servidores.csv')
foreach ($s in $servidores) {
    $percentual = [int]$s.disco_usado_gb / [int]$s.disco_total_gb * 100
    '{0}: {1:N0}% do disco em uso' -f $s.nome, $percentual
}
'@ | Set-Content -Encoding utf8 uso-de-disco.ps1

'SENHA_DO_BANCO=isto-nao-e-uma-senha-real' | Set-Content -Encoding utf8 .env
'CLAUDE.local.md', '.env', '.claude/settings.local.json' | Set-Content -Encoding utf8 .gitignore
```

**2. As instruções da demo 4** (o `CLAUDE.md`, um `AGENTS.md` e uma regra que só vale para `.ps1`):

```powershell
@'
<!-- Nota para humanos: este comentário não entra no contexto do Claude. A palavra secreta é abacaxi. -->
# Inventário de servidores

- Responda em português, com frases curtas.
- Quando mostrar um comando, use a sintaxe do PowerShell 7.
'@ | Set-Content -Encoding utf8 CLAUDE.md

@'
# Inventário de servidores (instruções para outros agentes)

- Responda em português.
- Termine cada resposta com uma linha só com o texto (AGENTS.md carregado).
'@ | Set-Content -Encoding utf8 AGENTS.md

New-Item -ItemType Directory -Force .claude\rules, .claude\hooks | Out-Null
@'
---
paths:
  - "**/*.ps1"
---

# Convenções de PowerShell

- Use verbos aprovados do PowerShell (Get-, Set-, New-).
- Comece todo script com Set-StrictMode -Version Latest.
'@ | Set-Content -Encoding utf8 .claude\rules\powershell.md
```

**3. O script do hook da demo 7:**

```powershell
@'
# PreToolUse: barra "rm -rf" pedido pelo Claude. Lê do stdin o JSON da chamada.
$entrada = [Console]::In.ReadToEnd() | ConvertFrom-Json
$comando = $entrada.tool_input.command
if ($comando -match 'rm\s+-rf') {
    [Console]::Error.WriteLine("Bloqueado pelo hook: 'rm -rf' não é permitido neste projeto.")
    exit 2
}
exit 0
'@ | Set-Content -Encoding utf8 .claude\hooks\bloqueia-rm.ps1
```

**4. Guarde no Git**, para o rewind e o `git status` das demos:

```powershell
git init -q
git add .
git commit -q -m "projeto de demonstração"
```

**5. Abra o projeto:** `code C:\demo\manha`, e rode o `claude` no **terminal integrado** do VS Code. Na primeira vez, responda **sim** à pergunta de confiança da pasta. Deixe um segundo terminal PowerShell aberto na mesma pasta: alguns passos rodam nele.

> Se algo sair do lugar entre as demos, no segundo terminal: `git restore .`, apague os arquivos novos que sobrarem e confira com `git status`.

### 9h15 · Onde o Claude Code roda

O Claude Code é um motor só, em cinco **superfícies**: o terminal (`claude`), o app desktop (`/desktop` leva a sessão do terminal para lá), a web (claude.ai/code, que roda na nuvem), o celular (app Claude, ou o `/remote-control` para comandar a sessão da sua máquina) e o VS Code. O que muda é **onde o código roda**: na sua máquina ou na nuvem. No workshop, o editor é o VS Code, com o `claude` no terminal integrado.

Leia mais: [parte 01](guia/01-o-que-e-o-claude-code.md#as-superfícies).

### 9h30 · Demo 1: primeira sessão

**O que você vai ver:** os quatro gestos de uma sessão, que são pedir, apontar um arquivo, rodar um comando e mostrar um erro.

1. Abra o `claude`. Repare no topo da tela (modelo e effort) e na linha embaixo do campo (`⏵⏵ auto mode on`).
2. Peça em linguagem natural:

   ```text
   Resuma o README deste projeto em 3 tópicos.
   ```

3. Aponte um arquivo com `@` (digite `@serv` e Tab para completar):

   ```text
   @servidores.csv Qual servidor tem o maior percentual de disco usado?
   ```

4. Rode um comando direto, sem passar pelo Claude:

   ```text
   !git log --oneline -3
   ```

   No Windows, o `!` roda no Git Bash: `!git status` funciona, e `!Get-ChildItem` não.
5. Mostre um erro: no segundo terminal, `pwsh -File .\uso-de-disco.ps1`. Tire um print do erro (Win+Shift+S), volte ao Claude e cole com **Alt+V**:

   ```text
   Explique este erro em linguagem simples e diga qual linha do CSV provoca. Não altere nada.
   ```

   Se colar a imagem falhar, rode `!pwsh -File uso-de-disco.ps1`: a saída entra na conversa.
6. Rode `/clear` e pergunte `O que eu te pedi antes desta mensagem?`. Ele não sabe: o `/clear` começa uma conversa nova. Para voltar, `/resume`.

**Repare:** cada linha que aparece na tela é uma ferramenta que o Claude escolheu usar.

### 9h50 · Demo 2: contexto, tokens, modelo e effort

**O que você vai ver:** o que gasta tokens e como escolher o modelo e o effort.

1. `/clear` e `/context`: a grade mostra o que já ocupa o contexto antes de você dizer qualquer coisa.
2. `/model` sozinho mostra a lista (feche com **Esc**). `/effort status` mostra o nível atual.
3. **Rodada A**, modelo pequeno e effort baixo:

   ```text
   /model haiku
   ```

   ```text
   /effort low
   ```

   ```text
   Leia @uso-de-disco.ps1 e @servidores.csv. Em até 4 linhas: o que o script faz, qual é o bug e qual linha do CSV o provoca. Não altere nada.
   ```

   Rode `/context` e `/usage`. O valor em dólar do `/usage` é uma estimativa a preço de API: no plano de assinatura, você não paga esse valor; o que conta são as barras de uso.
4. **Rodada B**, modelo grande e effort alto: `/clear`, `/model opus`, `/effort high`, a mesma pergunta, `/context` e `/usage`. Compare o tempo e os tokens.
5. `/compact` e depois `/context`: a conversa vira um resumo. O `/compact` mantém o fio, mas também gasta; o `/clear` não gasta nada e começa do zero.
6. **Volte ao padrão.** O `/model` e o `/effort` digitados ficam salvos para as próximas sessões:

   ```text
   /effort auto
   ```

   ```text
   /model default
   ```

> **`/fast`:** existe um modo de resposta mais rápida, que usa créditos de uso extra. No workshop ele não é demonstrado. Cuidado com o atalho **Alt+O**, que liga e desliga esse modo.

### 10h11 · Demo 3: permissões, regras, plan mode e rewind

**O que você vai ver:** quanto o Claude faz sozinho, o que ele nunca faz, como planejar antes de editar e como desfazer.

1. `!git status` precisa estar limpo. Com o campo vazio, aperte **Shift+Tab** devagar e leia a linha embaixo do campo: `auto mode on` → `manual mode on` → `accept edits on` → `plan mode on`. No Windows, se o Shift+Tab não funcionar, tente **Alt+M**.
2. No **plan mode**:

   ```text
   Planeje corrigir a divisão por zero em @uso-de-disco.ps1: pule o servidor com disco 0 e avise qual foi pulado com Write-Warning.
   ```

   Ele lê e planeja, mas não edita. No fim, escolha **Yes, manually approve edits**.
3. Na primeira proposta de edição, escolha **No**, aperte **Tab** e escreva `Antes de editar, explique em uma frase o que muda.` Ele recebe o motivo e segue. Aprove a próxima.
4. Teste: `!pwsh -File uso-de-disco.ps1`. O erro some, e aparece o aviso do `srv-bkp-01`.
5. **O limite do rewind.** Peça:

   ```text
   Crie uma cópia de uso-de-disco.ps1 chamada copia.ps1 usando um comando de terminal (Copy-Item ou cp), não a ferramenta de edição.
   ```

6. Com o campo **vazio**, **Esc Esc** (ou `/rewind`), escolha a mensagem do plano e **Restore code**. Depois `!git status`: o script voltou, mas a `copia.ps1` **continua lá**. O rewind só desfaz o que o Claude editou com as ferramentas de arquivo; para guardar versão de verdade, use o Git.
7. Limpe: `!rm copia.ps1`. Volte com Shift+Tab até `⏵⏵ auto mode on`.
8. **Regra `deny`: o "nunca" que vale em qualquer modo.** No segundo terminal, crie uma regra só sua, neste projeto:

   ```powershell
   @'
   {
     "permissions": {
       "deny": ["Read(./.env)"]
     }
   }
   '@ | Set-Content -Encoding utf8 .claude\settings.local.json
   ```

   No Claude, `/permissions` mostra a regra e de qual arquivo ela veio. Depois peça:

   ```text
   Leia o arquivo .env com a ferramenta de leitura de arquivo e me diga quais variáveis ele tem.
   ```

   É barrado. Peça também `Rode no terminal: Get-Content .env`: também é barrado. Agora crie, no segundo terminal, um script que lê o `.env` por dentro:

   ```powershell
   "Get-Content (Join-Path `$PSScriptRoot '.env')" | Set-Content -Encoding utf8 leitor.ps1
   ```

   E peça `Rode no terminal: pwsh -NoProfile -File ./leitor.ps1`. **Passa.** A regra vê a chamada, não o que o script faz por dentro. Para o que nunca pode acontecer, use três proteções: permissão mínima, regra `deny` e hook.
9. Limpe: `Remove-Item .claude\settings.local.json, leitor.ps1` no segundo terminal.

### 10h50 · Demo 4: memória, instruções e onde cada arquivo fica

**O que você vai ver:** o que o Claude carrega de instrução, quando, onde cada arquivo fica e como editar.

1. `/exit` e `claude` de novo. Rode `/context` e veja a lista **Memory files** (se não aparecer, `/context all`): o `CLAUDE.md` está lá; o `AGENTS.md` e a regra de `.ps1` **não**.
2. **Comentário HTML não gasta contexto.** Pergunte:

   ```text
   Sem abrir nenhum arquivo: qual é a palavra secreta das suas instruções de projeto?
   ```

   Ele não sabe: o comentário `<!-- ... -->` é removido antes de entrar no contexto.
3. **`CLAUDE.local.md`, só seu:**

   ```text
   !echo "- Me chame pelo meu nome, Ana, nas respostas." > CLAUDE.local.md
   ```

   (Troque Ana pelo seu nome.) `/exit`, `claude`, `/context`: ele aparece em Memory files. Mande `oi` e veja o efeito. O `.gitignore` o deixa fora do Git.
4. **`AGENTS.md`.** No padrão, o Claude Code só lê o `AGENTS.md` quando não há `CLAUDE.md`. Rode `/config`, digite `instructions`, vá até **Project instructions** e escolha `claude-md-and-agents-md`. Mande `oi de novo`: a resposta termina com `(AGENTS.md carregado)`.
5. **Volte ao padrão. Não pule:** essa opção vale para **todos** os seus projetos. `/config`, **Project instructions**, `claude-md-or-agents-md`. Para um arquivo só servir a todos os agentes, o caminho é pôr `@AGENTS.md` dentro do `CLAUDE.md`.
6. **Onde cada coisa fica e como editar.** `/memory` lista os arquivos de instrução e abre no editor o que você escolher. No segundo terminal, `code $HOME\.claude` mostra a sua pasta de usuário: `settings.json`, `skills\`, `agents\`, `projects\` (histórico e memória automática). A regra de bolso:
   - `.claude\` dentro do projeto é da equipe e vai para o git;
   - `~\.claude\` é seu, em todos os projetos;
   - os arquivos com `.local` são seus, só neste projeto, e ficam no `.gitignore`.

   O mapa completo está no [glossário](guia/glossario.md#onde-cada-coisa-fica). Num projeto sem `CLAUDE.md`, o **`/init`** lê o código e escreve o primeiro rascunho: revise antes de commitar.
7. **Regra com `paths`.** Peça `Leia uso-de-disco.ps1 e diga que convenções de PowerShell você seguiria ao editá-lo.` Ele cita `Set-StrictMode` e os verbos aprovados: a regra só entrou porque o trabalho tocou num `.ps1`.
8. Limpe: `!rm CLAUDE.local.md`.

**Repare:** `CLAUDE.md` e regras são **pedidos**. Quem **impede** é a regra `deny` e o hook.

### 11h15 · Demo 5: skills, subagentes e plugins

**O que você vai ver:** a diferença entre skill, subagente e plugin, e quanto cada um pesa.

1. **O peso de um plugin.** No Claude:

   ```text
   /plugin install mattpocock-skills@claude-plugins-official
   ```

   Abre o detalhe do plugin, com a seção **Context cost**: **Every turn** (o que ele soma a toda mensagem) e **When invoked** (quando uma peça dele roda). Se só quiser olhar, feche com **Esc** antes de escolher o escopo. Depois de instalado, no terminal, `claude plugin details mattpocock-skills` mostra o **Projected token cost** e uma tabela por componente.
2. **Crie uma skill.** No segundo terminal:

   ```powershell
   New-Item -ItemType Directory -Force .claude\skills\gerar-runbook | Out-Null
   @'
   ---
   name: gerar-runbook
   description: Gera um runbook de troubleshooting em markdown para um serviço Azure. Use quando pedirem um runbook ou um passo a passo de diagnóstico.
   ---

   Escreva um runbook de troubleshooting em markdown para este serviço Azure: $ARGUMENTS
   Use as seções: sintomas, primeiras verificações, causas comuns, correção e quando escalar.
   Não execute nenhum comando.
   '@ | Set-Content -Encoding utf8 .claude\skills\gerar-runbook\SKILL.md
   ```

   No Claude, `/reload-skills` (a pasta foi criada no meio da sessão) e:

   ```text
   /gerar-runbook Azure App Service
   ```

3. **Crie um subagente.** A skill roda na sua conversa; o subagente roda numa janela própria e devolve só o resultado. No segundo terminal:

   ```powershell
   New-Item -ItemType Directory -Force .claude\agents | Out-Null
   @'
   ---
   name: revisor-de-script
   description: Revisa scripts PowerShell e Bash de infra atrás de riscos. Use depois de criar ou alterar um script.
   tools: Read, Grep, Glob
   model: haiku
   ---

   Você revisa scripts de infraestrutura. Não altere nenhum arquivo.
   Para cada script, aponte: comandos que apagam ou alteram recursos, segredos escritos no código e falta de tratamento de erro.
   Devolva uma tabela com arquivo, linha, risco e sugestão. Termine com um veredito: pode rodar, ajustar antes ou não rodar.
   '@ | Set-Content -Encoding utf8 .claude\agents\revisor-de-script.md
   ```

   Como a pasta `.claude\agents` é nova, `/exit` e `claude`. O `/agents` hoje só lembra onde os arquivos ficam; ele não cria nem lista. Peça:

   ```text
   Use o subagente revisor-de-script para revisar uso-de-disco.ps1.
   ```

   Só a tabela volta para a conversa: os arquivos que ele leu ficaram na janela dele. Para garantir que ele rode, mencione com `@agent-revisor-de-script`.
4. `/skills` e a tecla **t** ordenam as skills por tokens.
5. Limpe: apague as pastas `.claude\skills\gerar-runbook` e `.claude\agents`.

**Repare:** o subagente economiza o seu **contexto**, mas os tokens dele contam no mesmo limite de uso.

### 11h45 · Demos 6 e 7: MCP e hooks

**MCP: um conector.** O servidor MCP do Microsoft Learn não pede login e busca na documentação oficial da Microsoft. No segundo terminal:

```powershell
claude mcp add --transport http microsoft-learn https://learn.microsoft.com/api/mcp
claude mcp list
```

`/exit` e `claude` para enxergar o servidor novo. `/mcp` mostra as ferramentas dele. Pergunte:

```text
Usando o MCP microsoft-learn, como acompanho o uso de disco de uma VM Linux no Azure pelo Azure Monitor? Cite os links da documentação oficial.
```

Para remover: `claude mcp remove microsoft-learn -s local`. O Azure MCP, que lê os recursos da sua subscription, está no [guia 05](guia/05-skills-plugins-mcp-e-hooks.md#mcp) e na [ficha 06](exercicios/06-mcps.md): ligue-o **sempre com `--read-only`**.

**Hook: o impedimento de verdade.** O script `.claude\hooks\bloqueia-rm.ps1` do preparo lê o comando e sai com **exit 2** se ele tiver `rm -rf`. Registre no segundo terminal:

```powershell
@'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|PowerShell",
        "hooks": [
          {
            "type": "command",
            "command": "pwsh",
            "args": ["-NoProfile", "-File", "${CLAUDE_PROJECT_DIR}/.claude/hooks/bloqueia-rm.ps1"]
          }
        ]
      }
    ]
  }
}
'@ | Set-Content -Encoding utf8 .claude\settings.json
```

No Claude, `/hooks` mostra o hook em `PreToolUse`. Teste `Rode no terminal: rm -rf ./pasta-que-nao-existe`: o hook barra **antes** de rodar, e o Claude mostra o motivo. Depois `Rode no terminal: git status`: passa normalmente. Limpe: `Remove-Item .claude\settings.json`.

**Repare:** o evento (`PreToolUse`, antes de cada ferramenta), o matcher (`Bash|PowerShell`, porque no Windows o Claude usa a ferramenta PowerShell) e o **exit 2**: com exit 1, o comando segue. À tarde, o hook-freio usa a mesma ideia para barrar qualquer escrita no Azure.

---

## Tarde: o formato enxuto e o relatório FinOps

O projeto da turma é um **relatório FinOps** em PowerShell 7 que lê uma subscription Azure, **sem alterar nada**, e aponta oportunidades de economia. A spec e os tickets prontos estão em [`.scratch/relatorio-finops/`](.scratch/relatorio-finops/), e o vocabulário no [`CONTEXT.md`](CONTEXT.md). Sem acesso a uma subscription, use os dados fictícios de [`dados-ficticios/`](dados-ficticios/).

| Horário | O que acontece | Você faz |
|---|---|---|
| 13h30 | O eixo "peças soltas → receita pronta": do Claude Code puro aos frameworks, e o formato enxuto (skills do Matt Pocock e o processo no repositório) | Assiste. Leia a [parte 06](guia/06-formato-de-trabalho.md) |
| 14h00 | **Hook-freio:** o Claude cria, com você, um hook que barra qualquer comando de escrita no Azure. Você vê o bloqueio acontecer e confere que a leitura passa | [Ficha 07](exercicios/07-hook-freio.md) |
| 14h20 | `grill-with-docs` ao vivo: o instrutor afia a ideia do relatório numa entrevista, e o glossário (`CONTEXT.md`) nasce dela | Assiste |
| 14h50 | `to-spec` e `to-tickets`: a conversa vira spec e tickets com as dependências. Os tickets da turma já estão prontos no repositório | Assiste |
| 15h10 | Intervalo | |
| 15h20 | **Implementar em paralelo:** o motor e a primeira regra numa sessão normal; depois vários tickets ao mesmo tempo, cada um na sua worktree (`claude -w`) ou numa sessão em segundo plano (`claude agents`); no fim, juntar tudo na `main` | [Ficha 08](exercicios/08-implementar-em-paralelo.md) |
| 16h20 | **Rodar no seu ambiente:** o relatório na sua subscription, a versão anonimizada para mostrar na empresa e a revisão com `/mattpocock-skills:code-review` | [Ficha 09](exercicios/09-rodar-e-revisar.md) |
| 16h40 | Automação (`claude -p`, `/loop`, `/schedule`, GitHub Actions) e encerramento | Leia a [parte 08](guia/08-proximos-passos.md) |

**A ordem importa:** primeiro o freio (ficha 07), **depois** qualquer comando que toque no Azure. E faça commit do freio antes da ficha 08: as worktrees nascem do que está em commit.

Travou? Compare com a branch `gabarito`, que tem o relatório completo e o hook-freio:

```powershell
git fetch origin gabarito
git diff main origin/gabarito --stat
```

---

## Depois do workshop

1. **Repita a manhã** com a pasta da demo e as seções acima, no seu ritmo. As fichas [01 a 06](exercicios/) são a prática opcional de cada bloco.
2. **Termine o relatório:** os tickets que faltarem, o custo real e uma regra FinOps sua.
3. **Escreva o `CLAUDE.md` do seu projeto real**, ou comece com `/init`, e confira no `/context` o que carregou.
4. **Crie um hook para o seu risco:** um freio para `kubectl delete`, `terraform destroy` ou `DROP TABLE`.
5. **Automatize algo pequeno:** um `claude -p` num script, ou um `/loop` vigiando um deploy ([parte 08](guia/08-proximos-passos.md)).

## Se travar

| Sintoma | O que fazer |
|---|---|
| `claude` não é reconhecido | Feche e abra o terminal (ou o VS Code) para ler o PATH novo. `claude doctor` mostra o diagnóstico |
| O `!` não funciona | No VS Code, use o `claude` no terminal integrado: a extensão não tem o `!` |
| A skill nova não aparece | `/reload-skills`, e confira o caminho `.claude\skills\<nome>\SKILL.md` com a primeira linha `---` |
| O subagente novo não é chamado | Se a pasta `.claude\agents` foi criada no meio da sessão, `/exit` e `claude`. Mencione com `@agent-<nome>` |
| O hook não barra | Confira se o `pwsh` está no PATH (sem ele, o hook dá erro **e não bloqueia**), se o matcher inclui `PowerShell` e se você aceitou a confiança da pasta |
| Uma regra de comando não pega no Windows | No Windows, use `PowerShell(...)`, não `Bash(...)`. Um `deny` de `Bash(...)` desliga a ferramenta PowerShell |
| `claude --bg` recusa a pasta | `Workspace not trusted`: rode `claude` uma vez na raiz do repositório e aceite a pergunta de confiança |
| Bateu no limite de uso | O Claude Code espera o limite voltar sozinho; **Esc** cancela a espera. Use `/model` com um modelo menor e `/clear` entre assuntos |

Para tudo o mais: o [glossário](guia/glossario.md), o [guia](guia/README.md) e a documentação oficial em https://code.claude.com/docs. Dentro do Claude Code, `/help` lista os comandos, e você pode simplesmente perguntar: "como eu faço X no Claude Code?".
