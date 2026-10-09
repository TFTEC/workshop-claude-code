# Retrato da partida

Toda sessão do Claude Code neste repositório começa com um retrato do estado real, calculado na hora (#79, spec #76). O hook `SessionStart` de [`.claude/settings.json`](../../.claude.exemplo/settings.json) roda [`scripts/agentes/retrato-da-partida.mjs`](../../scripts/agentes/retrato-da-partida.mjs), e o que ele imprime entra no contexto da sessão antes da primeira resposta. O texto não aparece como mensagem no chat: chega à sessão como lembrete de sistema.

O hook dispara com `matcher` `startup|resume|clear`: sessão nova, `--resume`/`--continue`/`/resume` e `/clear`. Compactação e fork ficam de fora (a sessão já recebeu o retrato naquela conversa). Ele roda na forma exec (`"command": "node"` com o caminho em `args`), que a doc oficial recomenda quando há `${CLAUDE_PROJECT_DIR}` no caminho.

## Como agir sobre o retrato

Leia o retrato antes do primeiro passo do pedido. A seção "Atenção", logo depois do Git, junta o que pede ação agora; ela vem cedo para o corte de tamanho nunca alcançá-la. Cada marca tem uma ação:

| No retrato | O que fazer |
|---|---|
| "Esta worktree está N commits atrás da origin/main, com regra velha" (Atenção) e "A main mudou regra..." (Git) | O `CLAUDE.md` ou o doc de processo que a sessão carregou está velho. Comece o trabalho numa worktree nova criada da `main` atualizada; se precisar continuar nesta, leia a versão da `origin/main` dos arquivos listados (`git show origin/main:CLAUDE.md`). |
| "main local: N commits atrás da origin/main" | A partida já tenta [avançar o checkout principal](#avanço-do-checkout-principal) sozinha; a `main` local só fica atrás quando o avanço não rodou, e então a Atenção traz a linha "checkout principal ... não atualizado". O comando manual só vale nesse caso: o dono roda o `git pull --ff-only` num terminal fora do Claude Code ou no `!` de uma sessão aberta no checkout principal; pelo `!` de sessão isolada em worktree o guarda recusa ([Comando que o dono roda com `!`](coordenacao-de-sessoes.md#comando-que-o-dono-roda-com-)). |
| "checkout principal atualizado de `<de>` para `<para>`" (Git) | Nada a fazer. As regras novas (`CLAUDE.md`, hooks, docs de processo) valem para as sessões que partirem no checkout principal daqui em diante. Se esta sessão roda nele, ela carregou as de antes: leia os arquivos de regra que mudaram ou abra uma sessão nova. |
| "checkout principal N commits atrás da origin/main e não atualizado: ..." (Atenção) | Nada mudou no checkout principal. Entregue ao dono o comando do fim da linha, que o motivo escolhe ([motivos](#avanço-do-checkout-principal)). Com o motivo "trava", outra sessão partindo junto costuma estar avançando: a próxima partida confere de novo. |
| Issue em "Issues em andamento" | Outra sessão está nela. Escolha outra issue ou combine com o dono. |
| PR aberto há dias | Avise o dono: mesclar é decisão dele. |
| `[PARADA esperando ...]` (Atenção) | A sessão espera o dono (pedido de permissão, diálogo). Diga ao dono qual é, pelo nome. |
| `[PASTA QUE JÁ NÃO É WORKTREE]` (Atenção) | A sessão roda num resto de faxina. Sugira ao dono encerrá-la. |
| `TRAVADA (...)` numa worktree | Uma sessão ou subagente segura a worktree; o motivo diz qual. |
| "GitHub indisponível" ou "A origin/main não foi atualizada agora" | Sem rede, sem `gh` autenticado, ou outra sessão atualizando a `origin/main` no mesmo instante. O resto do retrato vale, com a `origin/main` da última cópia baixada. |
| "git não respondeu: ..." | O git falhou ou travou; worktrees e sessões ficaram de fora. Rode `git status` para ver o motivo. |
| "retrato parcial (tempo esgotado)" | Uma coleta passou do prazo de 20 s e ficou de fora. Rode o script à mão se precisar dela. |
| "N arquivos de sessão ilegíveis" | Arquivo de sessão corrompido ou em formato novo; aquelas sessões ficaram de fora da lista. |

## O que o retrato junta

- **Git** (`retrato/coleta-git.mjs`): `git fetch origin main`, o [avanço do checkout principal](#avanço-do-checkout-principal) (`retrato/avanco-do-principal.mjs`) e depois a `main` local, a worktree da sessão e cada worktree de `git worktree list` contra a `origin/main`. Quando a worktree da sessão está atrás, lista o que a `main` mudou desde que a branch saiu em `CLAUDE.md`, `CONTEXT.md`, `docs/agents/` e `.claude/`. Separa "pasta sem repositório" de "git falhou ou travou".
- **GitHub** (`retrato/github.mjs`): `gh pr list --state open` e `gh issue list --label em-andamento`, com os comentários da issue. A linha "Assumida:" é a primeira linha do último comentário com "assumiu". Resposta que não é JSON vira "GitHub indisponível". O `gh` desiste em 10 s.
- **Sessões** (`retrato/coleta-sessoes.mjs`): os `<pid>.json` de `~/.claude/sessions/` (ou `$CLAUDE_CONFIG_DIR/sessions/`). Conta só processo vivo e ignora a sessão reserva (`spare`). Os `.key` da mesma pasta são segredo e ficam fechados. Sessão de outro projeto vira só uma contagem; arquivo ilegível também.
- **Formatação** (`retrato/formato.mjs`): não lê nada; recebe o que as coletas juntaram.

## Efeitos na partida

O retrato escreve em dois lugares, e só neles: a `origin/main` (pelo fetch) e o checkout principal (pelo avanço). O resto só lê.

### Fetch da origin/main

O `git fetch` é uma escolha: sem ele, a comparação seria contra a `origin/main` da última vez que alguém baixou, e o retrato deixaria de ser da hora. Escreve só em `origin/main` e `FETCH_HEAD`. Roda com `--no-auto-maintenance` (nenhuma manutenção do repositório dispara na partida), sem pedir senha (`GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE=never`) e desiste em 10 s. Se duas sessões partirem juntas, uma delas encontra a ref travada pela outra e mostra "A origin/main não foi atualizada agora".

### Avanço do checkout principal

Desde o #96 o dono não precisa rodar `git pull` no checkout principal (`C:\Projetos\<projeto>`): depois do fetch, a partida o leva até a `origin/main`. O checkout principal é a primeira entrada de `git worktree list`, então isso vale com a sessão partindo nele ou numa worktree. O único comando que escreve é `git merge --ff-only --no-autostash` do commit da `origin/main` que acabou de ser conferido, e ele só roda quando:

- o fetch da partida deu certo;
- o checkout principal está na branch `main`;
- a `main` local não tem commit que a `origin/main` não tem;
- nenhum arquivo rastreado tem mudança, no stage ou fora dele (`git status --porcelain --untracked-files=no` vazio, lido com `--no-optional-locks` para não disputar a trava com um git do dono);
- faltam pelo menos 5 s para o fim do prazo global, porque o retrato não interrompe o merge (ver **Tempo**, abaixo).

Arquivo não rastreado, como o `.claude/settings.local.json`, não impede: se o merge fosse sobrescrever um, o próprio git recusa e nada muda. O avanço nunca roda `reset`, `checkout`, `switch`, `stash`, `clean` nem `--force`, e o `--no-autostash` barra o stash automático mesmo com `merge.autoStash` ligado.

Quando avança, a seção Git diz "checkout principal atualizado de `<de>` para `<para>` (regras novas valem na próxima sessão)". Quando o checkout principal está atrás e não avança, a Atenção diz "checkout principal N commits atrás da origin/main e não atualizado", com o motivo e o comando para o dono rodar num terminal fora do Claude Code ou no `!` de uma sessão aberta no checkout principal:

| Motivo | Comando no fim da linha |
|---|---|
| o fetch da partida falhou; tem mudança sem commit em N arquivos rastreados; o git recusou, porque sobrescreveria um arquivo não rastreado (com o nome); faltou tempo no prazo; o git falhou | `cd /c/Projetos/<projeto> && git pull --ff-only` |
| está na branch X (ou com o HEAD destacado), não na main | `cd /c/Projetos/<projeto> && git switch main && git pull --ff-only` |
| a main local tem N commits que a origin/main não tem | `cd /c/Projetos/<projeto> && git log --oneline origin/main..main`, para ver os commits só locais antes de decidir |
| outro git segura a trava do repositório, talvez outra sessão atualizando agora | o mesmo `git pull --ff-only`, só se a linha voltar na próxima partida |

Duas sessões partindo juntas: uma avança; a outra esbarra na trava do git (da ref no fetch, ou do índice no merge), relata a trava e sai com código 0. Só diz "atualizado" quem moveu o HEAD: o texto sai do "Updating <de>..<para>" do próprio git, e um "Already up to date" não é relatado. Mudança em arquivo rastreado vista com o `index.lock` de outro git presente, ou com o HEAD andando durante a leitura, é o merge da outra sessão pela metade, e sai como trava.

Limites que o script garante:

- **Tempo**: prazo global de 20 s, abaixo dos 30 s do `timeout` do hook. Nenhum `git` ou `gh` passa do prazo; o que não terminou sai como "retrato parcial (tempo esgotado)", e o script encerra assim que entrega o texto. A exceção é o merge do avanço, que o retrato não interrompe (um merge interrompido deixa o checkout pela metade e o `index.lock` para trás): ele não tem timeout, só começa com 5 s de folga, e se ainda estiver rodando no fim do prazo o texto sai na hora e o processo espera o merge terminar antes de sair, até 28 s desde a partida. A espera é do processo, não do texto: sair antes mataria o merge, porque no Windows o processo filho morre com o script, até com `detached` (medido em 29/09/2026). Um merge que passasse de 28 s morreria de qualquer forma aos 30 s, quando o hook mata o script. Tempo medido em 29/09/2026: cerca de 2 s.
- **Tamanho**: saída abaixo de 10 mil caracteres (acima disso o Claude Code troca o texto por um arquivo que a sessão não é obrigada a ler), com teto por lista, "… e mais N" e corte final em 9.500 caracteres.
- **Segredo**: token do GitHub, da Meta, JWT, `sk-`, `sig=` de SAS e credencial em URL saem como "[segredo redigido]"; e-mail sai como "[e-mail redigido]". Vale também para o texto de falha.
- **Partida**: qualquer falha vira uma linha no retrato e o código de saída é sempre 0; o retrato nunca impede a sessão de começar.

## Rodar à mão e testar

```bash
node scripts/agentes/retrato-da-partida.mjs
RETRATO_SEM_AVANCO=1 node scripts/agentes/retrato-da-partida.mjs
node --test scripts/agentes/*.test.mjs
```

A primeira linha faz o mesmo que uma partida, o avanço do checkout principal inclusive. A segunda só lê: confere as condições do avanço e não roda o merge.

O teste roda o script como processo contra um repositório git temporário (uma `origin` bare, a `main` local atrás, uma worktree atrás) e troca as fontes externas por variáveis de ambiente. Esse mundo compartilhado roda com o avanço desligado; cada teste do avanço monta o próprio e confere que nada muda no checkout principal (HEAD, branch, status com os não rastreados, mudanças no stage e fora dele, stash) quando ele não deve avançar:

| Variável | Troca |
|---|---|
| `RETRATO_GITHUB_FIXTURE` | O `gh` por um JSON `{ "prs": ..., "issues": ... }`: lista no formato do `gh ... --json`, texto para simular a saída crua (ex.: JSON quebrado), ou `{ "erro": "motivo" }` para simular o GitHub fora do ar |
| `RETRATO_PASTA_SESSOES` | A pasta dos arquivos de sessão |
| `RETRATO_AGORA` | O relógio (data ISO), para as idades saírem fixas |
| `RETRATO_GIT_TIMEOUT_MS` | O tempo de cada comando git (valor baixo simula git travado) |
| `RETRATO_PRAZO_MS` | O prazo global de 20 s (valor baixo simula o prazo estourado) |
| `RETRATO_SEM_AVANCO` | Qualquer valor desliga o merge do avanço: as condições são conferidas, e a Atenção diz "avanço desligado por RETRATO_SEM_AVANCO" |

O guarda `scripts/agentes/guarda-docs.test.mjs` falha se o hook `SessionStart` de `.claude/settings.json` deixar de chamar `scripts/agentes/retrato-da-partida.mjs`, se esse script sumir, ou se o arquivo ganhar chave de permissão (`permissions`, `autoMode`, `defaultMode` e as demais da lista no guarda): permissão mora no settings do usuário (spec #76). Outras configurações de projeto, como `worktree.baseRef`, podem entrar.

## Como desligar

A doc oficial não tem como desligar um hook só; o desligamento vale para todos os hooks do escopo escolhido (https://code.claude.com/docs/en/hooks.md, "Disable or remove hooks"):

- **Uma sessão**: `claude --settings '{"disableAllHooks": true}'`. Desliga também o `skill-router` do settings do usuário.
- **Todas as sessões desta máquina**: `"disableAllHooks": true` no `~/.claude/settings.json`, aplicado pelo dono. Mesmo efeito colateral.
- **De vez no projeto**: PR que tira o bloco `SessionStart` de `.claude/settings.json` e a regra correspondente do guarda.

Worktree criada de branch anterior ao #79 não tem `.claude/settings.json` e começa sem retrato. O hook do projeto só roda em pasta que o dono marcou como confiável no diálogo de confiança do Claude Code.
