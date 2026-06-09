// map_tactics.js — H_Tactics + H_Avoid → grupos por TUPLA IDÊNTICA + nós monsterCheck.
// Monstros com a MESMA tupla caem no MESMO "Grupo N". A tupla == Padrão (MyTact[0]) é pulada.
// Cada grupo vira monsterCheck(group=N) → filho (comportamento traduzido). H_Avoid → grupo
// "Evitar (MVP)" + config.BossGroup. Saída:
//   { monsters, groups, tacticsBranch, bossGroupId, rows, notes, consumed, tacticsRaw }
(function (root) {
  'use strict';
  var luaParse = (typeof require !== 'undefined') ? require('./lua_parse.js')
    : (typeof window !== 'undefined' ? window.BRAI_LUA_PARSE : null);
  var toArray = luaParse && luaParse.toArray;

  // índices (0-based) e constantes dos campos da tupla
  var F_BASIC = 0, F_KITE = 2, F_SNIPE = 9, F_CHASE = 12;
  var TACT_IGNORE = 0, KITE_ALWAYS = 2;
  function isSnipe(b) { return b >= 10 && b <= 12; }            // TACT_SNIPE_L/M/H
  function isReact(b) { return b === 5 || b === 7 || b === 8 || b === 9; } // TACT_REACT_*

  function behaviorFor(t) {
    var basic = t[F_BASIC], kite = t[F_KITE];
    if (basic === TACT_IGNORE) return 'ignore';
    if (kite === KITE_ALWAYS) return 'kite';
    if (isSnipe(basic)) return 'snipe';
    if (isReact(basic)) return 'react';
    return 'attack';
  }
  // filho do monsterCheck por comportamento. fid: 'green' (nó já existe) | 'yellow' (aproximado)
  function childFor(beh) {
    switch (beh) {
      case 'ignore': return { node: { type: 'action', name: 'Idle', label: 'ignorar' }, fid: 'yellow', hint: 'Ignorar' };
      case 'kite': return { node: { type: 'action', name: 'Kite', label: 'kite' }, fid: 'green', hint: 'Kite' };
      case 'snipe': return { node: { type: 'action', name: 'UseMainSkill', label: 'snipe (skill)' }, fid: 'yellow', hint: 'Snipe' };
      case 'react': return { node: { type: 'check', name: 'BeingAttacked', label: 'só se atacado', child: { type: 'action', name: 'AttackTarget' } }, fid: 'yellow', hint: 'Reagir' };
      default: return { node: { type: 'action', name: 'AttackTarget', label: 'atacar' }, fid: 'green', hint: 'Atacar' };
    }
  }

  // nomes dos monstros vêm dos comentários do H_Tactics (o parser os descarta)
  function parseNames(rawText) {
    var names = {};
    if (!rawText) return names;
    var re = /MyTact\[(\d+)\]\s*=\s*\{[^}]*\}\s*--\s*(.*)/g, m;
    while ((m = re.exec(rawText))) { names[Number(m[1])] = m[2].trim(); }
    return names;
  }

  function densify(t) { return toArray ? toArray(t) : t; }

  function mapTactics(myTact, avoid, rawTacticsText, opts) {
    var useAvoid = !(opts && opts.useAvoid === false);  // UseAvoid=0 na AzzyAI → sem grupo Evitar
    myTact = myTact || {};
    var names = parseNames(rawTacticsText);
    var rows = [], notes = [], consumed = {}, tacticsRaw = {};

    var defaultSig = myTact[0] ? JSON.stringify(densify(myTact[0])) : null;

    // agrupa ids (≠0, ≠avoid) por assinatura da tupla, pulando os iguais ao Padrão
    var avoidSet = {};
    if (avoid) for (var ak in avoid) if (avoid.hasOwnProperty(ak) && Number(avoid[ak]) !== 0) avoidSet[Number(ak)] = true;

    var bySig = {}, order = [];
    Object.keys(myTact).forEach(function (k) {
      var id = Number(k);
      if (id === 0 || avoidSet[id]) return;
      var tup = densify(myTact[k]);
      if (!tup || !tup.length) return;
      var sig = JSON.stringify(tup);
      tacticsRaw[id] = tup;
      if (sig === defaultSig) return;                 // já é o comportamento padrão da árvore
      if (!bySig[sig]) { bySig[sig] = { sig: sig, tuple: tup, members: [] }; order.push(sig); }
      bySig[sig].members.push(id);
    });

    var monsters = [], groups = [], singles = [], monsterChecks = [], gid = 0;
    function addMonster(id) { monsters.push({ id: id, desc: names[id] || ('Mob ' + id) }); }

    order.forEach(function (sig) {
      var g = bySig[sig];
      var beh = behaviorFor(g.tuple);
      var cf = childFor(beh);
      if (g.members.length === 1) {                       // 1 monstro => "tática por monstro" (monsterCheck por id)
        var id = g.members[0]; addMonster(id);
        var dsc = names[id] || ('Mob ' + id);
        singles.push({ id: id, desc: dsc, behavior: cf.hint, fid: cf.fid });
        monsterChecks.push({ type: 'monsterCheck', monster: id, label: dsc, child: cf.node });
        if (cf.fid === 'yellow') notes.push(dsc + ': comportamento «' + cf.hint + '» é encaixe aproximado — revise.');
        rows.push({ from: dsc, to: dsc + ' → ' + cf.hint + (cf.fid === 'yellow' ? ' 🟡' : ' 🟢'), status: cf.fid === 'yellow' ? 'adjusted' : 'mapped' });
      } else {                                            // 2+ monstros => grupo
        gid++;
        var name = 'Grupo ' + gid + ' · ' + cf.hint;
        g.members.forEach(addMonster);
        groups.push({ id: gid, name: name, members: g.members.slice(), behavior: cf.hint, fid: cf.fid });
        monsterChecks.push({ type: 'monsterCheck', group: gid, label: name, child: cf.node });
        if (cf.fid === 'yellow') notes.push(name + ': comportamento «' + cf.hint + '» é encaixe aproximado — revise o filho do monsterCheck.');
        rows.push({ from: g.members.map(function (mid) { return names[mid] || mid; }).join(', '), to: name + ' → ' + cf.hint + (cf.fid === 'yellow' ? ' 🟡' : ' 🟢'), status: cf.fid === 'yellow' ? 'adjusted' : 'mapped' });
      }
    });

    // H_Avoid → SEMPRE vira config.BossGroup (detecção de chefe: TargetIsBoss, poda do EQC).
    // O ramo de FUGA (monsterCheck→Flee) só é injetado quando UseAvoid≠0 (UseAvoid=0 = não foge, igual à AzzyAI).
    var bossGroupId = 0;
    var avoidIds = Object.keys(avoidSet).map(Number);
    if (avoidIds.length) {
      gid++; bossGroupId = gid;
      avoidIds.forEach(addMonster);
      groups.push({ id: gid, name: 'Grupo ' + gid + ' · Evitar (MVP)', members: avoidIds, behavior: 'Evitar (MVP)', fid: 'green' });
      consumed['MyAvoid'] = true;
      if (useAvoid) {
        monsterChecks.push({ type: 'monsterCheck', group: gid, label: 'Grupo ' + gid + ' · Evitar (MVP)', child: { type: 'action', name: 'Flee', label: 'fugir do chefe' } });
        rows.push({ from: avoidIds.length + ' MVP(s) de H_Avoid', to: 'Grupo ' + gid + ' → ramo de fuga + config.BossGroup', status: 'mapped' });
        notes.push('Evitar (MVP): ' + avoidIds.length + ' monstros do H_Avoid → grupo de fuga + config.BossGroup = ' + bossGroupId + '.');
      } else {
        rows.push({ from: avoidIds.length + ' MVP(s) de H_Avoid · UseAvoid=0', to: 'config.BossGroup = ' + bossGroupId + ' (detecção de chefe; SEM ramo de fuga)', status: 'mapped' });
        notes.push('UseAvoid=0: BossGroup definido p/ detecção de chefe, mas sem ramo de fuga (igual à AzzyAI).');
      }
    }

    var tacticsBranch = monsterChecks.length
      ? { type: 'selector', label: 'Táticas por monstro', children: monsterChecks }
      : null;

    return {
      monsters: monsters, groups: groups, singles: singles, tacticsBranch: tacticsBranch, bossGroupId: bossGroupId,
      rows: rows, notes: notes, consumed: consumed, tacticsRaw: tacticsRaw,
    };
  }

  var api = { mapTactics: mapTactics, behaviorFor: behaviorFor, childFor: childFor, parseNames: parseNames };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.BRAI_MIG_MAP_TACTICS = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
