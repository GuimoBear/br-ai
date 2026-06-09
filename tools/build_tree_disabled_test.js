// build_tree_disabled_test.js — "Gerar Lua" PODA os nós desativados do arquivo final
// (Node tools/build_tree.js E navegador desktop/web/lib/build_tree_web.js), com paridade.
// Uso: node tools/build_tree_disabled_test.js
'use strict';
const path = require('path');
const ROOT = path.join(__dirname, '..');
const NODEB = require(path.join(ROOT, 'tools', 'build_tree.js'));
const WEB = require(path.join(ROOT, 'desktop', 'web', 'lib', 'build_tree_web.js'));
let pass = 0, fail = 0;
const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } };

const spec = { type: 'selector', children: [
  { type: 'action', name: 'KeepMe' },
  { type: 'action', name: 'DropMe', disabled: true },
  { type: 'check', name: 'CondKeep', child: { type: 'action', name: 'DropCheckChild', disabled: true } },
  { type: 'cooldown', ms: 1000, child: { type: 'action', name: 'DropDecChild', disabled: true } },
  { type: 'sequence', children: [ { type: 'action', name: 'SeqKeep' }, { type: 'action', name: 'SeqDrop', disabled: true } ] },
] };

[['Node', NODEB], ['Web', WEB]].forEach(([who, B]) => {
  const out = B.generate(spec);
  ok(out.indexOf('KeepMe') >= 0, who + ': mantém ação ativa (KeepMe)');
  ok(out.indexOf('CondKeep') >= 0, who + ': mantém o check (condição)');
  ok(out.indexOf('SeqKeep') >= 0, who + ': mantém passo ativo da sequence');
  ok(out.indexOf('DropMe') < 0, who + ': REMOVE ação desativada (DropMe)');
  ok(out.indexOf('DropCheckChild') < 0, who + ': REMOVE filho desativado do check');
  ok(out.indexOf('DropDecChild') < 0, who + ': REMOVE filho desativado do decorador');
  ok(out.indexOf('cooldown') < 0, who + ': decorador que ficou sem filho é removido');
  ok(out.indexOf('SeqDrop') < 0, who + ': REMOVE passo desativado da sequence');
  ok(out.indexOf('disabled') < 0, who + ': flag "disabled" não vai para o Lua final');
});
const body = (x) => { const i = x.indexOf('BRAI.treeSpec'); return i >= 0 ? x.slice(i) : x; };
ok(body(NODEB.generate(spec)) === body(WEB.generate(spec)), 'paridade: Node e navegador geram a MESMA árvore (corpo igual)');

// raiz inteira desativada -> árvore vazia (selector vazio), sem crash
const rootOff = NODEB.generate({ type: 'selector', disabled: true, children: [ { type: 'action', name: 'NeverRuns' } ] });
ok(rootOff.indexOf('NeverRuns') < 0, 'raiz desativada: subárvore não vai p/ o Lua');
ok(/selector/.test(rootOff), 'raiz desativada: gera um selector (vazio) válido');

console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
if (fail > 0) process.exit(1);
