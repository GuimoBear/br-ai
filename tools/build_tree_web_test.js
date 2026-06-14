// build_tree_web_test.js — o codegen do navegador (build_tree_web.js) grava o config completo
// e em PARIDADE com tools/build_tree.js. Uso: node tools/build_tree_web_test.js
'use strict';
var assert = require('assert');
var path = require('path');
global.window = global.window || {};
require(path.join(__dirname, '..', 'desktop', 'web', 'lib', 'build_tree_web.js'));
var web = global.window.BRAI_BUILD;
var node = require(path.join(__dirname, 'build_tree.js'));

var n = 0; function ok(c, m) { n++; assert.ok(c, m); }
function eq(a, b, m) { n++; assert.deepStrictEqual(a, b, m); }

var ctx = { homunType: 51, baseType: 2, config: { AggroHP: 55, UseAutoHeal: false, BossGroup: 18, HealOwnerHP: 40, KSMode: 'polite', UseBaseSkills: true } };
var cw = web.generateConfig(ctx);
['AggroHP = 55', 'UseAutoHeal = false', 'BossGroup = 18', 'HealOwnerHP = 40', 'KSMode = "polite"', 'BaseHomunType = 2', 'UseBaseSkills = true']
  .forEach(function (t) { ok(cw.indexOf(t) >= 0, 'web config contém: ' + t); });

// paridade: o CORPO do config (linhas "\tKey = val,") é idêntico entre web e node
function cfgLines(s) { return s.split('\n').filter(function (l) { return /^\t\S+ = /.test(l); }).sort(); }
eq(cfgLines(cw), cfgLines(node.generateConfig(ctx)), 'web e node geram o MESMO corpo de config');

// retrocompat: sem config → BaseHomunType presente
ok(/BaseHomunType = 2/.test(web.generateConfig({ homunType: 51, baseType: 2 })), 'sem config → BaseHomunType presente');
// skill levels continuam: generateSkillChoice com *Level
ok(/aoeAtkLevel = 10/.test(web.generateSkillChoice({ choices: { '51': { aoeAtk: 8044, aoeAtkLevel: 10 } } })), 'web skill_choice carrega nível');

// F6: bloco combo (Eleanor) serializado + paridade web↔node
var scCombo = { choices: { '52': { combo: { style: 'grapple', comboSpheres: 7, window: 2500, levels: { power: [5, 4, 3], grapple: [2, 2, 2] } } } } };
var wc = web.generateSkillChoice(scCombo), nc = node.generateSkillChoice(scCombo);
ok(/combo = \{/.test(wc), 'web: bloco combo serializado');
ok(/style = "grapple"/.test(wc) && /comboSpheres = 7/.test(wc) && /window = 2500/.test(wc), 'web: campos do combo presentes');
ok(/levels = \{/.test(wc), 'web: levels do combo serializados');
function scBody(x) { return x.slice(x.indexOf('local choices =')); }   // ignora o cabeçalho (nomeia o gerador)
eq(scBody(wc), scBody(nc), 'web e node geram o MESMO corpo de skill_choice (com combo)');

// M6: aoeAtk LISTA + skillLevels serializados + paridade web↔node
var scMulti = { choices: { '51': { aoeAtk: [8041, 8045], skillLevels: { '8041': 3 } } } };
var wm = web.generateSkillChoice(scMulti), nm = node.generateSkillChoice(scMulti);
ok(/aoeAtk = \{/.test(wm), 'web: aoeAtk como lista (tabela Lua)');
ok(/skillLevels = \{/.test(wm), 'web: skillLevels serializado');
eq(scBody(wm), scBody(nm), 'web e node: MESMO corpo de skill_choice (lista + skillLevels)');

// N5: lista VAZIA (= nenhuma skill) serializada + paridade web↔node
var scEmpty = { choices: { '51': { aoeAtk: [] } } };
var we = web.generateSkillChoice(scEmpty), ne = node.generateSkillChoice(scEmpty);
ok(/aoeAtk = \{\s*\}/.test(we), 'web: aoeAtk vazio serializado (nenhuma skill)');
eq(scBody(we), scBody(ne), 'web e node: MESMO corpo de skill_choice (lista vazia)');

console.log('RESULTADO build_tree_web: ' + n + ' asserções OK');
