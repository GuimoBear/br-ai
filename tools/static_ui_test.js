// static_ui_test.js — valida classify()/validate() do static_ui (puros). Uso: node tools/static_ui_test.js
'use strict';
const path = require('path');
const { classify, validate } = require(path.join(__dirname, '..', 'desktop', 'static', 'static_ui.js'));
let pass = 0, fail = 0; const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } };
const eq = (a, b, m) => ok(a === b, m + ' (got ' + a + ')');

eq(classify('c.json', { entities: [], grid: { w: 1, h: 1 } }).kind, 'scenario', 'classify cenário');
eq(classify('t.json', { spec: { type: 'selector' } }).kind, 'tree', 'classify árvore (spec)');
eq(classify('t.json', { type: 'selector', children: [] }).kind, 'tree', 'classify árvore (type+children)');
eq(classify('m.json', { monsters: [], groups: [] }).kind, 'monsters', 'classify monstros');
eq(classify('s.json', { choices: {} }).kind, 'skills', 'classify skills');
eq(classify('homun_summons.json', { choices: {} }).kind, 'summons', 'classify summons (dica no nome)');
eq(classify('x.json', { foo: 1 }).kind, 'unknown', 'classify desconhecido');

ok(validate('scenario', { entities: [], grid: { w: 10, h: 10 } }).ok, 'cenário válido');
ok(!validate('scenario', { grid: { w: 10, h: 10 } }).ok, 'cenário sem entities = inválido');
ok(!validate('scenario', { entities: [] }).ok, 'cenário sem grid = inválido');
ok(!validate('scenario', { entities: [], grid: { w: 'x', h: 1 } }).ok, 'cenário grid.w não-número = inválido');
ok(validate('tree', { spec: { type: 'selector' } }).ok, 'árvore (spec) válida');
ok(validate('tree', { type: 'selector', children: [] }).ok, 'árvore (bare) válida');
ok(!validate('tree', { spec: {} }).ok, 'árvore sem type = inválida');
ok(!validate('tree', { foo: 1 }).ok, 'árvore lixo = inválida');
ok(/cenário/.test(validate('scenario', {}).error || ''), 'erro de cenário menciona "cenário"');
ok(/árvore/.test(validate('tree', {}).error || ''), 'erro de árvore menciona "árvore"');

console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
if (fail > 0) process.exit(1);
