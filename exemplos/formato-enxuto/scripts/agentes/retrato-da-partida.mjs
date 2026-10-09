#!/usr/bin/env node
/**
 * RETRATO DA PARTIDA (#79, spec #76). Chamado pelo hook `SessionStart` de `.claude/settings.json`;
 * o que ele imprime entra no contexto da sessão nova. Como funciona e como desligar:
 * `docs/agents/retrato-da-partida.md`.
 *
 * Nunca derruba a partida: qualquer falha vira uma linha no retrato e o código de saída é 0.
 * Prazo global de 20 s, abaixo dos 30 s do hook: o que não terminou a tempo sai como
 * "retrato parcial (tempo esgotado)". Um merge do avanço ainda em curso segura a saída do processo
 * (não a do texto) até terminar, com teto de 28 s.
 *
 * Efeitos: o `git fetch origin main` e, quando é seguro, o `git merge --ff-only` que avança o
 * checkout principal até a origin/main (#96, condições em retrato/avanco-do-principal.mjs).
 *
 * Rodar à mão:  node scripts/agentes/retrato-da-partida.mjs
 * Ver o retrato sem avançar o checkout principal:  RETRATO_SEM_AVANCO=1 node scripts/agentes/retrato-da-partida.mjs
 *
 * Variáveis que só o teste (retrato-da-partida.test.mjs) e a leitura à mão usam:
 *   RETRATO_GITHUB_FIXTURE  JSON { "prs": ..., "issues": ... } no lugar do `gh` (`{ "erro": "..." }` = GitHub fora)
 *   RETRATO_PASTA_SESSOES   pasta no lugar de ~/.claude/sessions
 *   RETRATO_AGORA           data ISO no lugar do relógio
 *   RETRATO_GIT_TIMEOUT_MS  timeout de cada git (valor baixo simula git travado)
 *   RETRATO_PRAZO_MS        prazo global no lugar dos 20 s (valor baixo simula o prazo estourado)
 *   RETRATO_SEM_AVANCO      qualquer valor: confere as condições do avanço, não roda o merge e diz
 *                           na Atenção que o avanço está desligado
 */
import { coletarGit } from './retrato/coleta-git.mjs';
import { coletarSessoes, pastaPadraoDeSessoes } from './retrato/coleta-sessoes.mjs';
import { adaptadorFixture, adaptadorGh, coletarGitHub } from './retrato/github.mjs';
import { formatar, textoDeFalha } from './retrato/formato.mjs';

const PRAZO_MS = 20000;
// O hook é morto em 30 s (`timeout` em .claude/settings.json): a espera por um merge em curso
// termina antes disso.
const TETO_DA_ESPERA_MS = 28000;

const env = process.env;
const agora = env.RETRATO_AGORA ? new Date(env.RETRATO_AGORA) : new Date();
const cwd = env.CLAUDE_PROJECT_DIR || process.cwd();
// Só o teste injeta estes dois: valores bem baixos simulam git travado e prazo estourado.
const timeoutDoGitMs = Number(env.RETRATO_GIT_TIMEOUT_MS) || undefined;
const prazoMs = Number(env.RETRATO_PRAZO_MS) || PRAZO_MS;
const inicio = Date.now();
const ate = inicio + prazoMs;
// O merge do avanço do checkout principal em curso, se houver (retrato/avanco-do-principal.mjs).
const escritas = [];

const quando = data => new Intl.DateTimeFormat('pt-BR', {
  timeZone: 'America/Sao_Paulo', day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit'
}).format(data).replace(', ', ' ') + ' (Brasília)';

const ESGOTADO = Symbol('tempo esgotado');
let relogio;
const esgotou = new Promise(resolve => { relogio = setTimeout(() => resolve(ESGOTADO), prazoMs); });
const comPrazo = promessa => Promise.race([promessa, esgotou]);

async function retratar() {
  const adaptador = env.RETRATO_GITHUB_FIXTURE ? adaptadorFixture(env.RETRATO_GITHUB_FIXTURE) : adaptadorGh(cwd, { ate });
  const [git, github] = await Promise.all([
    comPrazo(coletarGit(cwd, { timeoutMs: timeoutDoGitMs, ate, semAvanco: Boolean(env.RETRATO_SEM_AVANCO), escritas })),
    comPrazo(coletarGitHub(adaptador))
  ]);
  const segundos = Math.round(prazoMs / 1000);
  const gitFinal = git === ESGOTADO ? { estado: 'tempo-esgotado', segundos } : git;
  const githubFinal = github === ESGOTADO ? { disponivel: false, tempoEsgotado: true, segundos } : github;
  const sessoes = gitFinal.estado === 'ok'
    ? coletarSessoes(env.RETRATO_PASTA_SESSOES || pastaPadraoDeSessoes(), gitFinal)
    : { legivel: false, motivo: 'sem o git, não deu para localizar as sessões' };
  return formatar({ git: gitFinal, github: githubFinal, sessoes, agora, geradoEm: quando(agora) });
}

let texto;
try {
  texto = await retratar();
} catch (erro) {
  texto = textoDeFalha(erro);
}
clearTimeout(relogio);

// Um merge do avanço que passou do prazo termina antes da saída: o processo dele morre junto com
// este script (no Windows, até com `detached`), e um merge morto no meio deixa o checkout principal
// pela metade. O texto já foi entregue; a próxima partida mostra o checkout em dia. A espera para
// em 28 s: passar disso não salvaria o merge, porque aos 30 s o hook mata o script e o que ele lançou.
async function esperarEscritas() {
  if (escritas.length === 0) return;
  let teto;
  const limite = new Promise(resolve => { teto = setTimeout(resolve, Math.max(0, inicio + TETO_DA_ESPERA_MS - Date.now())); });
  await Promise.race([Promise.all(escritas), limite]);
  clearTimeout(teto);
}

// Sai assim que o texto foi entregue e nenhum merge está em curso: um git ou gh que estourou o
// prazo não segura a partida.
process.stdout.write(texto, () => esperarEscritas().then(() => process.exit(0)));
