// map_skills.js — extrai SÓ as 4 skills padrão por papel + nível, por tipo de homún.
// NÃO importa a lista de skills nem metadados (SkillInfo) — a base do BR-AI é mais atual.
// Entrada: skillList (env.SkillList = {tipo:{id:nível}}) e hconfig (H_Config). Saída:
//   { skillChoices:{choices:{tipo:{mainAtk?,aoeAtk?,offBuff?,defBuff?, *Level?}}}, rows, consumed, notes, disabledRoles }
// Override de papel é gravado SÓ quando difere do padrão do BR-AI; nível sempre que houver.
(function (root) {
  'use strict';

  // IDs (canônicos) — só p/ legibilidade
  var ID = {
    HLIF_AVOID: 8002, HLIF_CHANGE: 8004, HAMI_DEFENCE: 8006, HAMI_BLOODLUST: 8008,
    HFLI_MOON: 8009, HFLI_FLEET: 8010, HFLI_SPEED: 8011, HVAN_CAPRICE: 8013,
    MH_NEEDLE: 8019, MH_POISON_MIST: 8020, MH_OVERED_BOOST: 8023, MH_ERASER_CUTTER: 8024,
    MH_XENO_SLASHER: 8025, MH_SONIC_CLAW: 8028, MH_STAHL_HORN: 8031, MH_GOLDENE_FERSE: 8032,
    MH_STEINWAND: 8033, MH_HEILIGE_STANGE: 8034, MH_ANGRIFFS_MODUS: 8035, MH_MAGMA_FLOW: 8039,
    MH_GRANITIC_ARMOR: 8040, MH_LAVA_SLIDE: 8041, MH_PYROCLASTIC: 8042, MH_BLAST_FORGE: 8044, MH_TEMPERING: 8045,
  };

  // padrões do BR-AI (espelham lua/src/data/profiles.lua) — p/ saber quando GRAVAR override
  var DEFAULTS = {
    1: { offBuff: ID.HLIF_CHANGE, defBuff: ID.HLIF_AVOID },
    2: { offBuff: ID.HAMI_BLOODLUST, defBuff: ID.HAMI_DEFENCE },
    3: { mainAtk: ID.HFLI_MOON, offBuff: ID.HFLI_FLEET, defBuff: ID.HFLI_SPEED },
    4: { mainAtk: ID.HVAN_CAPRICE },
    48: { mainAtk: ID.MH_ERASER_CUTTER, aoeAtk: ID.MH_XENO_SLASHER, offBuff: ID.MH_OVERED_BOOST },
    49: { mainAtk: ID.MH_STAHL_HORN, aoeAtk: ID.MH_HEILIGE_STANGE, offBuff: ID.MH_GOLDENE_FERSE, defBuff: ID.MH_STEINWAND },
    50: { mainAtk: ID.MH_NEEDLE, aoeAtk: ID.MH_POISON_MIST },
    51: { aoeAtk: ID.MH_LAVA_SLIDE, offBuff: ID.MH_PYROCLASTIC, defBuff: ID.MH_GRANITIC_ARMOR },
    52: { mainAtk: ID.MH_SONIC_CLAW },
  };

  // specs por tipo: como resolver a skill de cada papel a partir do H_Config.
  //   single  → { role, id, enableKey?, levelKey? }   (enableKey ausente = sempre ligado)
  //   alts    → { role, alts:[{id, enableKey, levelKey?}] }  (escolhe o 1º habilitado)
  var SPECS = {
    1: [{ role: 'offBuff', id: ID.HLIF_CHANGE }, { role: 'defBuff', id: ID.HLIF_AVOID, levelKey: 'LifEscapeLevel' }],
    2: [{ role: 'offBuff', id: ID.HAMI_BLOODLUST }, { role: 'defBuff', id: ID.HAMI_DEFENCE, levelKey: 'AmiBulwarkLevel' }],
    3: [{ role: 'mainAtk', id: ID.HFLI_MOON }, { role: 'offBuff', id: ID.HFLI_FLEET, levelKey: 'FilirFlitLevel' }, { role: 'defBuff', id: ID.HFLI_SPEED, levelKey: 'FilirAccelLevel' }],
    4: [{ role: 'mainAtk', id: ID.HVAN_CAPRICE }],
    48: [
      { role: 'mainAtk', id: ID.MH_ERASER_CUTTER, enableKey: 'UseEiraEraseCutter', levelKey: 'EiraEraseCutterLevel' },
      { role: 'aoeAtk', id: ID.MH_XENO_SLASHER, enableKey: 'UseEiraXenoSlasher', levelKey: 'EiraXenoSlasherLevel' },
      { role: 'offBuff', id: ID.MH_OVERED_BOOST, enableKey: 'UseEiraOveredBoost' },
    ],
    49: [
      { role: 'mainAtk', id: ID.MH_STAHL_HORN, enableKey: 'UseBayeriStahlHorn', levelKey: 'BayeriStahlHornLevel' },
      { role: 'aoeAtk', id: ID.MH_HEILIGE_STANGE, enableKey: 'UseBayeriHailegeStar', levelKey: 'BayeriHailegeStarLevel' },
      { role: 'offBuff', alts: [{ id: ID.MH_GOLDENE_FERSE, enableKey: 'UseBayeriGoldenPherze' }, { id: ID.MH_ANGRIFFS_MODUS, enableKey: 'UseBayeriAngriffModus' }] },
      { role: 'defBuff', id: ID.MH_STEINWAND, enableKey: 'UseBayeriSteinWand', levelKey: 'BayeriSteinWandLevel' },
    ],
    50: [
      { role: 'mainAtk', id: ID.MH_NEEDLE, enableKey: 'UseSeraParalyze', levelKey: 'SeraParalyzeLevel' },
      { role: 'aoeAtk', id: ID.MH_POISON_MIST, enableKey: 'UseSeraPoisonMist', levelKey: 'SeraPoisonMistLevel' },
    ],
    51: [
      { role: 'aoeAtk', alts: [{ id: ID.MH_LAVA_SLIDE, enableKey: 'UseDieterLavaSlide', levelKey: 'DieterLavaSlideLevel' }, { id: ID.MH_BLAST_FORGE, enableKey: 'UseDieterBlastForge' }] },
      { role: 'offBuff', alts: [{ id: ID.MH_PYROCLASTIC, enableKey: 'UseDieterPyroclastic', levelKey: 'DieterPyroclasticLevel' }, { id: ID.MH_TEMPERING, enableKey: 'UseDieterTempering', levelKey: 'UseDieterTemperingLevel' }] },
      { role: 'defBuff', alts: [{ id: ID.MH_GRANITIC_ARMOR, enableKey: 'UseDieterGraniticArmor' }, { id: ID.MH_MAGMA_FLOW, enableKey: 'UseDieterMagmaFlow' }] },
    ],
    52: [{ role: 'mainAtk', id: ID.MH_SONIC_CLAW, enableKey: 'UseEleanorSonicClaw', levelKey: 'EleanorSonicClawLevel' }],
  };

  function has(o, k) { return o && Object.prototype.hasOwnProperty.call(o, k); }
  function num(v) { var n = Number(v); return isNaN(n) ? 0 : n; }
  function enabled(hconfig, key) { return !key || (has(hconfig, key) ? num(hconfig[key]) !== 0 : true); }

  function mapSkills(skillList, hconfig) {
    skillList = skillList || {}; hconfig = hconfig || {};
    var choices = {}, rows = [], notes = [], consumed = {}, disabledRoles = {};
    function mark(k) { if (k) consumed[k] = true; }
    function slLevel(type, id) { var t = skillList[type] || skillList[String(type)]; return t ? (t[id] || t[String(id)]) : null; }
    function lvlKey(key) { if (key && has(hconfig, key)) { mark(key); var n = num(hconfig[key]); return n > 0 ? n : null; } return null; }

    Object.keys(SPECS).forEach(function (typeKey) {
      var type = Number(typeKey);
      var specs = SPECS[type], roles = {}, def = DEFAULTS[type] || {};
      specs.forEach(function (sp) {
        var id = null, levelKey = sp.levelKey;
        if (sp.alts) {
          for (var a = 0; a < sp.alts.length; a++) { mark(sp.alts[a].enableKey); }
          for (var b = 0; b < sp.alts.length; b++) {
            if (enabled(hconfig, sp.alts[b].enableKey)) { id = sp.alts[b].id; levelKey = sp.alts[b].levelKey; break; }
          }
          if (id == null) { notes.push(skillNote(type, sp.role, 'nenhuma skill habilitada p/ o papel — mantém padrão do BR-AI')); return; }
        } else {
          mark(sp.enableKey);
          if (!enabled(hconfig, sp.enableKey)) {
            disabledRoles[type] = disabledRoles[type] || {}; disabledRoles[type][sp.role] = true;
            notes.push(skillNote(type, sp.role, 'desabilitada na AzzyAI (' + sp.enableKey + '=0)'));
            rows.push({ from: sp.enableKey + ' = 0', to: tname(type) + ': papel ' + sp.role + ' DESATIVADO', status: 'note' });
            return;
          }
          id = sp.id;
        }
        var level = lvlKey(levelKey) || slLevel(type, id) || null;
        var differs = def[sp.role] != null && id !== def[sp.role];
        if (differs) roles[sp.role] = id;
        if (level != null) roles[sp.role + 'Level'] = level;
        rows.push({
          from: tname(type) + ' · ' + sp.role + (levelKey ? ' (' + levelKey + ')' : ''),
          to: 'skill #' + id + (differs ? ' (override do padrão)' : ' (padrão)') + (level != null ? ' · nível ' + level : ''),
          status: differs ? 'adjusted' : 'mapped',
        });
      });
      if (Object.keys(roles).length) choices[String(type)] = roles;
    });

    return { skillChoices: { choices: choices }, rows: rows, consumed: consumed, notes: notes, disabledRoles: disabledRoles };
  }

  var TN = { 1: 'Lif', 2: 'Amistr', 3: 'Filir', 4: 'Vanilmirth', 48: 'Eira', 49: 'Bayeri', 50: 'Sera', 51: 'Dieter', 52: 'Eleanor' };
  function tname(t) { return TN[t] || ('tipo ' + t); }
  function skillNote(type, role, msg) { return tname(type) + ' · ' + role + ': ' + msg; }

  var api = { mapSkills: mapSkills, DEFAULTS: DEFAULTS, SPECS: SPECS, ID: ID };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.BRAI_MIG_MAP_SKILLS = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
