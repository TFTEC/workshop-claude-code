/**
 * GUARDA DA DOCUMENTAÇÃO DOS AGENTES (#77, spec #76).
 *
 * O QUE ESTE ARQUIVO PROTEGE
 * Toda sessão do Claude Code começa lendo o `CLAUDE.md`, e é por ele que acha o documento do
 * processo que vai executar. Um ponteiro para arquivo que não existe, ou um `CLAUDE.md` inchado
 * além das 200 linhas que a doc oficial recomenda, faz a sessão começar sem o padrão da casa, e
 * nada acende: a sessão só age errado. Este guarda falha antes disso.
 *
 * Regras:
 * - o `CLAUDE.md` aponta para o índice de processos;
 * - todo caminho do repositório que o `CLAUDE.md` cita (entre crases ou em link) existe, fora os
 *   que não moram aqui (`FORA_DO_REPOSITORIO`);
 * - cada item do índice é link para arquivo que existe ou uma linha "pendente (#N)", com o
 *   ticket que vai escrever o documento;
 * - o `CLAUDE.md` fica abaixo de 200 linhas;
 * - a configuração versionada do projeto (`.claude/settings.json`, #79) declara o hook
 *   `SessionStart` apontando para o script do retrato da partida, e ele existe;
 * - ela não carrega nenhuma chave de permissão (`CHAVES_DE_PERMISSAO`): permissão mora no settings
 *   do usuário (spec #76), e uma regra aqui valeria para toda worktree sem o dono ver. Outras
 *   configurações de projeto (ex.: `worktree.baseRef`) podem entrar.
 *
 * Cópia sanitizada: no original, este guarda tem ainda as regras que leem o conteúdo de um
 * documento (as contas de anúncio listadas em dois lugares, o modelo de permissões do settings do
 * usuário e o modo em vigor, os hosts da CSP de cada Site). Elas saíram junto com os documentos
 * que conferem. As seis regras acima estão como no original.
 *
 * Rodar:  node --test scripts/agentes/*.test.mjs
 */
import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const RAIZ = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const INDICE = 'docs/agents/README.md';
const LIMITE_LINHAS = 200;
// O CLAUDE.md cita estes caminhos de propósito, mas eles não moram nesta pasta. No original, a lista
// tem as pastas de ADRs antigos do repositório de origem; nesta cópia sanitizada, tem as pastas da
// aplicação e o fork das skills, que não vieram.
const FORA_DO_REPOSITORIO = ['src/', 'backend/', 'sites/', 'claude-plugins/'];

const ler = relativo => readFileSync(path.join(RAIZ, relativo), 'utf8');
const existe = relativo => existsSync(path.join(RAIZ, relativo));

// Caminho do repositório: tem "/", não começa com "/" (rota de API) e não é "dono/repo" do GitHub.
const pareceCaminho = token => token.includes('/') && !token.startsWith('/') && !/^TFTEC\//.test(token);

function caminhosCitados(texto) {
  const entreCrases = [...texto.matchAll(/`([^`\s]+)`/g)].map(m => m[1])
    .filter(t => pareceCaminho(t) || /^[A-Z]+\.md$/.test(t));
  const emLinks = [...texto.matchAll(/\]\(([^)#\s]+)(?:#[^)]*)?\)/g)].map(m => m[1])
    .filter(l => !/^https?:/.test(l));
  return [...new Set([...entreCrases, ...emLinks])];
}

const linhas = texto => texto.replace(/\r?\n$/, '').split(/\r?\n/);
const itensDoIndice = texto => linhas(texto).filter(linha => /^\s*-\s+/.test(linha));

test('o CLAUDE.md aponta para o índice de processos', () => {
  assert.ok(caminhosCitados(ler('CLAUDE.md.exemplo')).includes(INDICE), `o CLAUDE.md não cita \`${INDICE}\``);
});

test('todo caminho do repositório que o CLAUDE.md cita existe (fora os que não moram aqui)', () => {
  const quebrados = caminhosCitados(ler('CLAUDE.md.exemplo'))
    .filter(c => !FORA_DO_REPOSITORIO.includes(c))
    .filter(c => !existe(c.replace(/\*.*$/, '')));
  assert.deepEqual(quebrados, [], `ponteiros quebrados no CLAUDE.md: ${quebrados.join(', ')}`);
});

test('cada item do índice é link para arquivo que existe ou "pendente (#N)"', () => {
  assert.ok(existe(INDICE), `${INDICE} não existe`);
  const pastaDoIndice = path.dirname(INDICE);
  const itens = itensDoIndice(ler(INDICE));
  assert.ok(itens.length > 0, 'o índice não tem nenhum item');
  const problemas = [];
  for (const item of itens) {
    const links = [...item.matchAll(/\]\(([^)#\s]+)(?:#[^)]*)?\)/g)].map(m => m[1]).filter(l => !/^https?:/.test(l));
    const pendente = /pendente \(#\d+\)/.test(item);
    if (links.length === 0 && !pendente) problemas.push(`sem link nem "pendente (#N)": ${item.trim()}`);
    for (const link of links) {
      if (!existe(path.posix.join(pastaDoIndice, link))) problemas.push(`link quebrado: ${link}`);
    }
  }
  assert.deepEqual(problemas, []);
});

test(`o CLAUDE.md fica abaixo de ${LIMITE_LINHAS} linhas`, () => {
  const total = linhas(ler('CLAUDE.md.exemplo')).length;
  assert.ok(total < LIMITE_LINHAS, `o CLAUDE.md tem ${total} linhas`);
});

const CONFIG_DO_PROJETO = '.claude.exemplo/settings.json';
const SCRIPT_DO_RETRATO = 'scripts/agentes/retrato-da-partida.mjs';
// Chaves que concedem permissão ou mudam o modo de permissão, conforme a doc de settings
// (https://code.claude.com/docs/en/settings-reference.md, 29/09/2026). `defaultMode` só vale dentro
// de `permissions`, mas fica na lista para não escapar solto.
const CHAVES_DE_PERMISSAO = [
  'permissions', 'autoMode', 'defaultMode', 'disableAutoMode', 'skipDangerousModePermissionPrompt',
  'skipAutoPermissionPrompt', 'useAutoModeDuringPlan', 'allowManagedPermissionRulesOnly',
  'enableAllProjectMcpServers', 'enabledMcpjsonServers'
];
const lerConfigDoProjeto = () => {
  assert.ok(existe(CONFIG_DO_PROJETO), `${CONFIG_DO_PROJETO} não existe`);
  return JSON.parse(ler(CONFIG_DO_PROJETO));
};

// Caminhos que o hook monta a partir da raiz do projeto: "${CLAUDE_PROJECT_DIR}/x" ou "$CLAUDE_PROJECT_DIR/x",
// no `command` (forma de shell) ou nos `args` (forma exec).
function scriptsDoHook(hook) {
  const textos = [hook.command, ...(hook.args ?? [])].filter(t => typeof t === 'string');
  return textos.flatMap(t => [...t.matchAll(/\$\{?CLAUDE_PROJECT_DIR\}?["']?\/([^"'\s]+)/g)].map(m => m[1]));
}

test('a configuração do projeto declara o hook SessionStart do retrato da partida, e o script existe', () => {
  const entradas = lerConfigDoProjeto().hooks?.SessionStart ?? [];
  const comandos = entradas.flatMap(e => e.hooks ?? []).filter(h => h.type === 'command');
  assert.ok(comandos.length > 0, `${CONFIG_DO_PROJETO} não declara hook SessionStart de comando`);
  const scripts = comandos.flatMap(scriptsDoHook);
  assert.ok(scripts.includes(SCRIPT_DO_RETRATO),
    `o hook SessionStart não chama \${CLAUDE_PROJECT_DIR}/${SCRIPT_DO_RETRATO} (chama: ${scripts.join(', ') || 'nada do repositório'})`);
  assert.ok(existe(SCRIPT_DO_RETRATO), `${SCRIPT_DO_RETRATO} não existe`);
});

test('a configuração do projeto não carrega nenhuma chave de permissão', () => {
  const config = lerConfigDoProjeto();
  const proibidas = Object.keys(config).filter(chave => CHAVES_DE_PERMISSAO.includes(chave));
  assert.deepEqual(proibidas, [], `${CONFIG_DO_PROJETO} declara permissão: ${proibidas.join(', ')}`);
});
