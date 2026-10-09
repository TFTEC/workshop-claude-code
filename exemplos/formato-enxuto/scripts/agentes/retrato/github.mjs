// Lado GitHub do retrato da partida, atrás de um adaptador que devolve a saída crua do `gh`:
// o de verdade roda o `gh`; o de teste lê um JSON fixo (`RETRATO_GITHUB_FIXTURE`) com
// `{ "prs": ..., "issues": ... }`. Lista = o que o `gh ... --json` devolveria; texto = a saída crua,
// para simular resposta quebrada; `{ "erro": "motivo" }` simula o GitHub fora do ar.
// O JSON é lido num lugar só (`coletarGitHub`), dentro do `try`: resposta quebrada vira
// "GitHub indisponível", nunca exceção solta.
import { execFile } from 'node:child_process';
import { readFile } from 'node:fs/promises';

const LABEL_EM_ANDAMENTO = 'em-andamento';
const LIMITE = '50';
const TIMEOUT_MS = 10000;
const LIMITE_MESCLADOS = '500';
const TIMEOUT_MESCLADOS_MS = 30000;

function gh(cwd, args, timeout) {
  return new Promise((resolve, reject) => {
    execFile('gh', args, { cwd, timeout, windowsHide: true, env: { ...process.env, GH_PROMPT_DISABLED: '1' } }, (erro, stdout, stderr) => {
      if (!erro) return resolve(stdout);
      reject(new Error(erro.killed ? `gh sem resposta em ${Math.round(timeout / 1000)} s` : (stderr || erro.message).trim()));
    });
  });
}

// `ate`: instante limite do prazo global; nenhum `gh` passa dele.
export function adaptadorGh(cwd, { ate = Infinity } = {}) {
  const tempo = () => Math.max(1, Math.min(TIMEOUT_MS, ate - Date.now()));
  return {
    prsAbertos: () => gh(cwd, ['pr', 'list', '--state', 'open', '--limit', LIMITE,
      '--json', 'number,title,createdAt,isDraft,headRefName,author'], tempo()),
    issuesEmAndamento: () => gh(cwd, ['issue', 'list', '--state', 'open', '--label', LABEL_EM_ANDAMENTO, '--limit', LIMITE,
      '--json', 'number,title,assignees,comments'], tempo()),
    // Usado pela faxina (#81): PRs mesclados, com a base, para saber se o trabalho entrou na main.
    prsMesclados: () => gh(cwd, ['pr', 'list', '--state', 'merged', '--limit', LIMITE_MESCLADOS,
      '--json', 'number,headRefName,headRefOid,baseRefName,mergedAt'], TIMEOUT_MESCLADOS_MS)
  };
}

export function adaptadorFixture(arquivo) {
  const dados = readFile(arquivo, 'utf8').then(JSON.parse).then(d => {
    if (d.erro) throw new Error(d.erro);
    return d;
  });
  const cru = valor => (typeof valor === 'string' ? valor : JSON.stringify(valor ?? []));
  return {
    prsAbertos: () => dados.then(d => cru(d.prs)),
    issuesEmAndamento: () => dados.then(d => cru(d.issues)),
    prsMesclados: () => dados.then(d => cru(d.prsMesclados))
  };
}

const primeiraLinha = texto => (texto ?? '').split(/\r?\n/)[0].trim();

function lerJson(texto) {
  try {
    const valor = JSON.parse(texto);
    if (!Array.isArray(valor)) throw new Error('não é uma lista');
    return valor;
  } catch (erro) {
    throw new Error(`o gh não devolveu JSON: ${primeiraLinha(texto).slice(0, 60) || erro.message}`);
  }
}

function ultimaPosse(comentarios = []) {
  const posse = comentarios.filter(c => /assumiu/i.test(c.body ?? '')).at(-1);
  return posse ? { texto: primeiraLinha(posse.body), em: new Date(posse.createdAt) } : null;
}

export async function coletarGitHub(adaptador) {
  try {
    const [textoPrs, textoIssues] = await Promise.all([adaptador.prsAbertos(), adaptador.issuesEmAndamento()]);
    const prs = lerJson(textoPrs);
    const issues = lerJson(textoIssues);
    return {
      disponivel: true,
      prsAbertos: prs
        .map(p => ({
          numero: p.number, titulo: p.title, criadoEm: new Date(p.createdAt), rascunho: Boolean(p.isDraft),
          branch: p.headRefName, autor: p.author?.login ?? null
        }))
        .sort((a, b) => a.criadoEm - b.criadoEm),
      issuesEmAndamento: issues.map(i => ({
        numero: i.number, titulo: i.title,
        responsaveis: (i.assignees ?? []).map(a => a.login),
        posse: ultimaPosse(i.comments)
      }))
    };
  } catch (erro) {
    return { disponivel: false, motivo: primeiraLinha(erro.message) };
  }
}
