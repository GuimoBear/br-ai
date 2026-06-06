#!/usr/bin/env node
// run_lua_tests.js — roda todos os tools/*_test.lua + outputs_chk.lua num
// interpretador Lua e sai com código != 0 se algum falhar (para CI e uso local).
//
// Uso:
//   node tools/run_lua_tests.js            # autodetecta lua / luajit / texlua no PATH
//   node tools/run_lua_tests.js lua5.1     # força um interpretador específico
'use strict';
const { spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');

function detect() {
  if (process.argv[2]) return process.argv[2];
  for (const c of ['lua', 'lua5.4', 'lua5.3', 'lua5.2', 'lua5.1', 'luajit', 'texlua']) {
    const r = spawnSync(c, ['-v'], { encoding: 'utf8' });
    if (!r.error) return c;
  }
  return null;
}

const lua = detect();
if (!lua) {
  console.error('Nenhum interpretador Lua encontrado no PATH (tente instalar lua5.1+ ou texlua).');
  process.exit(2);
}

const tests = fs.readdirSync(path.join(root, 'tools'))
  .filter((f) => /_test\.lua$/.test(f)).sort();

console.log('Interpretador: ' + lua + '  |  ' + tests.length + ' arquivos de teste\n');
let fail = 0;
function run(file) {
  const r = spawnSync(lua, [file], { cwd: root, encoding: 'utf8' });
  const out = (r.stdout || '') + (r.stderr || '');
  const res = (out.match(/RESULTADO:[^\n]*/) || [''])[0];
  if (r.status === 0) {
    console.log('  ok    ' + file.padEnd(32) + (res ? '  ' + res : ''));
  } else {
    fail++;
    console.log('  FALHA ' + file.padEnd(32) + '  (exit ' + r.status + ')');
    process.stdout.write(out.split('\n').slice(-8).join('\n') + '\n');
  }
}
for (const t of tests) run(path.join('tools', t));
run('outputs_chk.lua');

console.log('\n' + (fail === 0 ? 'TUDO VERDE' : fail + ' FALHA(S)') +
  ' — ' + (tests.length + 1 - fail) + '/' + (tests.length + 1));
process.exit(fail ? 1 : 0);
