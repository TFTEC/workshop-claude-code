// Coleta do lado git do retrato da partida: atualiza a origin/main, avança o checkout principal
// quando é seguro e compara a `main` local, a worktree da sessão e as demais worktrees com ela.
// Tem dois efeitos: o `git fetch`, que escreve em `origin/main` e `FETCH_HEAD`, e o
// `git merge --ff-only` do checkout principal, com as condições em `avanco-do-principal.mjs` (#96).
// O resto só lê.
//
// Devolve um `estado`: `ok`; `nao-repositorio` (a pasta não é repositório git); ou `falhou`
// (git ausente, travado ou lento demais), com o motivo. As duas últimas nunca se confundem.
import { execFile } from 'node:child_process';
import path from 'node:path';
import { avancarCheckoutPrincipal } from './avanco-do-principal.mjs';

const REMOTO = 'origin';
const MAIN = 'main';
const REF_REMOTA = `${REMOTO}/${MAIN}`;
// Arquivos que a sessão carrega na partida ou lê antes de agir: se a main mudou algum deles
// depois que a worktree saiu, a sessão está começando com regra velha.
const ARQUIVOS_DE_REGRA = ['CLAUDE.md', 'CONTEXT.md', 'docs/agents', '.claude'];
const TIMEOUT_MS = 5000;
const TIMEOUT_FETCH_MS = 10000;

// Nunca pedir senha nem abrir janela de credencial: sem rede, o fetch falha e o retrato segue.
// Mensagens do git em inglês, para reconhecer "not a git repository" em qualquer máquina.
const ENV_DO_GIT = { GIT_TERMINAL_PROMPT: '0', GCM_INTERACTIVE: 'never', LC_ALL: 'C' };

const primeiraLinha = texto => String(texto ?? '').split(/\r?\n/)[0].trim();

// `ate`: instante limite do prazo global; nenhum comando passa dele.
// `padrao` Infinity: o comando escreve e nunca é morto no meio (o merge do avanço do checkout
// principal), nem pelo prazo global; quem o chama confere antes se sobra tempo.
// O erro leva `codigo` (código de saída do git), `tempoEsgotado` e `saida` (o stderr inteiro), para
// quem precisa separar "o git respondeu não" (ex.: código 1 do `merge-base --is-ancestor`) de
// "o git falhou", ou ler a lista de arquivos que o git recusou.
// Só o fim da saída é aparado: no `status --porcelain` o espaço do começo faz parte do código.
export function criarGit({ timeoutMs, ate = Infinity }) {
  return (cwd, args, padrao = TIMEOUT_MS) => {
    // Para o execFile, timeout 0 é "sem timeout".
    const timeout = padrao === Infinity ? 0 : Math.max(1, Math.min(timeoutMs ?? padrao, ate - Date.now()));
    return new Promise((resolve, reject) => {
      execFile('git', args, { cwd, timeout, windowsHide: true, env: { ...process.env, ...ENV_DO_GIT } }, (erro, stdout, stderr) => {
        if (!erro) return resolve(stdout.trimEnd());
        const subcomando = args.find(a => !a.startsWith('-')) ?? args[0];
        const falha = new Error(erro.killed ? `git ${subcomando} sem resposta em ${timeout} ms` : primeiraLinha(stderr || erro.message));
        falha.codigo = typeof erro.code === 'number' ? erro.code : null;
        falha.tempoEsgotado = Boolean(erro.killed);
        falha.saida = String(stderr ?? '');
        reject(falha);
      });
    });
  };
}

// Saída de `git worktree list --porcelain -z`: campos separados por NUL, worktrees por NUL duplo.
// Com `-z` o git não põe aspas nem escapes octais no motivo da trava ("sessão" chega inteiro).
export function worktreesDoPorcelain(texto) {
  return texto.split('\0\0').filter(bloco => bloco.trim()).map(bloco => {
    const w = {};
    for (const linha of bloco.split('\0')) {
      const [chave, ...resto] = linha.split(' ');
      const valor = resto.join(' ');
      if (chave === 'worktree') w.caminho = valor;
      else if (chave === 'HEAD') w.head = valor;
      else if (chave === 'branch') w.branch = valor.replace(/^refs\/heads\//, '');
      else if (chave === 'detached') w.branch = null;
      else if (chave === 'locked') w.travada = valor || 'sem motivo';
      else if (chave === 'prunable') w.pastaSumiu = true;
    }
    return w;
  });
}

// `semAvanco`: RETRATO_SEM_AVANCO; o checkout principal não avança (o retrato diz que não avançou).
// `escritas`: recebe o merge do avanço em curso, para quem chamou não sair com ele no meio.
export async function coletarGit(cwd, { timeoutMs, ate, semAvanco = false, escritas } = {}) {
  const git = criarGit({ timeoutMs, ate });
  let topo;
  try {
    topo = await git(cwd, ['rev-parse', '--show-toplevel']);
  } catch (erro) {
    if (/not a git repository/i.test(erro.message)) return { estado: 'nao-repositorio' };
    return { estado: 'falhou', motivo: erro.message };
  }
  try {
    return { estado: 'ok', ...(await compararComAOrigin(git, topo, { semAvanco, ate, escritas })) };
  } catch (erro) {
    return { estado: 'falhou', motivo: primeiraLinha(erro.message) };
  }
}

async function compararComAOrigin(git, topo, { semAvanco, ate, escritas }) {
  const gitOuNulo = args => git(topo, args).catch(() => null); // "não achei a ref" é resposta, não falha
  const aFrenteAtras = async ref => {
    const contagem = await gitOuNulo(['rev-list', '--left-right', '--count', `${ref}...${REF_REMOTA}`]);
    if (!contagem) return null;
    const [aFrente, atras] = contagem.split(/\s+/).map(Number);
    return { aFrente, atras };
  };

  let fetch = { ok: true };
  try {
    await git(topo, ['fetch', '--quiet', '--no-tags', '--no-auto-maintenance', REMOTO, MAIN], TIMEOUT_FETCH_MS);
  } catch (erro) {
    fetch = { ok: false, motivo: erro.message };
  }

  const temRemota = Boolean(await gitOuNulo(['rev-parse', '--verify', '--quiet', `refs/remotes/${REF_REMOTA}`]));
  const listar = async () => worktreesDoPorcelain(await git(topo, ['worktree', 'list', '--porcelain', '-z']));
  let worktrees = await listar();
  // A primeira entrada do `git worktree list` é o checkout principal, parta a sessão dele ou de
  // uma worktree. Depois do avanço, a lista é lida de novo: o HEAD dele mudou.
  const avanco = temRemota
    ? await avancarCheckoutPrincipal(git, { raiz: worktrees[0].caminho, fetch, ate, semAvanco, escritas })
    : null;
  if (avanco?.feito) worktrees = await listar();
  const principal = worktrees[0];

  const mainLocal = temRemota && (await gitOuNulo(['rev-parse', '--verify', '--quiet', `refs/heads/${MAIN}`]))
    ? await aFrenteAtras(`refs/heads/${MAIN}`)
    : null;

  const atual = worktrees.find(w => mesmoCaminho(w.caminho, topo)) ?? { caminho: topo };
  const branchAtual = await gitOuNulo(['branch', '--show-current']);
  const comparacaoAtual = temRemota ? await aFrenteAtras('HEAD') : null;
  let regrasQueMudaram = [];
  if (comparacaoAtual?.atras > 0) {
    const nomes = await gitOuNulo(['diff', '--name-only', `HEAD...${REF_REMOTA}`, '--', ...ARQUIVOS_DE_REGRA]);
    regrasQueMudaram = nomes ? nomes.split(/\r?\n/).filter(Boolean) : [];
  }

  const todas = await Promise.all(worktrees.map(async w => ({
    nome: nomeDaPasta(w.caminho),
    principal: w === principal,
    caminho: w.caminho,
    branch: w.branch ?? null,
    travada: w.travada ?? null,
    pastaSumiu: Boolean(w.pastaSumiu),
    atual: w === atual,
    comparacao: temRemota && w.head && !w.pastaSumiu ? await aFrenteAtras(w.head) : null
  })));

  return {
    fetch,
    temRemota,
    avanco,
    raizPrincipal: principal.caminho,
    worktrees: todas,
    mainLocal,
    atual: {
      nome: nomeDaPasta(atual.caminho),
      principal: mesmoCaminho(atual.caminho, principal.caminho),
      branch: branchAtual || null,
      comparacao: comparacaoAtual,
      regrasQueMudaram
    }
  };
}

export const normalizar = caminho => caminho.replace(/\\/g, '/').replace(/\/+$/, '').toLowerCase();
const mesmoCaminho = (a, b) => normalizar(a) === normalizar(b);

const nomeDaPasta = caminho => path.basename(caminho.replace(/\\/g, '/'));
