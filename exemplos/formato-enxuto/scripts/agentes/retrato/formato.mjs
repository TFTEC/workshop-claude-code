// Formatação do retrato da partida: recebe o que a coleta juntou e devolve o texto que a sessão lê.
// Não roda git, não chama o GitHub e não lê disco.
//
// Dois limites valem para qualquer entrada:
// - o hook entrega no máximo 10 mil caracteres; acima disso o Claude Code troca o texto por um
//   arquivo e uma prévia, que a sessão não é obrigada a ler. Cada lista tem teto e o texto final
//   é cortado antes do limite;
// - nada com cara de credencial ou de e-mail sai daqui (título de PR e comentário de issue são
//   texto livre).

const LIMITE_DE_CARACTERES = 9500;
const MAXIMO = { atencao: 10, prs: 15, issues: 12, worktrees: 25, sessoes: 20 };

const plural = (n, um, varios) => `${n} ${n === 1 ? um : varios}`;
const curto = (texto, max) => {
  const limpo = String(texto ?? '').replace(/\s+/g, ' ').trim();
  return limpo.length > max ? `${limpo.slice(0, max - 1)}…` : limpo;
};

const SEGREDOS = [
  [/\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})/g, '[segredo redigido]'],
  [/\bEAA[A-Za-z0-9]{20,}/g, '[segredo redigido]'],
  [/\bsk-[A-Za-z0-9_-]{20,}/g, '[segredo redigido]'],
  [/\beyJ[\w-]{10,}\.[\w-]{10,}\.[\w-]{5,}/g, '[segredo redigido]'],
  [/(\b[a-z][a-z0-9+.-]*:\/\/)[^\s/:@]+:[^\s/@]+@/gi, '$1[credencial redigida]@'],
  [/\b(sig|password|senha|secret|token|api[_-]?key)=[^\s&]+/gi, '$1=[segredo redigido]'],
  // Depois da credencial em URL, para "usuario:senha@host" sair como credencial, não como e-mail.
  [/[\w.+-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+/gi, '[e-mail redigido]']
];
export const semSegredo = texto => SEGREDOS.reduce((t, [padrao, troca]) => t.replace(padrao, troca), texto);

function comLimite(itens, maximo, rotulo) {
  const excedente = itens.length - maximo;
  return { visiveis: itens.slice(0, maximo), resto: excedente > 0 ? `- … e mais ${excedente} ${rotulo}.` : null };
}

function idade(desde, agora) {
  const minutos = Math.max(0, Math.round((agora - desde) / 60000));
  if (minutos < 60) return `${minutos} min`;
  const horas = Math.round(minutos / 60);
  if (horas < 24) return `${horas} h`;
  return plural(Math.round(horas / 24), 'dia', 'dias');
}

function comparacaoCurta(comparacao) {
  if (!comparacao) return null;
  const { aFrente, atras } = comparacao;
  if (atras === 0 && aFrente === 0) return 'em dia com a origin/main';
  if (atras === 0) return `${plural(aFrente, 'commit', 'commits')} à frente da origin/main`;
  return `${plural(atras, 'commit', 'commits')} atrás da origin/main${aFrente > 0 ? `, ${aFrente} à frente` : ''}`;
}

function secaoGit(git) {
  if (git.estado === 'nao-repositorio') return ['## Git', '- Esta pasta não é um repositório git.'];
  if (git.estado === 'falhou') return ['## Git', `- git não respondeu: ${curto(git.motivo, 160)}. Worktrees e sessões ficaram de fora.`];
  if (git.estado === 'tempo-esgotado') {
    return ['## Git', `- Git: retrato parcial (tempo esgotado); o git não terminou em ${git.segundos} s. Worktrees e sessões ficaram de fora.`];
  }
  const linhas = ['## Git'];
  if (!git.fetch.ok) {
    linhas.push(`- A origin/main não foi atualizada agora (${curto(git.fetch.motivo, 160)}); a comparação usa a última cópia baixada.`);
  }
  if (!git.temRemota) {
    linhas.push('- Não existe origin/main neste repositório: sem comparação.');
    return linhas;
  }

  const { atual } = git;
  const rotulo = atual.principal
    ? `Esta sessão roda no checkout principal (branch ${atual.branch ?? 'destacada'})`
    : `Esta worktree (${atual.nome}, branch ${atual.branch ?? 'destacada'})`;
  linhas.push(`- ${rotulo}: ${comparacaoCurta(atual.comparacao) ?? 'sem comparação com a origin/main'}.`);
  if (atual.regrasQueMudaram.length > 0) {
    const { visiveis, resto } = comLimite(atual.regrasQueMudaram, 8, 'arquivos');
    linhas.push(`  A main mudou regra desde que esta branch saiu: ${visiveis.join(', ')}${resto ? ` ${resto.slice(2)}` : ''}.`);
  }

  if (git.avanco?.feito) {
    linhas.push(`- checkout principal atualizado de \`${git.avanco.de}\` para \`${git.avanco.para}\` (regras novas valem na próxima sessão).`);
  }
  if (!git.mainLocal) linhas.push('- main local: não existe neste clone.');
  else {
    const aviso = git.mainLocal.atras > 0 ? ' Atualize a main antes de criar worktree nova.' : '';
    linhas.push(`- main local: ${comparacaoCurta(git.mainLocal)}.${aviso}`);
  }
  return linhas;
}

function secaoGitHub(github, agora) {
  if (github.tempoEsgotado) {
    return ['## GitHub', `- GitHub: retrato parcial (tempo esgotado); o gh não respondeu em ${github.segundos} s. PRs abertos e issues em andamento ficaram de fora.`];
  }
  if (!github.disponivel) {
    return ['## GitHub', `- GitHub indisponível (${curto(github.motivo, 160)}): PRs abertos e issues em andamento ficaram de fora deste retrato.`];
  }
  const prs = comLimite(github.prsAbertos, MAXIMO.prs, 'PRs');
  const linhas = [`## PRs abertos (${github.prsAbertos.length})`];
  if (github.prsAbertos.length === 0) linhas.push('- Nenhum.');
  for (const pr of prs.visiveis) {
    const detalhes = [`branch ${curto(pr.branch, 60)}`, pr.autor && `@${pr.autor}`, pr.rascunho && 'rascunho'].filter(Boolean).join(', ');
    linhas.push(`- #${pr.numero} aberto há ${idade(pr.criadoEm, agora)}: ${curto(pr.titulo, 100)} (${detalhes})`);
  }
  if (prs.resto) linhas.push(prs.resto);

  const issues = comLimite(github.issuesEmAndamento, MAXIMO.issues, 'issues');
  linhas.push('', `## Issues em andamento (${github.issuesEmAndamento.length})`);
  if (github.issuesEmAndamento.length === 0) linhas.push('- Nenhuma com o label em-andamento.');
  for (const issue of issues.visiveis) {
    const quem = issue.responsaveis.length > 0 ? issue.responsaveis.map(l => `@${l}`).join(', ') : 'sem responsável';
    linhas.push(`- #${issue.numero} com ${quem}: ${curto(issue.titulo, 100)}`);
    linhas.push(issue.posse
      ? `  Assumida: ${curto(issue.posse.texto, 140)} (há ${idade(issue.posse.em, agora)})`
      : '  Sem comentário de quem assumiu.');
  }
  if (issues.resto) linhas.push(issues.resto);
  return linhas;
}

const moraNaWorktree = (s, w) =>
  (s.local.tipo === 'worktree' || s.local.tipo === 'principal') && s.local.caminho === w.caminho;

function secaoWorktrees(git, sessoes) {
  if (git.estado !== 'ok') return [];
  const { visiveis, resto } = comLimite(git.worktrees, MAXIMO.worktrees, 'worktrees');
  const linhas = [`## Worktrees (${git.worktrees.length})`];
  for (const w of visiveis) {
    const nomesDasSessoes = (sessoes.doRepositorio ?? []).filter(s => moraNaWorktree(s, w)).map(s => `"${curto(s.nome, 60)}"`);
    const partes = [
      comparacaoCurta(w.comparacao),
      w.travada && `TRAVADA (${curto(w.travada, 60)})`,
      w.pastaSumiu && 'PASTA APAGADA (o git ainda lista)',
      nomesDasSessoes.length > 0 && `sessão ${nomesDasSessoes.join(', ')}`,
      w.atual && 'é a desta sessão'
    ].filter(Boolean);
    linhas.push(`- ${w.principal ? 'checkout principal' : w.nome} (branch ${w.branch ?? 'destacada'}): ${partes.join('; ') || 'sem comparação'}`);
  }
  if (resto) linhas.push(resto);
  return linhas;
}

const ESTADO = { busy: 'trabalhando', idle: 'ociosa' };

function linhaDeSessao(s, agora) {
  const ha = s.desde ? ` há ${idade(s.desde, agora)}` : '';
  const onde = {
    worktree: `na worktree ${s.local.nome}`,
    principal: 'no checkout principal',
    'nao-e-worktree': `em ${s.local.relativo}`
  }[s.local.tipo];
  const quem = `"${curto(s.nome, 60)}" (pid ${s.pid}) ${onde}`;
  if (s.status === 'waiting') return `- [PARADA esperando ${curto(s.esperando ?? 'resposta', 40)}${ha}] ${quem}`;
  const estado = `${ESTADO[s.status] ?? s.status}${ha}`;
  if (s.local.tipo === 'nao-e-worktree') return `- [PASTA QUE JÁ NÃO É WORKTREE] ${quem}, ${estado}`;
  return `- ${quem}, ${estado}`;
}

const emDestaque = s => s.status === 'waiting' || s.local.tipo === 'nao-e-worktree';

// Por que o checkout principal não avançou (`retrato/avanco-do-principal.mjs`) e o que o dono roda.
// O comando padrão é o `git pull --ff-only`. Fora da main, o pull puxaria a outra branch: o comando
// volta para a main antes. Divergente, o pull recusaria: o dono vê primeiro os commits que só
// existem ali. Na trava, a outra sessão costuma estar avançando agora: o comando fica para o caso
// de a linha voltar.
const PULL = 'git pull --ff-only';
const SEM_AVANCO = {
  desligado: { motivo: () => 'avanço desligado por RETRATO_SEM_AVANCO' },
  'sem-fetch': { motivo: () => 'o fetch da partida falhou' },
  sujo: { motivo: a => `tem mudança sem commit em ${plural(a.arquivos, 'arquivo rastreado', 'arquivos rastreados')}` },
  'fora-da-main': {
    motivo: a => (a.branch ? `está na branch ${a.branch}, não na main` : 'está com o HEAD destacado, não na main'),
    comando: `git switch main && ${PULL}`
  },
  divergente: {
    motivo: a => `a main local tem ${plural(a.aFrente, 'commit', 'commits')} que a origin/main não tem`,
    acao: 'Veja os commits só locais',
    comando: 'git log --oneline origin/main..main'
  },
  'nao-rastreado': {
    motivo: a => {
      const { visiveis, resto } = comLimite(a.arquivos, 3, 'arquivos');
      const lista = `${visiveis.map(f => curto(f, 80)).join(', ')}${resto ? ` ${resto.slice(2, -1)}` : ''}`;
      return `o git recusou, porque sobrescreveria ${plural(a.arquivos.length, 'arquivo não rastreado', 'arquivos não rastreados')} (${lista})`;
    }
  },
  trava: {
    motivo: a => `outro git segura a trava do repositório (${curto(a.travado, 80)}), talvez outra sessão atualizando agora`,
    acao: 'A próxima partida confere de novo; se a linha voltar, rode'
  },
  'sem-tempo': { motivo: () => 'faltou tempo no prazo da partida para atualizar com segurança' },
  git: { motivo: a => `o git falhou (${curto(a.detalhe, 160)})` }
};

// O `!` roda no Git Bash: C:/x/y vira /c/x/y, e caminho com caractere especial vai entre aspas.
export function caminhoDoBash(caminho) {
  const posix = caminho.replace(/\\/g, '/').replace(/^([A-Za-z]):/, (_, letra) => `/${letra.toLowerCase()}`);
  return /^[\w./-]+$/.test(posix) ? posix : `'${posix.replace(/'/g, `'\\''`)}'`;
}

function linhaDoPrincipalSemAvanco(avanco, raiz) {
  const atras = avanco.atras ? ` ${plural(avanco.atras, 'commit', 'commits')} atrás da origin/main e` : '';
  // Causa que este formato não conhece sai pelo nome, sem derrubar o retrato.
  const { motivo, acao = 'Rode', comando = PULL } = SEM_AVANCO[avanco.causa] ?? { motivo: a => `causa ${a.causa}` };
  return `- checkout principal${atras} não atualizado: ${motivo(avanco)}. ` +
    `${acao} num terminal fora do Claude Code ou pelo \`!\` de uma sessão aberta no checkout principal: ` +
    `\`cd ${caminhoDoBash(raiz)} && ${comando}\`.`;
}

// Vem logo depois do Git: o corte de tamanho nunca alcança o que pede ação agora.
function secaoAtencao(git, sessoes, agora) {
  const itens = [];
  const atras = git.estado === 'ok' && git.atual.comparacao?.atras > 0;
  if (atras) {
    itens.push(`- Esta ${git.atual.principal ? 'sessão roda no checkout principal, que' : 'worktree'} está ` +
      `${plural(git.atual.comparacao.atras, 'commit', 'commits')} atrás da origin/main` +
      `${git.atual.regrasQueMudaram.length > 0 ? ', com regra velha' : ''}: comece o trabalho numa worktree nova criada da main atualizada.`);
  }
  if (git.estado === 'ok' && git.avanco && !git.avanco.feito) itens.push(linhaDoPrincipalSemAvanco(git.avanco, git.raizPrincipal));
  const { visiveis, resto } = comLimite((sessoes.doRepositorio ?? []).filter(emDestaque), MAXIMO.atencao, 'sessões em destaque');
  for (const s of visiveis) itens.push(linhaDeSessao(s, agora));
  if (resto) itens.push(resto);
  return itens.length > 0 ? ['## Atenção', ...itens] : [];
}

function secaoSessoes(sessoes, agora) {
  if (!sessoes.legivel) return ['## Sessões vivas', `- Não deu para ler as sessões: ${sessoes.motivo}.`];
  const todas = sessoes.doRepositorio;
  const comuns = todas.filter(s => !emDestaque(s));
  const { visiveis, resto } = comLimite(comuns, MAXIMO.sessoes, 'sessões');
  const linhas = [`## Sessões vivas neste repositório (${todas.length})`];
  if (todas.length === 0) linhas.push('- Nenhuma.');
  if (todas.length > comuns.length) linhas.push(`- ${plural(todas.length - comuns.length, 'destacada', 'destacadas')} em Atenção, acima.`);
  for (const s of visiveis) linhas.push(linhaDeSessao(s, agora));
  if (resto) linhas.push(resto);
  if (sessoes.foraDoRepositorio > 0) {
    linhas.push(`Mais ${plural(sessoes.foraDoRepositorio, 'sessão viva', 'sessões vivas')} fora deste repositório.`);
  }
  if (sessoes.ilegiveis > 0) {
    linhas.push(`${plural(sessoes.ilegiveis, 'arquivo de sessão ilegível', 'arquivos de sessão ilegíveis')}: as sessões deles ficaram de fora.`);
  }
  return linhas;
}

// Texto do caminho de erro inesperado: a mesma redação de segredo do retrato normal.
export function textoDeFalha(erro) {
  const motivo = curto(String(erro?.message ?? erro).split(/\r?\n/)[0], 200);
  return `${semSegredo(`# Retrato da partida\n\nO retrato falhou nesta partida (${motivo}). ` +
    'Rode `node scripts/agentes/retrato-da-partida.mjs` para ver o erro.')}\n`;
}

export function formatar({ git, github, sessoes, agora, geradoEm }) {
  const atencao = secaoAtencao(git, sessoes, agora);
  const texto = semSegredo([
    `# Retrato da partida (calculado agora: ${geradoEm})`, '',
    ...secaoGit(git), '',
    ...(atencao.length > 0 ? [...atencao, ''] : []),
    ...secaoGitHub(github, agora), '',
    ...secaoWorktrees(git, sessoes), '',
    ...secaoSessoes(sessoes, agora)
  ].join('\n'));
  if (texto.length <= LIMITE_DE_CARACTERES) return `${texto}\n`;
  return `${texto.slice(0, LIMITE_DE_CARACTERES)}\n… (retrato cortado em ${LIMITE_DE_CARACTERES} caracteres)\n`;
}
