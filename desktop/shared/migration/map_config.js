// map_config.js — H_Config (knobs) → bb.config do BR-AI + toggles de ramo (Use*=0 desativa nó).
// Retorna { config, branchToggles, rows, consumed, notes }. NÃO mexe em skills (map_skills cuida).
//   rows = linhas do relatório de→para: { from, to, status: 'mapped'|'adjusted'|'note', reason }
(function (root) {
  'use strict';

  // H_Config → config.<X> (cópia numérica direta)
  var DIRECT = {
    AggroHP: 'AggroHP', AggroSP: 'AggroSP', FleeHP: 'FleeHP',
    HealSelfHP: 'HealSelfHP', HealOwnerHP: 'HealOwnerHP',
    AutoMobCount: 'AutoMobCount', AttackSkillReserveSP: 'AttackSkillReserveSP',
    CastleDefendThreshold: 'CastleDefendThreshold', AutoComboSpheres: 'AutoComboSpheres',
    FollowStayBack: 'FollowStayBack', SphereTrackFactor: 'SphereTrackFactor',
    KiteBounds: 'KiteBounds', KiteStep: 'KiteStep', DanceMinSP: 'DanceMinSP',  // Fase 8a
    RescueOwnerLowHP: 'RescueOwnerLowHP',  // Fase 8b
    IdleWalkSP: 'IdleWalkSP', IdleWalkDistance: 'IdleWalkDistance', AutoMobMode: 'AutoMobMode', AoEFixedLevel: 'AoEFixedLevel',  // Fase 8c
  };
  // H_Config (0/1) → config.<X> (booleano)
  var BOOLS = {
    UseAttackSkill: 'UseAttackSkill', UseOffensiveBuff: 'UseOffensiveBuff',
    UseDefensiveBuff: 'UseDefensiveBuff', UseAutoHeal: 'UseAutoHeal', SuperPassive: 'SuperPassive',
    KiteMonsters: 'KiteMonsters', ForceKite: 'ForceKite', UseDanceAttack: 'UseDanceAttack', EleanorDoNotSwitchMode: 'EleanorDoNotSwitchMode',  // Fase 8a
    UseSkillOnly: 'UseSkillOnly', OpportunisticTargeting: 'OpportunisticTargeting', DefensiveBuffOwnerMobbed: 'DefensiveBuffOwnerMobbed',  // Fase 8b
    UseIdleWalk: 'UseIdleWalk', MoveSticky: 'MoveSticky', MoveStickyFight: 'MoveStickyFight', AoEMaximizeTargets: 'AoEMaximizeTargets', UseHomunSSkillChase: 'UseHomunSSkillChase', UseHomunSSkillAttack: 'UseHomunSSkillAttack',  // Fase 8c
  };
  // ramos da árvore ligados/desligados conforme um flag (por label ou nome de ação)
  // on:'nonzero' → habilitado quando ≠0 (0 desativa). on:'zero' → habilitado quando ==0 (ex.: DoNotChase=1 desativa)
  var BRANCHES = [
    { flag: 'UseAutoHeal', on: 'nonzero', target: { label: 'cura-urgente' }, desc: 'cura urgente' },
    { flag: 'UseCastleDefend', on: 'nonzero', target: { action: 'UseCastling' }, desc: 'Castling (Amistr)' },
    { flag: 'UseSeraPainkiller', on: 'nonzero', target: { action: 'UseOwnerBuff' }, desc: 'Painkiller no dono (Sera)' },
    { flag: 'UseSeraCallLegion', on: 'nonzero', target: { action: 'UseSummon' }, desc: 'Summon Legion (Sera)' },
    { flag: 'UseOffensiveBuff', on: 'nonzero', target: { action: 'UseOffensiveBuff' }, desc: 'buffs ofensivos' },
    { flag: 'UseDefensiveBuff', on: 'nonzero', target: { action: 'UseDefensiveBuff' }, desc: 'buffs defensivos' },
    { flag: 'UseAttackSkill', on: 'nonzero', target: { actions: ['UseAoESkill', 'UseMainSkill'] }, desc: 'skills de ataque' },
    { flag: 'DoNotChase', on: 'zero', target: { action: 'ChaseTarget' }, desc: 'perseguir alvo' },
  ];

  function has(o, k) { return o && Object.prototype.hasOwnProperty.call(o, k); }
  function num(v) { var n = Number(v); return isNaN(n) ? 0 : n; }
  function bool(v) { return num(v) !== 0; }

  function mapConfig(hconfig) {
    hconfig = hconfig || {};
    var config = {}, branchToggles = [], rows = [], notes = [], consumed = {};
    function mark(k) { consumed[k] = true; }

    // diretos
    for (var k in DIRECT) if (DIRECT.hasOwnProperty(k) && has(hconfig, k)) {
      var dst = DIRECT[k], val = num(hconfig[k]);
      config[dst] = val; mark(k);
      rows.push({ from: k + ' = ' + hconfig[k], to: 'config.' + dst + ' = ' + val, status: 'mapped' });
    }
    // booleanos 0/1
    for (var b in BOOLS) if (BOOLS.hasOwnProperty(b) && has(hconfig, b)) {
      var bd = BOOLS[b], bv = bool(hconfig[b]);
      config[bd] = bv; mark(b);
      rows.push({ from: b + ' = ' + hconfig[b], to: 'config.' + bd + ' = ' + bv, status: 'mapped' });
    }
    // OldHomunType → BaseHomunType
    if (has(hconfig, 'OldHomunType')) {
      config.BaseHomunType = num(hconfig.OldHomunType); mark('OldHomunType');
      rows.push({ from: 'OldHomunType = ' + hconfig.OldHomunType, to: 'config.BaseHomunType = ' + config.BaseHomunType, status: 'mapped' });
    }
    // Painkiller / Legion → flags de config (papel/ramo)
    if (has(hconfig, 'UseSeraPainkiller')) {
      config.UseOwnerBuff = bool(hconfig.UseSeraPainkiller); mark('UseSeraPainkiller');
      rows.push({ from: 'UseSeraPainkiller = ' + hconfig.UseSeraPainkiller, to: 'config.UseOwnerBuff = ' + config.UseOwnerBuff, status: 'mapped' });
    }
    if (has(hconfig, 'UseSeraCallLegion')) {
      config.UseSummon = bool(hconfig.UseSeraCallLegion); mark('UseSeraCallLegion');
      rows.push({ from: 'UseSeraCallLegion = ' + hconfig.UseSeraCallLegion, to: 'config.UseSummon = ' + config.UseSummon, status: 'mapped' });
    }
    // pares estacionário/móvel → um único knob (usa o MAIOR, com nota)
    reducePair('MoveBounds', 'StationaryMoveBounds', 'MobileMoveBounds');
    reducePair('AggroDist', 'StationaryAggroDist', 'MobileAggroDist');
    function reducePair(dst, a, c) {
      var hasA = has(hconfig, a), hasC = has(hconfig, c);
      if (!hasA && !hasC) return;
      var va = hasA ? num(hconfig[a]) : null, vc = hasC ? num(hconfig[c]) : null;
      var val = Math.max(va == null ? -Infinity : va, vc == null ? -Infinity : vc);
      config[dst] = val; if (hasA) mark(a); if (hasC) mark(c);
      var adjusted = (hasA && hasC && va !== vc);
      rows.push({
        from: [hasA ? a + ' = ' + hconfig[a] : null, hasC ? c + ' = ' + hconfig[c] : null].filter(Boolean).join(' · '),
        to: 'config.' + dst + ' = ' + val, status: adjusted ? 'adjusted' : 'mapped',
        reason: adjusted ? 'BR-AI usa um só valor; adotei o maior (estacionário/móvel)' : undefined,
      });
    }

    // toggles de ramo
    BRANCHES.forEach(function (br) {
      if (!has(hconfig, br.flag)) return;
      mark(br.flag);
      var v = num(hconfig[br.flag]);
      var enabled = (br.on === 'zero') ? (v === 0) : (v !== 0);
      branchToggles.push({ match: br.target, enabled: enabled, from: br.flag + ' = ' + hconfig[br.flag], desc: br.desc });
      rows.push({
        from: br.flag + ' = ' + hconfig[br.flag],
        to: (enabled ? 'mantém' : 'DESATIVA') + ' ramo «' + br.desc + '»',
        status: 'mapped',
      });
    });

    return { config: config, branchToggles: branchToggles, rows: rows, consumed: consumed, notes: notes };
  }

  var api = { mapConfig: mapConfig, DIRECT: DIRECT, BOOLS: BOOLS, BRANCHES: BRANCHES };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.BRAI_MIG_MAP_CONFIG = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
