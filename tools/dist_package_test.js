// dist_package_test.js — HARNESS DE DIST (Node): gera o PACOTE real via
// installer.buildPackage e valida a SAIDA (arquivos presentes/omitidos + sintaxe Lua
// via Fengari lintLua). Fecha a lacuna: nenhum teste carregava os artefatos GERADOS
// como o AI.lua faz. (PLANO-GERACAO-LUA G0/G2/G3).
// Uso: node tools/dist_package_test.js
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const LUA_BASE = path.join(ROOT, 'lua');
const installer = require(path.join(ROOT, 'desktop', 'installer.js'));
const buildTree = require(path.join(ROOT, 'tools', 'build_tree.js'));
const buildTreeWeb = require(path.join(ROOT, 'desktop', 'web', 'lib', 'build_tree_web.js'));
const host = require(path.join(ROOT, 'desktop', 'lua_host.js'));
host.init(LUA_BASE);

let pass = 0, fail = 0;
const ok = (c, m) => { if (c) { pass++; } else { fail++; console.log('  FAIL- ' + m); } };
function lint(text) { return JSON.parse(host.dispatch('lintLua', JSON.stringify({ text: text }))); }
const safeName = (n) => String(n || '').replace(/[\\/:*?"<>|]+/g, '_').replace(/\s+/g, ' ').trim();

function build(opts) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'brai-dist-'));
  const res = installer.buildPackage(Object.assign({
    root: root, luaBase: LUA_BASE, ctx: {}, catalog: { monsters: [], groups: [] },
    choices: { choices: {} }, summonChoices: { choices: {} }, buildTree: buildTree, safeName: safeName,
  }, opts));
  return { root: root, res: res, safe: safeName(opts.name) };
}
function srcFile(root, safe, f) { return path.join(root, 'trees', safe, 'dist', 'brai', 'lua', 'src', f); }
// nomes de arquivo em zip ficam em texto puro nos headers locais — basta procurar o byte-string
function zipHasEntry(zipPath, name) { return fs.readFileSync(zipPath).includes(Buffer.from(name)); }

console.log('== Pacote de dist (installer.buildPackage) ==');

const simpleSpec = { type: 'selector', children: [
  { type: 'action', name: 'AcquireTarget' }, { type: 'action', name: 'AttackTarget' } ] };
const monSpec = { type: 'selector', children: [
  { type: 'monsterCheck', group: 1, child: { type: 'action', name: 'AttackTarget' } },
  { type: 'action', name: 'AcquireTarget' } ] };
const catalog = { monsters: [{ id: 1002, desc: 'Poring' }], groups: [{ id: 1, name: 'G', members: [1002] }] };

// --- G0: pacote basico valido (sem monsterCheck) ---
{
  const { root, res, safe } = build({ name: 'Teste G0', spec: simpleSpec, ctx: { homunType: 4 } });
  const dist = path.join(root, 'trees', safe, 'dist');
  ok(fs.existsSync(path.join(dist, 'AI.lua')), 'G0: AI.lua na raiz do pacote');
  ok(fs.existsSync(path.join(dist, 'LEIA-ME.txt')), 'G0: LEIA-ME.txt presente');
  for (const f of ['tree_homun.lua', 'config.lua', 'skill_choice.lua', 'summon_choice.lua', 'skill_params.lua']) {
    const p = srcFile(root, safe, f);
    ok(fs.existsSync(p), 'G0: ' + f + ' gerado');
    if (fs.existsSync(p)) { const r = lint(fs.readFileSync(p, 'utf8')); ok(r.ok, 'G0: ' + f + ' sintaxe Lua valida' + (r.ok ? '' : ' (' + r.error + ')')); }
  }
  // G2: sem monsterCheck -> monsters.lua OMITIDO (dist e zip)
  ok(!fs.existsSync(srcFile(root, safe, 'monsters.lua')), 'G2: sem monsterCheck -> monsters.lua OMITIDO do dist');
  ok(!zipHasEntry(res.zipPath, 'brai/lua/src/monsters.lua'), 'G2: sem monsterCheck -> monsters.lua OMITIDO do zip');
  fs.rmSync(root, { recursive: true, force: true });
}

// --- G2: com monsterCheck -> monsters.lua presente, carrega, traz o catalogo ---
{
  const { root, res, safe } = build({ name: 'Teste G2', spec: monSpec, catalog: catalog, ctx: { homunType: 4 } });
  const mp = srcFile(root, safe, 'monsters.lua');
  ok(fs.existsSync(mp), 'G2: com monsterCheck -> monsters.lua PRESENTE no dist');
  ok(zipHasEntry(res.zipPath, 'brai/lua/src/monsters.lua'), 'G2: com monsterCheck -> monsters.lua PRESENTE no zip');
  if (fs.existsSync(mp)) {
    const txt = fs.readFileSync(mp, 'utf8');
    ok(lint(txt).ok, 'G2: monsters.lua sintaxe valida');
    ok(txt.includes('1002'), 'G2: monsters.lua traz o catalogo (Poring 1002)');
  }
  fs.rmSync(root, { recursive: true, force: true });
}

// --- G2: treeUsesMonsterCheck paridade node<->web + casos (aninhado/decorator/desativado) ---
{
  const cases = [ simpleSpec, monSpec, { type: 'monsterCheck' }, { type: 'cooldown', child: { type: 'monsterCheck' } },
    { type: 'selector', children: [ { type: 'monsterCheck', disabled: true } ] }, null, { type: 'action', name: 'X' } ];
  const expected = [false, true, true, true, false, false, false];
  let parity = true;
  cases.forEach((sp, i) => {
    const n = buildTree.treeUsesMonsterCheck(sp), w = buildTreeWeb.treeUsesMonsterCheck(sp);
    if (n !== w) { parity = false; }
    ok(n === expected[i], 'G2: treeUsesMonsterCheck caso ' + i + ' = ' + expected[i] + ' (node=' + n + ')');
  });
  ok(parity, 'G2: treeUsesMonsterCheck node<->web paridade');
}

// --- G3: skill_choice.lua exporta TODOS os 9 homuns (auto-descritivo) ---
{
  const all = JSON.parse(host.dispatch('allSkillChoices', JSON.stringify({ choices: {} })));
  const { root, safe } = build({ name: 'Teste G3', spec: simpleSpec, choices: { choices: all }, ctx: { homunType: 51 } });
  const txt = fs.readFileSync(srcFile(root, safe, 'skill_choice.lua'), 'utf8');
  ok(lint(txt).ok, 'G3: skill_choice.lua sintaxe valida');
  const types = [1, 2, 3, 4, 48, 49, 50, 51, 52];
  ok(types.every(function (t) { return txt.includes('["' + t + '"]'); }), 'G3: skill_choice.lua traz os 9 homuns');
  ok(txt.includes('8041') && txt.includes('8044'), 'G3: Dieter exporta Lava Slide(8041)+Blast Forge(8044)');
  ok(txt.includes('8031'), 'G3: Bayeri exporta Stahl Horn(8031)');
  // round-trip: recarregar o skill_choice.lua gerado reproduz as escolhas efetivas
  host.dispatch('setSkillChoice', JSON.stringify({ choices: {} }));
  const rt = JSON.parse(host.dispatch('lintLua', JSON.stringify({ text: txt })));
  ok(rt.ok, 'G3: skill_choice.lua gerado e carregavel (round-trip de sintaxe)');
  fs.rmSync(root, { recursive: true, force: true });
}

// --- G8: JSONs-fonte em source/ (#6) ---
{
  const sourceJson = {
    tree: JSON.stringify({ name: 'T', homunType: 51, spec: simpleSpec }),
    skills: '{"choices":{"51":{"aoeAtk":[8044]}}}',
    monsters: '{"monsters":[{"id":1002}],"groups":[]}',
    skillParams: '{"params":{"aoeAtk":{"AutoMobCount":1}}}',
  };
  // sem monsterCheck: tree.json + homun_skills.json presentes; monsters.json OMITIDO
  {
    const { root, res, safe } = build({ name: 'Teste G8a', spec: simpleSpec, sourceJson: sourceJson });
    const sdir = path.join(root, 'trees', safe, 'dist', 'source');
    ok(fs.existsSync(path.join(sdir, 'tree.json')), 'G8: source/tree.json presente');
    ok(fs.existsSync(path.join(sdir, 'homun_skills.json')), 'G8: source/homun_skills.json presente');
    ok(!fs.existsSync(path.join(sdir, 'monsters.json')), 'G8: source/monsters.json OMITIDO sem monsterCheck');
    ok(zipHasEntry(res.zipPath, 'source/tree.json') && zipHasEntry(res.zipPath, 'source/homun_skills.json'), 'G8: source/*.json no zip');
    ok(!zipHasEntry(res.zipPath, 'source/monsters.json'), 'G8: source/monsters.json fora do zip sem monsterCheck');
    ok(JSON.parse(fs.readFileSync(path.join(sdir, 'tree.json'), 'utf8')).spec.type === 'selector', 'G8: tree.json re-importável (spec)');
    ok(JSON.parse(fs.readFileSync(path.join(sdir, 'homun_skills.json'), 'utf8')).choices['51'].aoeAtk[0] === 8044, 'G8: homun_skills.json re-importável');
    ok(fs.existsSync(path.join(sdir, 'homun_skill_params.json')), 'C2: source/homun_skill_params.json presente');
    ok(zipHasEntry(res.zipPath, 'source/homun_skill_params.json'), 'C2: source/homun_skill_params.json no zip');
    fs.rmSync(root, { recursive: true, force: true });
  }
  // com monsterCheck: monsters.json também presente (casa com #2)
  {
    const { root, res, safe } = build({ name: 'Teste G8b', spec: monSpec, catalog: catalog, sourceJson: sourceJson });
    const sdir = path.join(root, 'trees', safe, 'dist', 'source');
    ok(fs.existsSync(path.join(sdir, 'monsters.json')), 'G8: source/monsters.json presente com monsterCheck');
    ok(zipHasEntry(res.zipPath, 'source/monsters.json'), 'G8: source/monsters.json no zip com monsterCheck');
    fs.rmSync(root, { recursive: true, force: true });
  }
}

// --- C2: skill_params.lua (parâmetros por homún/papel) no zip + conteúdo + paridade ---
{
  const skillParams = { params: { aoeAtk: { AutoMobCount: 1, AoEMaximizeTargets: true } }, overrides: { '51': { aoeAtk: { AutoMobCount: 3 } } } };
  const { root, res, safe } = build({ name: 'Teste C2', spec: simpleSpec, skillParams: skillParams,
    sourceJson: { tree: '{}', skills: '{"choices":{}}', skillParams: JSON.stringify(skillParams) } });
  const sp = srcFile(root, safe, 'skill_params.lua');
  ok(fs.existsSync(sp), 'C2: skill_params.lua no dist');
  ok(zipHasEntry(res.zipPath, 'brai/lua/src/skill_params.lua'), 'C2: skill_params.lua no zip');
  const txt = fs.readFileSync(sp, 'utf8');
  ok(lint(txt).ok, 'C2: skill_params.lua sintaxe válida');
  ok(txt.includes('aoeAtk') && txt.includes('AutoMobCount') && txt.includes('AoEMaximizeTargets'), 'C2: skill_params.lua traz aoeAtk knobs (global)');
  ok(txt.includes('overrides') && txt.includes('["51"]'), 'C2: skill_params.lua traz overrides por homúnculo');
  ok(txt.includes('BRAI.setSkillParams'), 'C2: skill_params.lua chama setSkillParams');
  // source re-importável
  const sdir = path.join(root, 'trees', safe, 'dist', 'source');
  { const j = JSON.parse(fs.readFileSync(path.join(sdir, 'homun_skill_params.json'), 'utf8')); ok(j.params.aoeAtk.AutoMobCount === 1 && j.overrides['51'].aoeAtk.AutoMobCount === 3, 'C2: source/homun_skill_params.json re-importável (global+overrides)'); }
  fs.rmSync(root, { recursive: true, force: true });
  // paridade node<->web de generateSkillParams
  const bn = buildTree.generateSkillParams(skillParams), wn = buildTreeWeb.generateSkillParams(skillParams);
  const body = x => { const i = x.indexOf('local params'); return i >= 0 ? x.slice(i) : x; };
  ok(body(bn) === body(wn), 'C2: generateSkillParams node<->web paridade');
}

console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
if (fail > 0) process.exit(1);
