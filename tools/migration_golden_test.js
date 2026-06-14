// migration_golden_test.js — regressão ponta-a-ponta com o USER_AI/ real do repo.
// Trava o resultado da migração e valida a estrutura do spec gerado (nomes de nós,
// monsterCheck com group+filho). Atualize as expectativas se a fonte/mapeamento mudar de propósito.
'use strict';
var assert = require('assert');
var fs = require('fs');
var path = require('path');
var M = path.join(__dirname, '..', 'desktop', 'shared', 'migration');
var migrate = require(path.join(M, 'migrate.js')).migrate;

var n = 0; function ok(c, m) { n++; assert.ok(c, m); }
function eq(a, b, m) { n++; assert.deepStrictEqual(a, b, m); }

// nomes válidos no registry do BR-AI (folhas usadas pela árvore + pela migração)
var ACTIONS = ['AcquireOwnerAttacker', 'AcquireTarget', 'AttackTarget', 'ChaseTarget', 'DanceAttack', 'Flee', 'HandleOwnerCommand', 'Idle', 'IdleWalk', 'Kite', 'MoveToOwner', 'ReacquireIfBetter', 'RescueOwner', 'SetStyle', 'UseAoESkill', 'UseCastling', 'UseCombo', 'UseDefensiveBuff', 'UseEleanorOffense', 'UseHealOwner', 'UseHealSelf', 'UseMainSkill', 'UseOffensiveBuff', 'UseOwnerBuff', 'UseSeraLegion', 'UseSkill', 'UseSkillBuff', 'UseSummon'];
var CONDS = ['BeingAttacked', 'CanEngage', 'HasOwnerCommand', 'HasValidTarget', 'HpAbove', 'HpBelow', 'InAttackRange', 'LegionActive', 'LegionBelow', 'LegionExpiring', 'Mobbed', 'OwnerHpAbove', 'OwnerHpBelow', 'OwnerUnderAttack', 'SafeToGrapple', 'SelfUnderAttack', 'ShouldFlee', 'SpAbove', 'StyleIs', 'TargetIsBoss', 'TooFarFromOwner'];
var COMPOSITES = ['selector', 'sequence', 'parallel'];
var DECOS = ['inverter', 'succeeder', 'cooldown', 'limiter'];

function validateSpec(node, where) {
  ok(node && typeof node === 'object', where + ': nó objeto');
  var t = node.type;
  if (COMPOSITES.indexOf(t) >= 0) { ok(Array.isArray(node.children), where + ': composite tem children'); node.children.forEach(function (c, i) { validateSpec(c, where + '/' + i); }); }
  else if (DECOS.indexOf(t) >= 0) { if (node.child) validateSpec(node.child, where + '/child'); }
  else if (t === 'check') { ok(CONDS.indexOf(node.name) >= 0, where + ': condição conhecida (' + node.name + ')'); if (node.child) validateSpec(node.child, where + '/child'); }
  else if (t === 'monsterCheck') { ok((node.group && node.group !== 0) || (node.monster && node.monster !== 0), where + ': monsterCheck tem group/monster'); ok(!!node.child, where + ': monsterCheck tem filho'); validateSpec(node.child, where + '/child'); }
  else if (t === 'condition') { ok(CONDS.indexOf(node.name) >= 0, where + ': condition conhecida (' + node.name + ')'); }
  else if (t === 'action') { ok(ACTIONS.indexOf(node.name) >= 0, where + ': ação conhecida (' + node.name + ')'); }
  else { ok(false, where + ': tipo desconhecido ' + t); }
}

// carrega o USER_AI/ real
var dir = path.join(__dirname, '..', 'USER_AI');
if (!fs.existsSync(dir)) { console.log('SKIP migration_golden: USER_AI/ ausente neste ambiente (fonte AzzyAI local).'); process.exit(0); }
var files = {};
fs.readdirSync(dir).forEach(function (f) { if (/\.lua$/i.test(f)) { try { files[f] = fs.readFileSync(path.join(dir, f), 'latin1'); } catch (e) {} } });

var r = migrate(files, { name: 'azzyai-teste' });

// ---- regressão (valores-chave do USER_AI atual) ----
eq(r.wrapper.homunType, 51, 'tipo detectado = Dieter (mais skills no SkillList)');
eq(r.wrapper.baseType, 2, 'baseType = OldHomunType');
eq(r.config.UseAutoHeal, false, 'UseAutoHeal=0 → false');
eq(r.config.HealOwnerHP, 40, 'HealOwnerHP');
eq(r.config.AttackSkillReserveSP, 400, 'AttackSkillReserveSP');
eq(r.config.AutoComboSpheres, 10, 'AutoComboSpheres');
ok(r.config.BossGroup > 0, 'BossGroup do H_Avoid');
eq(r.skillChoices.choices['51'].aoeAtk, 8044, 'Dieter aoeAtk = Blast Forge');
eq(r.skillChoices.choices['51'].offBuff, 8045, 'Dieter offBuff = Tempering');

// Red Plant + Blue Plant no MESMO grupo (agrupamento por tupla idêntica)
var gPlant = r.monsters.groups.filter(function (g) { return g.members.indexOf(1078) >= 0; })[0];
ok(gPlant && gPlant.members.indexOf(1079) >= 0, 'Red(1078) e Blue(1079) Plant no mesmo grupo');

// singles: monstro com tática própria (1 membro) vira "tática por monstro", não grupo
ok(Array.isArray(r.singles) && r.singles.length > 0, 'há táticas por monstro (singles): ' + (r.singles || []).length);
ok(!r.monsters.groups.some(function (g) { return g.members.length === 1; }), 'nenhum grupo tem só 1 membro (viraram singles)');
ok(r.singles.some(function (sg) { return sg.id === 1042; }), 'Steel Chonchon (1042) é um single');

// ramos desativados por Use*=0
var disabled = [];
require(path.join(M, 'migrate.js'))._walk(r.wrapper.spec, function (nd) { if (nd.disabled) disabled.push(nd.label || nd.name); });
ok(disabled.indexOf('cura-urgente') >= 0, 'cura-urgente desativada (UseAutoHeal=0)');

// monsterCheck injetados + estrutura do spec válida
var mc = 0; require(path.join(M, 'migrate.js'))._walk(r.wrapper.spec, function (nd) { if (nd.type === 'monsterCheck') mc++; });
ok(mc > 0, 'pelo menos um monsterCheck injetado');
validateSpec(r.wrapper.spec, 'root');

// contadores presentes
ok(r.report.counts.mapped > 0 && r.report.counts.groups > 0, 'contadores do relatório');

// ---- Fase 5: override da forma base (opts.baseType) ----
var rb = migrate(files, { homunType: 51, baseType: 3 });
eq(rb.wrapper.baseType, 3, 'opts.baseType sobrescreve a forma base');
eq(rb.config.BaseHomunType, 3, 'config.BaseHomunType segue o override');
eq(migrate(files, { homunType: 3, baseType: 2 }).wrapper.baseType, 0, 'tipo nao-S ignora baseType');

// ---- Fase 5: applyGroupNames renomeia grupo + label do no monsterCheck ----
var applyGroupNames = require(path.join(M, 'migrate.js')).applyGroupNames;
var walk = require(path.join(M, 'migrate.js'))._walk;
var g0 = rb.monsters.groups[0];
var origName = g0.name;
applyGroupNames(rb, {});
eq(rb.monsters.groups[0].name, origName, 'override vazio = no-op');
var ov = {}; ov[g0.id] = 'Custom XYZ';
applyGroupNames(rb, ov);
eq(rb.monsters.groups[0].name, 'Custom XYZ', 'grupo renomeado');
var lbl = null; walk(rb.wrapper.spec, function (nd) { if (nd.type === 'monsterCheck' && nd.group === g0.id) lbl = nd.label; });
eq(lbl, 'Custom XYZ', 'label do monsterCheck renomeado');
applyGroupNames(rb, { 999999: 'x' });
eq(rb.monsters.groups[0].name, 'Custom XYZ', 'id inexistente = no-op');
var ov2 = {}; ov2[g0.id] = '   ';
applyGroupNames(rb, ov2);
eq(rb.monsters.groups[0].name, 'Custom XYZ', 'nome em branco nao sobrescreve');

// grava um snapshot p/ referência/depuração (não falha o teste)
try {
  fs.mkdirSync(path.join(M, 'fixtures'), { recursive: true });
  fs.writeFileSync(path.join(M, 'fixtures', 'expected.json'), JSON.stringify({
    homunType: r.wrapper.homunType, baseType: r.wrapper.baseType, config: r.config,
    skillChoices: r.skillChoices, counts: r.report.counts,
    groups: r.monsters.groups.map(function (g) { return { id: g.id, name: g.name, members: g.members.length }; }),
  }, null, 2));
} catch (e) {}

console.log('RESULTADO migration_golden: ' + n + ' asserções OK (spec válido, ' + mc + ' monsterCheck, ' + r.monsters.groups.length + ' grupos)');
