// Avanço do checkout principal (#96): depois do fetch da partida, leva o checkout principal até a
// origin/main por fast-forward, para o dono não precisar rodar `git pull` nele. É o único comando
// do retrato que escreve fora de `origin/main` e `FETCH_HEAD`: `git merge --ff-only --no-autostash`
// do commit da origin/main conferido, no checkout principal, e só quando
// - o fetch da partida deu certo;
// - o checkout principal está na branch `main`;
// - a main local não tem commit que a origin/main não tem;
// - nenhum arquivo rastreado tem mudança, no stage ou fora dele;
// - sobra tempo no prazo global para o merge terminar.
// Arquivo não rastreado (como o `.claude/settings.local.json`) não impede: se o merge fosse
// sobrescrever um, o próprio git recusa e nada muda. Nunca roda reset, checkout, switch, stash,
// clean nem --force; o `--no-autostash` impede o stash automático mesmo com `merge.autoStash` ligado.
//
// Devolve null quando não há o que relatar (o checkout principal não está atrás da origin/main, ou
// outra sessão acabou de avançá-lo); `{ feito: true, de, para }` quando este merge avançou;
// `{ feito: false, atras, causa, ... }` quando não, com a causa para o retrato.
import { existsSync } from 'node:fs';
import path from 'node:path';

const MAIN = 'main';
const ORIGIN_MAIN = 'refs/remotes/origin/main';
// O retrato não interrompe o merge (um merge interrompido deixa o checkout pela metade e o
// `index.lock` para trás): ele não tem timeout, o script espera por ele antes de sair
// (`escritas`), e ele só começa com esta folga antes do fim do prazo global. Um fast-forward de
// poucos commits leva menos de 1 s.
const MARGEM_DO_MERGE_MS = 5000;
const abreviar = sha => sha.slice(0, 7);

// `raiz`: a pasta do checkout principal (a primeira entrada de `git worktree list`).
// `fetch`: o resultado do fetch da partida (`{ ok, motivo }`). `ate`: fim do prazo global.
// `semAvanco`: RETRATO_SEM_AVANCO; confere tudo e não escreve.
// `escritas`: lista do chamador que recebe o merge em curso, para ele não sair com o merge no meio.
export async function avancarCheckoutPrincipal(git, { raiz, fetch, ate, semAvanco, escritas }) {
  const ler = args => git(raiz, args);
  let head;
  let alvo;
  let aFrente;
  let atras;
  try {
    head = await ler(['rev-parse', '--verify', 'HEAD^{commit}']);
    alvo = await ler(['rev-parse', '--verify', `${ORIGIN_MAIN}^{commit}`]);
    [aFrente, atras] = (await ler(['rev-list', '--left-right', '--count', `HEAD...${alvo}`])).split(/\s+/).map(Number);
  } catch (erro) {
    return { feito: false, atras: null, causa: 'git', detalhe: erro.message };
  }
  if (atras === 0) return null;
  const nao = (causa, extra = {}) => ({ feito: false, atras, causa, ...extra });
  // Sem o fetch, a origin/main é a da última cópia baixada, não a de agora. Fetch que esbarrou na
  // trava da ref é outra sessão partindo no mesmo instante: ela é quem avança.
  if (!fetch.ok) {
    const travado = oQueEstaTravado(fetch.motivo);
    return travado ? nao('trava', { travado }) : nao('sem-fetch');
  }

  // O merge avança a branch que estiver no checkout: só a main pode ser ela.
  let branch;
  try {
    branch = await ler(['symbolic-ref', '--quiet', '--short', 'HEAD']);
  } catch (erro) {
    if (erro.codigo !== 1) return nao('git', { detalhe: erro.message });
    branch = null; // código 1 do `symbolic-ref --quiet`: HEAD destacado
  }
  if (branch !== MAIN) return nao('fora-da-main', { branch });
  if (aFrente > 0) return nao('divergente', { aFrente });

  // `--no-optional-locks`: o status não regrava o índice, então não disputa a trava com um git
  // que o dono rode no checkout principal nesse instante.
  let mudancas;
  try {
    mudancas = await ler(['--no-optional-locks', 'status', '--porcelain', '--untracked-files=no']);
  } catch (erro) {
    return nao('git', { detalhe: erro.message });
  }
  const arquivos = mudancas.split(/\r?\n/).filter(Boolean).length;
  if (arquivos > 0) {
    // Status lido no meio do merge de outra sessão vê os arquivos novos contra o índice velho. O
    // index.lock dela, ou o HEAD que andou desde a primeira leitura, separa isso de mudança do dono.
    try {
      const agora = await ler(['rev-parse', '--verify', 'HEAD^{commit}']);
      if (agora === alvo) return null;
      const indiceTravado = existsSync(path.resolve(raiz, await ler(['rev-parse', '--git-path', 'index.lock'])));
      if (indiceTravado || agora !== head) return nao('trava', { travado: 'index.lock' });
    } catch (erro) {
      return nao('git', { detalhe: erro.message });
    }
    return nao('sujo', { arquivos });
  }

  if (semAvanco) return nao('desligado');
  if (ate - Date.now() < MARGEM_DO_MERGE_MS) return nao('sem-tempo');
  const merge = git(raiz, ['merge', '--ff-only', '--no-autostash', '--no-stat', '--no-progress', alvo], Infinity);
  escritas.push(Promise.allSettled([merge]));
  let saida;
  try {
    saida = await merge;
  } catch (erro) {
    return nao(...causaDaRecusa(erro));
  }
  // Quem moveu o HEAD foi este merge só se o git disse "Updating <de>..<para>". "Already up to
  // date" quer dizer que outra sessão avançou entre a leitura e o merge: não há o que relatar.
  const avancou = saida.match(/^Updating ([0-9a-f]+)\.\.([0-9a-f]+)/m);
  return avancou ? { feito: true, de: abreviar(avancou[1]), para: abreviar(avancou[2]) } : null;
}

// O git lista, com tabulação no começo da linha, os arquivos que o fizeram recusar o merge.
function causaDaRecusa(erro) {
  const saida = erro.saida ?? '';
  const arquivos = saida.split(/\r?\n/).filter(l => l.startsWith('\t')).map(l => l.trim());
  if (/untracked working tree files would be (?:overwritten|removed)/i.test(saida) && arquivos.length > 0) {
    return ['nao-rastreado', { arquivos }];
  }
  const travado = oQueEstaTravado(saida);
  if (travado) return ['trava', { travado }];
  return ['git', { detalhe: erro.message }];
}

// Duas sessões partindo juntas: a trava do git fica com a primeira, e a segunda recebe uma destas
// mensagens. Devolve o que está travado (o arquivo `.lock` do índice ou o nome da ref), ou null.
function oQueEstaTravado(texto = '') {
  const trava = texto.match(/Unable to create '([^']+\.lock)': File exists|cannot lock ref '([^']+)'/i);
  if (!trava) return null;
  return trava[1] ? path.basename(trava[1]) : trava[2];
}
