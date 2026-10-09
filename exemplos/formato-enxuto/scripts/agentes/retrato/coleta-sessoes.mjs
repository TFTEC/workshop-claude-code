// Sessões vivas do Claude Code, lidas dos arquivos `<pid>.json` que ele mantém em
// `~/.claude/sessions/` (ou `$CLAUDE_CONFIG_DIR/sessions/`). Só os `.json`: os `.key` ao lado são
// segredo e nunca são abertos. Uma sessão é viva quando o processo do pid ainda existe.
import { readdirSync, readFileSync, realpathSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { normalizar } from './coleta-git.mjs';

export const pastaPadraoDeSessoes = () =>
  path.join(process.env.CLAUDE_CONFIG_DIR || path.join(homedir(), '.claude'), 'sessions');

function processoVivo(pid) {
  if (!Number.isInteger(pid) || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch (erro) {
    return erro.code === 'EPERM';
  }
}

function caminhoReal(caminho) {
  try {
    return realpathSync.native(caminho);
  } catch {
    return caminho; // a pasta pode ter sido apagada, e isso é justamente o que o retrato quer acusar
  }
}

// Onde a sessão roda: numa worktree listada pelo git, no checkout principal, numa pasta de
// `.claude/worktrees/` que já não é worktree, ou fora deste repositório.
function localDaSessao(cwd, { raizPrincipal, worktrees }) {
  const alvo = normalizar(caminhoReal(cwd));
  const dono = worktrees
    .filter(w => !w.pastaSumiu)
    .filter(w => alvo === normalizar(w.caminho) || alvo.startsWith(`${normalizar(w.caminho)}/`))
    .sort((a, b) => b.caminho.length - a.caminho.length)[0];
  const raiz = normalizar(raizPrincipal);
  const relativo = alvo.startsWith(`${raiz}/`) ? path.posix.relative(raiz, alvo) : null;
  if (!dono) return { tipo: 'fora' };
  if (dono.principal && relativo?.startsWith('.claude/worktrees/')) return { tipo: 'nao-e-worktree', relativo };
  return dono.principal ? { tipo: 'principal', caminho: dono.caminho } : { tipo: 'worktree', nome: dono.nome, caminho: dono.caminho };
}

export function coletarSessoes(pasta, repositorio) {
  let arquivos;
  try {
    arquivos = readdirSync(pasta).filter(nome => nome.endsWith('.json'));
  } catch (erro) {
    return { legivel: false, motivo: `pasta de sessões ilegível (${erro.code ?? erro.message})` };
  }

  const vivas = [];
  let ilegiveis = 0; // corrompido, sendo regravado pela própria sessão ou num formato que mudou
  for (const nome of arquivos) {
    let s;
    try {
      s = JSON.parse(readFileSync(path.join(pasta, nome), 'utf8'));
    } catch {
      ilegiveis += 1;
      continue;
    }
    if (typeof s !== 'object' || s === null || typeof s.cwd !== 'string') {
      ilegiveis += 1;
      continue;
    }
    if (!processoVivo(s.pid)) continue;
    if (s.spare) continue; // reserva aquecida para a próxima sessão em segundo plano: ninguém trabalha nela
    vivas.push({
      pid: s.pid,
      nome: s.name || s.sessionId || String(s.pid),
      status: s.status ?? 'desconhecido',
      esperando: s.waitingFor ?? null,
      desde: s.statusUpdatedAt ? new Date(s.statusUpdatedAt) : null,
      local: localDaSessao(s.cwd, repositorio),
      // Usados pela faxina (#81): id curto do `claude stop`/`claude respawn`, versão e tipo.
      id: s.jobId || String(s.sessionId ?? s.pid).slice(0, 8),
      versao: s.version ?? null,
      emSegundoPlano: s.kind === 'bg',
      cwd: s.cwd
    });
  }

  return {
    legivel: true,
    doRepositorio: vivas.filter(s => s.local.tipo !== 'fora'),
    foraDoRepositorio: vivas.filter(s => s.local.tipo === 'fora').length,
    todas: vivas,
    ilegiveis
  };
}
