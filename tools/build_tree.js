#!/usr/bin/env node
// build_tree.js — gera um modulo Lua (tabela BRAI.treeSpec) a partir de um JSON.
// A FONTE DA VERDADE da arvore e o JSON (editado no editor visual); o Lua e gerado.
// Uso: node tools/build_tree.js [entrada.json] [saida.lua]
//   padrao: desktop/shared/tree_homun.json -> lua/src/tree_homun.lua
'use strict';
const fs = require('fs');
const path = require('path');

const IDENT = /^[A-Za-z_][A-Za-z0-9_]*$/;

function luaString(s) {
  return '"' + String(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t') + '"';
}

function luaValue(v, indent) {
  if (v === null || v === undefined) return 'nil';
  const t = typeof v;
  if (t === 'boolean') return v ? 'true' : 'false';
  if (t === 'number') return Number.isInteger(v) ? String(v) : String(v);
  if (t === 'string') return luaString(v);
  if (Array.isArray(v)) return luaArray(v, indent);
  if (t === 'object') return luaObject(v, indent);
  throw new Error('tipo nao suportado: ' + t);
}

function luaArray(arr, indent) {
  if (arr.length === 0) return '{}';
  const pad = '\t'.repeat(indent + 1);
  const items = arr.map(x => pad + luaValue(x, indent + 1));
  return '{\n' + items.join(',\n') + '\n' + '\t'.repeat(indent) + '}';
}

function luaObject(obj, indent) {
  const keys = Object.keys(obj);
  if (keys.length === 0) return '{}';
  const pad = '\t'.repeat(indent + 1);
  const parts = keys.map(k => {
    const key = IDENT.test(k) ? k : '[' + luaString(k) + ']';
    return pad + key + ' = ' + luaValue(obj[k], indent + 1);
  });
  return '{\n' + parts.join(',\n') + '\n' + '\t'.repeat(indent) + '}';
}

function pruneDisabled(spec) {
  if (!spec || typeof spec !== 'object') return spec;
  if (spec.disabled) return null;
  var out = {};
  var keys = Object.keys(spec);
  for (var i = 0; i < keys.length; i++) {
    var k = keys[i];
    if (k === 'disabled') continue;
    if (k === 'children' && Array.isArray(spec.children)) {
      var arr = [];
      for (var j = 0; j < spec.children.length; j++) { var pc = pruneDisabled(spec.children[j]); if (pc != null) arr.push(pc); }
      out.children = arr;
    } else if (k === 'child') {
      out.child = spec.child ? pruneDisabled(spec.child) : null;
    } else {
      out[k] = spec[k];
    }
  }
  var DEC_REQ = { inverter: 1, succeeder: 1, cooldown: 1, limiter: 1 };
  if (DEC_REQ[out.type] && out.child == null) return null;
  return out;
}

// treeUsesMonsterCheck(spec): a árvore (após poda de desativados) usa algum nó monsterCheck?
// Só esse nó consome o catálogo de monstros/grupos; sem ele, monsters.lua é inútil no pacote.
// Recursivo em children/child; ignora subárvores desativadas (que o codegen poda). [PLANO-GERACAO-LUA #2]
function treeUsesMonsterCheck(spec) {
  if (!spec || typeof spec !== 'object') return false;
  if (spec.disabled) return false;
  if (spec.type === 'monsterCheck') return true;
  if (Array.isArray(spec.children)) {
    for (var i = 0; i < spec.children.length; i++) if (treeUsesMonsterCheck(spec.children[i])) return true;
  }
  if (spec.child && treeUsesMonsterCheck(spec.child)) return true;
  return false;
}

function generate(spec) {
  spec = pruneDisabled(spec) || { type: 'selector', children: [] };
  return [
    '-- tree_homun.lua — GERADO por tools/build_tree.js. Nao editar a mao.',
    '-- Fonte da verdade: o JSON correspondente (editor visual).',
    'BRAI = BRAI or {}',
    '',
    'BRAI.treeSpec = ' + luaValue(spec, 0),
    '',
    'return BRAI.treeSpec',
    '',
  ].join('\n');
}

function main() {
  const root = path.join(__dirname, '..');
  const input = process.argv[2] || path.join(root, 'desktop', 'shared', 'tree_homun.json');
  const output = process.argv[3] || path.join(root, 'lua', 'src', 'tree_homun.lua');
  const spec = JSON.parse(fs.readFileSync(input, 'utf8'));
  if (!spec || !spec.type) throw new Error('JSON invalido: raiz sem "type"');
  fs.writeFileSync(output, generate(spec), 'utf8');
  console.log('OK: ' + path.relative(root, input) + ' -> ' + path.relative(root, output));
}

if (require.main === module) main();
const HOMUN_NAMES = { 1: 'Lif', 2: 'Amistr', 3: 'Filir', 4: 'Vanilmirth', 48: 'Eira', 49: 'Bayeri', 50: 'Sera', 51: 'Dieter', 52: 'Eleanor' };

// Gera o config.lua de runtime de uma árvore (forma base do Homunculus S, etc).
function generateConfig(ctx) {
  ctx = ctx || {};
  const ht = ctx.homunType || 0, bt = ctx.baseType || 0;
  const hn = HOMUN_NAMES[ht] || ('tipo ' + ht);
  const bn = bt ? (HOMUN_NAMES[bt] || ('tipo ' + bt)) : 'nenhuma';
  // mescla a config migrada (ctx.config) e garante BaseHomunType
  const cfg = {};
  const src = ctx.config || {};
  Object.keys(src).forEach(function (k) { if (src[k] !== undefined && src[k] !== null) cfg[k] = src[k]; });
  if (cfg.BaseHomunType === undefined) cfg.BaseHomunType = bt;
  const lines = Object.keys(cfg).map(function (k) {
    const key = IDENT.test(k) ? k : '[' + luaString(k) + ']';
    return '\t' + key + ' = ' + luaValue(cfg[k], 1) + ',';
  });
  return [
    '-- config.lua — GERADO por tools/build_tree.js. Nao editar a mao.',
    '-- Config de runtime desta arvore (knobs migrados / forma base). Copie junto com tree_homun.lua.',
    '-- Homunculo: ' + hn + ' · Forma base: ' + bn,
    'BRAI = BRAI or {}',
    '',
    'BRAI.userConfig = {',
    lines.join('\n'),
    '}',
    '',
    'return BRAI.userConfig',
    '',
  ].join('\n');
}


// Gera monsters.lua — catálogo de monstros/grupos p/ os nós monsterCheck no cliente.
// Carrega BRAI.monsterGroups (se já presente via bootstrap) com o catálogo inline.
function generateMonsters(catalog) {
  catalog = catalog || {};
  const monsters = Array.isArray(catalog.monsters) ? catalog.monsters : [];
  const groups = Array.isArray(catalog.groups) ? catalog.groups : [];
  const data = { monsters: monsters, groups: groups };
  return [
    '-- monsters.lua — GERADO por tools/build_tree.js. Nao editar a mao.',
    '-- Catalogo de monstros/grupos (cadastro do editor) p/ os nos monsterCheck.',
    'BRAI = BRAI or {}',
    '',
    'local catalog = ' + luaValue(data, 0),
    '',
    'if BRAI.monsterGroups then BRAI.monsterGroups.load(catalog) end',
    'BRAI.monsterCatalog = catalog',
    '',
    'return catalog',
    '',
  ].join('\n');
}

function generateSkillChoice(choices) {
  const src = (choices && choices.choices) ? choices.choices : (choices || {});
  const data = {};
  Object.keys(src).forEach(function (k) {
    const roles = src[k] || {}, r = {};
    ['mainAtk', 'aoeAtk', 'offBuff', 'defBuff'].forEach(function (rk) {
      const rv = roles[rk];
      if (Array.isArray(rv)) { const lst = rv.map(function (x) { return parseInt(x, 10); }).filter(function (x) { return x > 0; }); r[rk] = lst; }   // lista (inclui VAZIA = nenhuma skill)
      else { const v = parseInt(rv, 10); if (v > 0) r[rk] = v; }
      const lv = parseInt(roles[rk + 'Level'], 10);   // nível por papel (migrado da AzzyAI)
      if (lv > 0) r[rk + 'Level'] = lv;
    });
    if (roles.combo && typeof roles.combo === 'object') r.combo = roles.combo;   // padrão de combo (Eleanor)
    if (roles.skillLevels && typeof roles.skillLevels === 'object') {            // nível por skill
      const sl = {}; Object.keys(roles.skillLevels).forEach(function (id) { const lv2 = parseInt(roles.skillLevels[id], 10); if (lv2 > 0) sl[String(id)] = lv2; });
      if (Object.keys(sl).length) r.skillLevels = sl;
    }
    if (roles.skillGate && typeof roles.skillGate === 'object') {                // gate "possui a skill X"
      const sg = {}; Object.keys(roles.skillGate).forEach(function (id) { const g = roles.skillGate[id]; const gs = g && parseInt(g.skill, 10); if (gs > 0) sg[String(id)] = { skill: gs, negate: !!g.negate }; });
      if (Object.keys(sg).length) r.skillGate = sg;
    }
    if (Object.keys(r).length) data[String(k)] = r;
  });
  return [
    '-- skill_choice.lua — GERADO por tools/build_tree.js. Nao editar a mao.',
    '-- Escolha de skill por papel/homunculo (tela "Skills por homunculo" do editor).',
    'BRAI = BRAI or {}',
    '',
    'local choices = ' + luaValue({ choices: data }, 0),
    '',
    'if BRAI.setSkillChoice then BRAI.setSkillChoice(choices) end',
    'BRAI.skillChoiceRaw = choices',
    '',
    'return choices',
    '',
  ].join('\n');
}

function generateSummonChoice(choices) {
  const src = (choices && choices.choices) ? choices.choices : (choices || {});
  const data = {};
  Object.keys(src).forEach(function (k) {
    const p = src[k] || {}, r = {};
    if (p.level != null && parseInt(p.level, 10) >= 1) r.level = parseInt(p.level, 10);
    if (typeof p.resummon === 'string') r.resummon = p.resummon;
    if (p.minCount != null && parseInt(p.minCount, 10) >= 1) r.minCount = parseInt(p.minCount, 10);
    if (p.minMobCount != null && parseInt(p.minMobCount, 10) >= 0) r.minMobCount = parseInt(p.minMobCount, 10);
    if (typeof p.vsBossOnly === 'boolean') r.vsBossOnly = p.vsBossOnly;
    if (Object.keys(r).length) data[String(k)] = r;
  });
  return [
    '-- summon_choice.lua — GERADO por tools/build_tree.js. Nao editar a mao.',
    '-- Config de invocacoes por homunculo (tela "Skills" do editor, sub-painel).',
    'BRAI = BRAI or {}',
    '',
    'local choices = ' + luaValue({ choices: data }, 0),
    '',
    'if BRAI.setSummonChoice then BRAI.setSummonChoice(choices) end',
    'BRAI.summonChoiceRaw = choices',
    '',
    'return choices',
    '',
  ].join('\n');
}

function generateSkillParams(params) {
  const src = params || {};
  const gIn = src.params || src.global || {};
  const oIn = src.overrides || src.byHomun || {};
  const clean = function (knobs) { const rr = {}; Object.keys(knobs || {}).forEach(function (key) { const v = knobs[key]; if (typeof v === 'number' || typeof v === 'boolean') rr[key] = v; }); return rr; };
  const global = {};
  Object.keys(gIn).forEach(function (role) { const rr = clean(gIn[role]); if (Object.keys(rr).length) global[role] = rr; });
  const overrides = {};
  Object.keys(oIn).forEach(function (h) { const roles = oIn[h] || {}, hr = {}; Object.keys(roles).forEach(function (role) { const rr = clean(roles[role]); if (Object.keys(rr).length) hr[role] = rr; }); if (Object.keys(hr).length) overrides[String(h)] = hr; });
  return [
    '-- skill_params.lua — GERADO por tools/build_tree.js. Nao editar a mao.',
    '-- Parametros das acoes de skill: global (todos) + overrides por homunculo.',
    'BRAI = BRAI or {}',
    '',
    'local params = ' + luaValue({ params: global, overrides: overrides }, 0),
    '',
    'if BRAI.setSkillParams then BRAI.setSkillParams(params) end',
    'BRAI.skillParamsRaw = params',
    '',
    'return params',
    '',
  ].join('\n');
}

module.exports = { generate, generateConfig, generateMonsters, generateSkillChoice, generateSummonChoice, generateSkillParams, treeUsesMonsterCheck };
