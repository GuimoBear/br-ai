// migrate.js — orquestra a migração AzzyAI → BR-AI. JS puro (Node + navegador).
//   migrate(files, opts) → MigrationResult {
//     wrapper:{name,homunType,baseType,spec}, config, monsters, skillChoices,
//     report:{ sections:[{title,rows}], counts }, notes, fromMigration:true }
//   files = { basename → texto }   opts = { defaultTree?, homunType?, name? }
(function (root) {
  'use strict';
  var req = (typeof require !== 'undefined') ? require : null;
  function dep(node, win) { return req ? req(node) : (typeof window !== 'undefined' ? window[win] : null); }
  var luaParse = dep('./lua_parse.js', 'BRAI_LUA_PARSE');
  var symbols = dep('./symbols.js', 'BRAI_MIG_SYMBOLS');
  var mapCfg = dep('./map_config.js', 'BRAI_MIG_MAP_CONFIG');
  var mapSkl = dep('./map_skills.js', 'BRAI_MIG_MAP_SKILLS');
  var mapTac = dep('./map_tactics.js', 'BRAI_MIG_MAP_TACTICS');
  var mapMsc = dep('./map_misc.js', 'BRAI_MIG_MAP_MISC');

  var pick = symbols.pick;
  function parse(txt, env) { return luaParse.parse(txt, env || {}); }

  // árvore padrão: no navegador a UI passa opts.defaultTree; no Node lemos o JSON compartilhado.
  function loadDefaultTree(opts) {
    if (opts && opts.defaultTree) return JSON.parse(JSON.stringify(opts.defaultTree));
    if (req) { var fs = req('fs'), path = req('path'); return JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'tree_homun.json'), 'utf8')); }
    throw new Error('árvore padrão não fornecida (opts.defaultTree)');
  }

  // ---- utilidades de árvore ----
  function walk(n, fn) {
    if (!n || typeof n !== 'object') return;
    fn(n);
    if (Array.isArray(n.children)) n.children.forEach(function (c) { walk(c, fn); });
    if (n.child) walk(n.child, fn);
  }
  function matchNode(n, m) {
    if (m.label) return n.label === m.label;
    if (m.action) return n.type === 'action' && n.name === m.action;
    if (m.actions) return n.type === 'action' && m.actions.indexOf(n.name) >= 0;
    return false;
  }
  function applyToggles(spec, toggles) {
    (toggles || []).forEach(function (t) {
      if (t.enabled !== false) return;          // só desativamos quando o flag pede
      walk(spec, function (n) { if (matchNode(n, t.match)) n.disabled = true; });
    });
  }
  function disableActions(spec, names) {
    walk(spec, function (n) { if (n.type === 'action' && names.indexOf(n.name) >= 0) n.disabled = true; });
  }
  function findByLabel(spec, label) {
    var found = null; walk(spec, function (n) { if (!found && n.label === label) found = n; }); return found;
  }
  // Âncoras por CONTEÚDO (robustas a rótulos): a árvore default é editável pelo usuário,
  // então localizamos os ramos pela estrutura, não por label fixo.
  function findSelectorWith(spec, pred) {
    var hit = null;
    walk(spec, function (n) {
      if (hit || n.type !== 'selector' || !Array.isArray(n.children)) return;
      if (n.children.some(pred)) hit = n;
    });
    return hit;
  }
  function findCombatAction(spec) {   // selector com UseMainSkill/UseAoESkill/ChaseTarget/InAttackRange
    return findSelectorWith(spec, function (c) {
      return (c.type === 'action' && (c.name === 'UseMainSkill' || c.name === 'UseAoESkill' || c.name === 'ChaseTarget'))
          || (c.type === 'check' && c.name === 'InAttackRange');
    });
  }
  function findIdleNode(spec) {        // selector que contém a folha Idle
    return findSelectorWith(spec, function (c) { return c.name === 'Idle'; });
  }
  function findEngageNode(spec) {      // selector de aquisição/engajamento de alvo
    return findSelectorWith(spec, function (c) {
      return (c.type === 'check' && (c.name === 'HasValidTarget' || c.name === 'CanEngage'))
          || (c.type === 'action' && c.name === 'AcquireTarget');
    });
  }

  // tipo de homún alvo: opção do usuário, senão o tipo com mais skills no SkillList, senão 4
  function pickType(opts, hconfig, skillList) {
    if (opts && opts.homunType) return Number(opts.homunType);
    var best = 0, bestN = -1;
    Object.keys(skillList || {}).forEach(function (k) {
      var t = Number(k); if (isNaN(t)) return;
      var n = Object.keys(skillList[k] || {}).length;
      var bonus = (t >= 48 && t <= 52) ? 0.5 : 0;   // desempate: prefere Homun S
      if (n + bonus > bestN) { bestN = n + bonus; best = t; }
    });
    if (best) return best;
    if (hconfig && hconfig.OldHomunType) return Number(hconfig.OldHomunType);
    return 4;
  }

  var SKIP_UNKNOWN = { LastSavedDate: 1, TactLastSavedDate: 1, ConfigPath: 1, AggressiveRelogPath: 1, AggressiveRelogTracking: 1, MagicNumber: 1, MagicNumber2: 1 };
  // knobs sem sentido no BR-AI (motor/timing/PVP) — "ignorados de propósito", não "requer atenção"
  var IGNORE_NOISE = {
    SpawnDelay: 1, AutoSkillDelay: 1, AutoSkillLimit: 1, AttackTimeLimit: 1, CastTimeRatio: 1,
    ChaseSPPause: 1, ChaseSPPauseSP: 1, ChaseSPPauseTime: 1, StienWandTelePause: 1, SteinWandTelePause: 1,
    LagReduction: 1, TankMonsterLimit: 1, AssumeHomun: 1, AttackLastFullSP: 1, LiveMobID: 1, AoEReserveSP: 1,
    PVPmode: 1, PVPMode: 1, PainkillerFriends: 1, PainkillerFriendsSave: 1, StandbyFriending: 1, MirAIFriending: 1,
    DefendStandby: 1, StickyStandby: 1, NewAutoFriend: 1, KSMercHomun: 1, RouteWalkCircle: 1,
  };

  function migrate(files, opts) {
    files = files || {}; opts = opts || {};
    var warnings = [];

    // 1) símbolos (FALLBACK + Const_/H_SkillList do zip)
    var built = symbols.buildEnv(files, luaParse.parse);
    var env = built.env; warnings = warnings.concat(built.warnings || []);

    // 2) parse dos arquivos de dados (no env de símbolos p/ resolver TACT_*, ELEANOR, etc.)
    var hconfig = {};
    var cfgTxt = pick(files, 'H_Config.lua'); if (cfgTxt != null) parse(cfgTxt, hconfig);
    var tacTxt = pick(files, 'H_Tactics.lua'); if (tacTxt != null) parse(tacTxt, env);
    var avoTxt = pick(files, 'H_Avoid.lua'); if (avoTxt != null) parse(avoTxt, env);
    var friTxt = pick(files, 'A_Friends.lua'); if (friTxt != null) parse(friTxt, env);
    var mobTxt = pick(files, 'Mob_ID.lua'); if (mobTxt != null) parse(mobTxt, env);

    // 3) mapeadores
    var rCfg = mapCfg.mapConfig(hconfig);
    var rSkl = mapSkl.mapSkills(env.SkillList || {}, hconfig);
    var useAvoid = !(hconfig.UseAvoid !== undefined && Number(hconfig.UseAvoid) === 0);  // UseAvoid=0 → sem grupo MVP
    var rTac = mapTac.mapTactics(env.MyTact || {}, env.MyAvoid || {}, tacTxt || '', { useAvoid: useAvoid });
    var rMsc = mapMsc.mapMisc(env.MyFriends || {}, env.MobID || {});

    // 4) tipo alvo + config final
    var homunType = pickType(opts, hconfig, env.SkillList || {});
    var baseType = symbols.isHomunS(homunType) ? (opts.baseType != null ? Number(opts.baseType) : Number(hconfig.OldHomunType || 0)) : 0;
    var config = {};
    for (var ck in rCfg.config) config[ck] = rCfg.config[ck];
    if (rTac.bossGroupId) config.BossGroup = rTac.bossGroupId;
    config.BaseHomunType = baseType;

    // Fase 8a: nível da invocação (Sera) → summon_choice (homun_summons.json)
    var summonChoices = { choices: {} };
    var summonLvl = Number(hconfig.SeraCallLegionLevel || 0);
    var summonOn = hconfig.UseSeraCallLegion === undefined || Number(hconfig.UseSeraCallLegion) !== 0;
    if (summonOn && summonLvl > 0) summonChoices.choices['50'] = { level: summonLvl };

    // 5) árvore: padrão → toggles → papéis desativados (do tipo) → injeta táticas
    var spec = loadDefaultTree(opts);
    applyToggles(spec, rCfg.branchToggles);
    var dr = rSkl.disabledRoles[homunType] || {};
    if (dr.aoeAtk) disableActions(spec, ['UseAoESkill']);
    if (dr.mainAtk) disableActions(spec, ['UseMainSkill']);
    if (rTac.tacticsBranch) {
      var combat = findByLabel(spec, 'combate-acao') || findCombatAction(spec) || findByLabel(spec, 'Engajar');
      if (combat && Array.isArray(combat.children)) combat.children.unshift(rTac.tacticsBranch);
      else if (Array.isArray(spec.children)) spec.children.push(rTac.tacticsBranch);
    }
    // Fase 8a: ramos opcionais (nós já existentes), ligados pelo flag de config
    var combat8a = findByLabel(spec, 'combate-acao') || findCombatAction(spec);
    if (combat8a && Array.isArray(combat8a.children)) {
      if (config.KiteMonsters || config.ForceKite) {
        var ti = -1; for (var ki = 0; ki < combat8a.children.length; ki++) { if (combat8a.children[ki].label === 'Táticas por monstro') { ti = ki; break; } }
        combat8a.children.splice(ti + 1, 0, { type: 'action', name: 'Kite', params: { gate: 'KiteMonsters' }, label: 'kitar' });
      }
      if (config.UseDanceAttack) {
        var ai = -1; for (var di = 0; di < combat8a.children.length; di++) { var cd = combat8a.children[di]; if (cd.type === 'check' && cd.name === 'InAttackRange') { ai = di; break; } }
        var dance = { type: 'action', name: 'DanceAttack', params: { gate: 'UseDanceAttack' }, label: 'dança' };
        if (ai >= 0) combat8a.children.splice(ai, 0, dance); else combat8a.children.push(dance);
      }
    }
    // Fase 8b: proteção do dono + estratégia de mira (nós já existentes, ligados por config)
    if (Array.isArray(spec.children)) {
      var engIdx = -1; for (var bi = 0; bi < spec.children.length; bi++) { if (spec.children[bi].label === 'Engajar') { engIdx = bi; break; } }
      if (engIdx < 0) engIdx = spec.children.length;
      if (config.DefensiveBuffOwnerMobbed) {                                  // buff no dono quando cercado (OwnerUnderAttack + UseOwnerBuff)
        spec.children.splice(engIdx, 0, { type: 'check', name: 'OwnerUnderAttack', params: { count: 2 }, label: 'dono cercado', child: { type: 'action', name: 'UseOwnerBuff', label: 'buff defensivo no dono' } });
        engIdx++;
      }
      if ((config.RescueOwnerLowHP || 0) > 0) {                               // resgate posicional quando o dono está com HP baixo
        spec.children.splice(engIdx, 0, { type: 'action', name: 'RescueOwner', label: 'resgatar dono' });
        engIdx++;
      }
    }
    if (config.OpportunisticTargeting) {                                      // troca p/ um alvo melhor (liga o ReacquireIfBetter)
      var reacq = { type: 'action', name: 'ReacquireIfBetter', params: { gate: 'OpportunisticTargeting' }, label: 'mira oportunista' };
      var setAlvo = findByLabel(spec, 'Definir alvo');
      if (setAlvo && Array.isArray(setAlvo.children)) {
        var temIdx = -1; for (var ci2 = 0; ci2 < setAlvo.children.length; ci2++) { if (setAlvo.children[ci2].label === 'Tem alvo') { temIdx = ci2; break; } }
        if (temIdx >= 0) setAlvo.children.splice(temIdx, 0, reacq); else setAlvo.children.unshift(reacq);
      } else {
        var eng = findEngageNode(spec);                                       // fallback por conteúdo (sem label 'Definir alvo')
        if (eng && Array.isArray(eng.children)) eng.children.unshift(reacq);
        else if (Array.isArray(spec.children)) spec.children.unshift(reacq);
      }
    }
    if (config.UseSkillOnly) {                                                // só skill: bloqueia TODO ataque normal
      walk(spec, function (nn) { if (nn && nn.type === 'action' && nn.name === 'AttackTarget') { nn.params = nn.params || {}; nn.params.blockIf = 'UseSkillOnly'; } });
    }
    // Fase 8c: IdleWalk no ramo «ocioso» (os demais knobs — sticky, AoE, skill-S — são só config lida por nós já existentes)
    if (config.UseIdleWalk) {
      var ocioso = findByLabel(spec, 'ocioso') || findIdleNode(spec);
      if (ocioso && Array.isArray(ocioso.children)) {
        var idi = -1; for (var oi = 0; oi < ocioso.children.length; oi++) { if (ocioso.children[oi].name === 'Idle') { idi = oi; break; } }
        var iw = { type: 'action', name: 'IdleWalk', label: 'perambular' };
        if (idi >= 0) ocioso.children.splice(idi, 0, iw); else ocioso.children.push(iw);
      }
    }

    // 6) catálogo de monstros (grupos das táticas)
    var monsters = { monsters: rTac.monsters, groups: rTac.groups };

    // 7) knobs não migrados (transparência)
    var consumed = {};
    [rCfg.consumed, rSkl.consumed, rTac.consumed].forEach(function (c) { for (var k in c) consumed[k] = true; });
    if (hconfig.UseAvoid !== undefined) consumed.UseAvoid = true;            // tratado via useAvoid (map_tactics)
    if (summonOn && summonLvl > 0) consumed.SeraCallLegionLevel = true;       // foi p/ summon_choice
    var ignored = [], couldImplement = [];
    Object.keys(hconfig).forEach(function (k) {
      if (consumed[k] || SKIP_UNKNOWN[k]) return;
      if (IGNORE_NOISE[k] || /Level$/.test(k)) ignored.push(k);              // interno/PVP/timing ou nível órfão (skill off/não-escolhida)
      else couldImplement.push(k);
    });

    // 8) relatório
    var attention = [];
    rSkl.notes.concat(rTac.notes, rMsc.notes).forEach(function (msg) { attention.push({ from: '⚠️', to: msg, status: 'note' }); });
    if (couldImplement.length) attention.push({ from: couldImplement.length + ' knobs poderiam ser implementados', to: couldImplement.slice(0, 24).join(', ') + (couldImplement.length > 24 ? '…' : ''), status: 'note' });
    if (ignored.length) attention.push({ from: ignored.length + ' ignorados de propósito (internos/PVP/níveis órfãos)', to: ignored.slice(0, 12).join(', ') + (ignored.length > 12 ? '…' : ''), status: 'note' });

    var sections = [
      { title: 'Configuração e ramos', rows: rCfg.rows },
      { title: 'Skills (4 papéis + nível)', rows: rSkl.rows },
      { title: 'Táticas por monstro', rows: rTac.rows },
      { title: 'Listas (amigos/avoid)', rows: rMsc.rows },
      { title: 'Não migrado / requer atenção', rows: attention },
    ];
    var counts = { mapped: 0, adjusted: 0, note: 0 };
    sections.forEach(function (s) { s.rows.forEach(function (r) { if (counts[r.status] != null) counts[r.status]++; }); });
    counts.groups = rTac.groups.length;
    counts.singles = (rTac.singles || []).length;
    counts.monsters = rTac.monsters.length;
    counts.skillTypes = Object.keys(rSkl.skillChoices.choices).length;
    counts.couldImplement = couldImplement.length;
    counts.ignored = ignored.length;

    var name = (opts.name || 'azzyai-migrada');
    return {
      wrapper: { name: name, homunType: homunType, baseType: baseType, spec: spec },
      config: config,
      monsters: monsters,
      singles: rTac.singles,
      skillChoices: rSkl.skillChoices,
      summonChoices: summonChoices,
      report: { sections: sections, counts: counts },
      tacticsRaw: rTac.tacticsRaw,
      warnings: warnings,
      fromMigration: true,
    };
  }

  // applyGroupNames — renomeia grupos (de->para) e os labels dos nos monsterCheck. Puro; usado pela UI.
  function applyGroupNames(result, overrides) {
    if (!result || !overrides) return result;
    var groups = (result.monsters && result.monsters.groups) || [];
    groups.forEach(function (g) {
      var nm = overrides[g.id];
      if (nm != null && String(nm).trim() !== '') g.name = String(nm);
    });
    if (result.wrapper && result.wrapper.spec) {
      walk(result.wrapper.spec, function (n) {
        if (n.type === 'monsterCheck' && n.group != null) {
          var nm = overrides[n.group];
          if (nm != null && String(nm).trim() !== '') n.label = String(nm);
        }
      });
    }
    return result;
  }

// applyMonsterNames — renomeia monstros (singles) e o label dos monsterCheck(monster=id). Puro.
  function applyMonsterNames(result, overrides) {
    if (!result || !overrides) return result;
    var mons = (result.monsters && result.monsters.monsters) || [];
    mons.forEach(function (m) { var nm = overrides[m.id]; if (nm != null && String(nm).trim() !== '') m.desc = String(nm); });
    (result.singles || []).forEach(function (sg) { var nm = overrides[sg.id]; if (nm != null && String(nm).trim() !== '') sg.desc = String(nm); });
    if (result.wrapper && result.wrapper.spec) {
      walk(result.wrapper.spec, function (n) {
        if (n.type === 'monsterCheck' && n.monster != null) {
          var nm = overrides[n.monster]; if (nm != null && String(nm).trim() !== '') n.label = String(nm);
        }
      });
    }
    return result;
  }

  var api = { migrate: migrate, applyGroupNames: applyGroupNames, applyMonsterNames: applyMonsterNames, _walk: walk, _applyToggles: applyToggles };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.BRAI_MIGRATE = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
