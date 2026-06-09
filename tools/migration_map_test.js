// migration_map_test.js — testes de unidade dos mapeadores (config, skills, táticas, misc).
'use strict';
var assert = require('assert');
var path = require('path');
var M = path.join(__dirname, '..', 'desktop', 'shared', 'migration');
var mapCfg = require(path.join(M, 'map_config.js'));
var mapSkl = require(path.join(M, 'map_skills.js'));
var mapTac = require(path.join(M, 'map_tactics.js'));
var mapMsc = require(path.join(M, 'map_misc.js'));
var migrate = require(path.join(M, 'migrate.js'));

var n = 0; function ok(c, m) { n++; assert.ok(c, m); }
function eq(a, b, m) { n++; assert.deepStrictEqual(a, b, m); }
function find(rows, pred) { return rows.filter(pred); }

// ---------------------------------------------------------------- map_config
(function () {
  var r = mapCfg.mapConfig({
    AggroHP: 55, HealOwnerHP: 40, AutoMobCount: 3, UseAutoHeal: 0, UseAttackSkill: 1,
    OldHomunType: 2, UseSeraCallLegion: 0, DoNotChase: 1,
    StationaryMoveBounds: 14, MobileMoveBounds: 9, SuperPassive: 0,
  });
  eq(r.config.AggroHP, 55, 'direto AggroHP');
  eq(r.config.HealOwnerHP, 40, 'direto HealOwnerHP');
  eq(r.config.UseAutoHeal, false, 'bool 0 → false');
  eq(r.config.UseAttackSkill, true, 'bool 1 → true');
  eq(r.config.BaseHomunType, 2, 'OldHomunType → BaseHomunType');
  eq(r.config.UseSummon, false, 'UseSeraCallLegion=0 → UseSummon false');
  eq(r.config.MoveBounds, 14, 'par estacionário/móvel → maior');
  // toggles
  var tg = {}; r.branchToggles.forEach(function (t) { tg[JSON.stringify(t.match)] = t.enabled; });
  eq(tg[JSON.stringify({ label: 'cura-urgente' })], false, 'UseAutoHeal=0 desativa cura-urgente');
  eq(tg[JSON.stringify({ action: 'ChaseTarget' })], false, 'DoNotChase=1 desativa ChaseTarget');
  ok(r.consumed.AggroHP && r.consumed.DoNotChase, 'marca consumed');
})();

// ---------------------------------------------------------------- map_skills
(function () {
  // Dieter: Blast Forge (override do Lava Slide) + Tempering (override do Pyroclastic) + níveis
  var sl = { 51: { 8044: 0 } };
  var r = mapSkl.mapSkills(sl, {
    UseDieterLavaSlide: 0, UseDieterBlastForge: 1,
    UseDieterPyroclastic: 0, UseDieterTempering: 1, UseDieterTemperingLevel: 10,
    DieterLavaSlideLevel: 7,
  });
  var c = r.skillChoices.choices['51'];
  eq(c.aoeAtk, 8044, 'Dieter aoeAtk = Blast Forge (override)');
  eq(c.offBuff, 8045, 'Dieter offBuff = Tempering (override)');
  eq(c.offBuffLevel, 10, 'nível do Tempering');

  // Sera: papel padrão (sem override), só nível
  var r2 = mapSkl.mapSkills({}, { UseSeraParalyze: 1, SeraParalyzeLevel: 10 });
  var c2 = r2.skillChoices.choices['50'] || {};
  eq(c2.mainAtk, undefined, 'Sera mainAtk == padrão → sem override de id');
  eq(c2.mainAtkLevel, 10, 'Sera mainAtk nível migrado');

  // Sera: skill desabilitada → papel desativado + nota
  var r3 = mapSkl.mapSkills({}, { UseSeraPoisonMist: 0 });
  ok(r3.disabledRoles[50] && r3.disabledRoles[50].aoeAtk, 'Sera aoe desativado');
})();

// ---------------------------------------------------------------- map_tactics
(function () {
  // tuplas idênticas (Red+Blue) → mesmo grupo; Steel diferente → grupo próprio; default pulado
  var raw = [
    'MyTact[0]={4,100,0} --Default',
    'MyTact[1042]={2,-1,0} --Steel Chonchon',
    'MyTact[1078]={5,0,0} --Red Plant',
    'MyTact[1079]={5,0,0} --Blue Plant',
    'MyTact[9999]={4,100,0} --Igual ao default',
    'MyTact[1111]={11,-3,2} --Drainliar Snipe+Kite',
  ].join('\n');
  var myTact = { 0: t([4, 100, 0]), 1042: t([2, -1, 0]), 1078: t([5, 0, 0]), 1079: t([5, 0, 0]), 9999: t([4, 100, 0]), 1111: t([11, -3, 2]) };
  var r = mapTac.mapTactics(myTact, { 1039: 1 }, raw);

  // Red+Blue (2 monstros) → MESMO grupo
  var plant = r.groups.filter(function (g) { return g.members.indexOf(1078) >= 0; })[0];
  ok(plant && plant.members.indexOf(1079) >= 0, 'Red e Blue Plant no MESMO grupo (2 membros)');
  // Steel (1 monstro) → SINGLE, não grupo
  ok(!r.groups.some(function (g) { return g.members.indexOf(1042) >= 0; }), 'Steel (1 monstro) NÃO vira grupo');
  ok((r.singles || []).some(function (sg) { return sg.id === 1042; }), 'Steel é tática por monstro (single)');
  // default pulado (nem grupo nem single)
  ok(!r.groups.some(function (g) { return g.members.indexOf(9999) >= 0; }) && !(r.singles || []).some(function (sg) { return sg.id === 9999; }), 'tupla == default é pulada');
  // nomes vêm dos comentários
  var mNames = {}; r.monsters.forEach(function (m) { mNames[m.id] = m.desc; });
  eq(mNames[1078], 'Red Plant', 'desc do comentário (grupo)');
  var dr = (r.singles || []).filter(function (sg) { return sg.id === 1111; })[0];
  eq(dr && dr.desc, 'Drainliar Snipe+Kite', 'single carrega desc do comentário');
  // avoid → grupo boss + bossGroupId
  ok(r.bossGroupId > 0, 'bossGroupId definido a partir de H_Avoid');
  ok(r.groups.some(function (g) { return g.members.indexOf(1039) >= 0; }), 'MVP do avoid num grupo');
  // ramo: 1 monsterCheck por grupo E por single; cada um tem (group|monster) + filho
  ok(r.tacticsBranch && r.tacticsBranch.type === 'selector' && r.tacticsBranch.children.length === r.groups.length + (r.singles || []).length, 'ramo: 1 monsterCheck por grupo e por single');
  ok(r.tacticsBranch.children.every(function (c) { return c.type === 'monsterCheck' && ((c.group > 0) || (c.monster > 0)) && c.child; }), 'cada monsterCheck tem group/monster + filho');
  // kite no single Drainliar → monsterCheck(monster=1111) → filho Kite
  var kiteNode = r.tacticsBranch.children.filter(function (c) { return c.monster === 1111; })[0];
  eq(kiteNode && kiteNode.child.name, 'Kite', 'Drainliar (single, KITE_ALWAYS) → filho Kite');
  function t(arr) { var o = {}; arr.forEach(function (v, i) { o[i + 1] = v; }); return o; }
})();

// ---------------------------------------------------------------- map_misc
(function () {
  var r = mapMsc.mapMisc({ 1529417: 1, 2322797: 12 }, {});
  ok(r.notes.length >= 1 && /amigos/.test(r.notes[0]), 'nota de amigos');
})();

// ---------------------------------------------------------------- Fase 8a
(function () {
  // map_config consome os knobs novos
  var r = mapCfg.mapConfig({
    KiteMonsters: 1, ForceKite: 0, UseDanceAttack: 1, EleanorDoNotSwitchMode: 1,
    KiteBounds: 12, KiteStep: 3, DanceMinSP: 25,
  });
  eq(r.config.KiteMonsters, true, '8a: KiteMonsters → bool');
  eq(r.config.ForceKite, false, '8a: ForceKite=0 → false');
  eq(r.config.UseDanceAttack, true, '8a: UseDanceAttack → bool');
  eq(r.config.EleanorDoNotSwitchMode, true, '8a: EleanorDoNotSwitchMode → bool');
  eq(r.config.KiteBounds, 12, '8a: KiteBounds → número');
  eq(r.config.KiteStep, 3, '8a: KiteStep → número');
  eq(r.config.DanceMinSP, 25, '8a: DanceMinSP → número');
  ok(r.consumed.KiteMonsters && r.consumed.UseDanceAttack && r.consumed.KiteBounds, '8a: knobs marcados como consumidos');
})();

(function () {
  // map_tactics: UseAvoid=0 mantém BossGroup (detecção de chefe) mas tira o ramo de fuga
  var av1 = mapTac.mapTactics({}, { 1086: 1, 1087: 1 }, '', { useAvoid: true });
  ok(av1.bossGroupId > 0, '8a: useAvoid → BossGroup definido');
  ok(JSON.stringify(av1.tacticsBranch).indexOf('fugir do chefe') >= 0, '8a: useAvoid → ramo de fuga presente');
  var av0 = mapTac.mapTactics({}, { 1086: 1, 1087: 1 }, '', { useAvoid: false });
  ok(av0.bossGroupId > 0, '8a: UseAvoid=0 → BossGroup AINDA definido');
  ok(!av0.tacticsBranch || JSON.stringify(av0.tacticsBranch).indexOf('fugir do chefe') < 0, '8a: UseAvoid=0 → SEM ramo de fuga');
  ok(av0.groups.some(function (g) { return /Evitar/.test(g.name); }), '8a: UseAvoid=0 → grupo MVP ainda no catálogo');
})();

(function () {
  // migrate: injeta ramos gated + nível de invocação + relatório categorizado
  var files = { 'H_Config.lua': 'KiteMonsters = 1\nForceKite = 0\nUseDanceAttack = 1\nKiteBounds = 12\nDanceMinSP = 25\nEleanorDoNotSwitchMode = 1\nUseSeraCallLegion = 1\nSeraCallLegionLevel = 4\n' };
  var rm = migrate.migrate(files, {});
  var kite = [], dance = [];
  migrate._walk(rm.wrapper.spec, function (nn) {
    if (nn.name === 'Kite' && nn.label === 'kitar') kite.push(nn.params && nn.params.gate);
    if (nn.name === 'DanceAttack' && nn.label === 'dança') dance.push(nn.params && nn.params.gate);
  });
  eq(kite, ['KiteMonsters'], '8a: migrate injeta Kite gated por KiteMonsters');
  eq(dance, ['UseDanceAttack'], '8a: migrate injeta DanceAttack gated por UseDanceAttack');
  eq(rm.config.EleanorDoNotSwitchMode, true, '8a: migrate leva EleanorDoNotSwitchMode ao config');
  eq(rm.summonChoices.choices['50'].level, 4, '8a: nível de invocação Sera → summon_choice (tipo 50)');
  ok(typeof rm.report.counts.couldImplement === 'number' && typeof rm.report.counts.ignored === 'number', '8a: relatório separa could/ignored');
  // flags 0 → não injeta
  var rm0 = migrate.migrate({ 'H_Config.lua': 'KiteMonsters = 0\nUseDanceAttack = 0\n' }, {});
  var inj = 0; migrate._walk(rm0.wrapper.spec, function (nn) { if (nn.label === 'kitar' || nn.label === 'dança') inj++; });
  eq(inj, 0, '8a: flags 0 → não injeta Kite/Dance');
})();

// ---------------------------------------------------------------- Fase 8b
(function () {
  var r = mapCfg.mapConfig({ RescueOwnerLowHP: 50, UseSkillOnly: 1, OpportunisticTargeting: 1, DefensiveBuffOwnerMobbed: 0 });
  eq(r.config.RescueOwnerLowHP, 50, '8b: RescueOwnerLowHP → número');
  eq(r.config.UseSkillOnly, true, '8b: UseSkillOnly → bool');
  eq(r.config.OpportunisticTargeting, true, '8b: OpportunisticTargeting → bool');
  eq(r.config.DefensiveBuffOwnerMobbed, false, '8b: DefensiveBuffOwnerMobbed=0 → false');
  ok(r.consumed.RescueOwnerLowHP && r.consumed.UseSkillOnly && r.consumed.OpportunisticTargeting, '8b: knobs consumidos');
})();

(function () {
  var files = { 'H_Config.lua': 'RescueOwnerLowHP = 60\nDefensiveBuffOwnerMobbed = 1\nOpportunisticTargeting = 1\nUseSkillOnly = 1\n' };
  var rm = migrate.migrate(files, {});
  var rescue = 0, dbuff = 0, reacq = 0, reacqGate = null, atkTotal = 0, atkBlocked = 0;
  migrate._walk(rm.wrapper.spec, function (n) {
    if (n.name === 'RescueOwner') rescue++;
    if (n.type === 'check' && n.name === 'OwnerUnderAttack' && n.label === 'dono cercado') dbuff++;
    if (n.name === 'ReacquireIfBetter') { reacq++; reacqGate = n.params && n.params.gate; }
    if (n.name === 'AttackTarget') { atkTotal++; if (n.params && n.params.blockIf === 'UseSkillOnly') atkBlocked++; }
  });
  eq(rescue, 1, '8b: migrate injeta RescueOwner');
  eq(dbuff, 1, '8b: migrate injeta buff defensivo no dono cercado');
  eq(reacq, 1, '8b: migrate injeta ReacquireIfBetter');
  eq(reacqGate, 'OpportunisticTargeting', '8b: ReacquireIfBetter gated por OpportunisticTargeting');
  ok(atkTotal > 0 && atkBlocked === atkTotal, '8b: UseSkillOnly bloqueia TODOS os AttackTarget (' + atkBlocked + '/' + atkTotal + ')');
  var rm0 = migrate.migrate({ 'H_Config.lua': 'RescueOwnerLowHP = 0\nUseSkillOnly = 0\nOpportunisticTargeting = 0\nDefensiveBuffOwnerMobbed = 0\n' }, {});
  var inj = 0; migrate._walk(rm0.wrapper.spec, function (n) { if (n.name === 'RescueOwner' || n.name === 'ReacquireIfBetter' || n.label === 'dono cercado') inj++; if (n.name === 'AttackTarget' && n.params && n.params.blockIf) inj++; });
  eq(inj, 0, '8b: tudo OFF → não injeta nada');
})();

// ---------------------------------------------------------------- Fase 8c
(function () {
  var r = mapCfg.mapConfig({ UseIdleWalk: 1, IdleWalkSP: 25, IdleWalkDistance: 4, MoveSticky: 1, MoveStickyFight: 1, AutoMobMode: 0, AoEFixedLevel: 3, AoEMaximizeTargets: 1, UseHomunSSkillChase: 0, UseHomunSSkillAttack: 0 });
  eq(r.config.UseIdleWalk, true, '8c: UseIdleWalk → bool');
  eq(r.config.IdleWalkSP, 25, '8c: IdleWalkSP → número');
  eq(r.config.IdleWalkDistance, 4, '8c: IdleWalkDistance → número');
  eq(r.config.MoveSticky, true, '8c: MoveSticky → bool');
  eq(r.config.MoveStickyFight, true, '8c: MoveStickyFight → bool');
  eq(r.config.AutoMobMode, 0, '8c: AutoMobMode → número');
  eq(r.config.AoEFixedLevel, 3, '8c: AoEFixedLevel → número');
  eq(r.config.AoEMaximizeTargets, true, '8c: AoEMaximizeTargets → bool');
  eq(r.config.UseHomunSSkillChase, false, '8c: UseHomunSSkillChase=0 → false');
  eq(r.config.UseHomunSSkillAttack, false, '8c: UseHomunSSkillAttack=0 → false');
})();

(function () {
  var rm = migrate.migrate({ 'H_Config.lua': 'UseIdleWalk = 1\n' }, {});
  var iw = 0, oc = null;
  migrate._walk(rm.wrapper.spec, function (n) { if (n.label === 'ocioso') oc = n; if (n.name === 'IdleWalk') iw++; });
  eq(iw, 1, '8c: migrate injeta IdleWalk quando UseIdleWalk');
  var names = oc ? oc.children.map(function (c) { return c.name; }) : [];
  ok(names.indexOf('IdleWalk') >= 0 && names.indexOf('IdleWalk') < names.indexOf('Idle'), '8c: IdleWalk vem antes de Idle no ocioso');
  var rm0 = migrate.migrate({ 'H_Config.lua': 'UseIdleWalk = 0\n' }, {});
  var iw0 = 0; migrate._walk(rm0.wrapper.spec, function (n) { if (n.name === 'IdleWalk') iw0++; });
  eq(iw0, 0, '8c: UseIdleWalk=0 → não injeta IdleWalk');
})();

console.log('RESULTADO migration_map: ' + n + ' asserções OK');
