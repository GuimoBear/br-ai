// symbols.js — tabela de símbolos da AzzyAI (constantes) p/ resolver os arquivos de config.
// Estratégia: começa com um FALLBACK embarcado (valores canônicos da 1.5x) e, se o zip trouxer
// Const_.lua / Const.lua / H_SkillList.lua, faz parse deles POR CIMA (o arquivo do usuário vence).
// Assim a decodificação de tuplas de tática e de IDs de skill é resiliente a faltar Const_.
(function (root) {
  'use strict';
  var luaParse = (typeof require !== 'undefined') ? require('./lua_parse.js')
    : (typeof window !== 'undefined' ? window.BRAI_LUA_PARSE : null);

  // --- tipos de homúnculo (V_HOMUNTYPE) ---
  var HOMUN_TYPES = {
    LIF: 1, AMISTR: 2, FILIR: 3, VANILMIRTH: 4,
    LIF2: 5, AMISTR2: 6, FILIR2: 7, VANILMIRTH2: 8,
    LIF_H: 9, AMISTR_H: 10, FILIR_H: 11, VANILMIRTH_H: 12,
    LIF_H2: 13, AMISTR_H2: 14, FILIR_H2: 15, VANILMIRTH_H2: 16,
    EIRA: 48, BAYERI: 49, BEYERI: 49, SERA: 50, DIETER: 51, ELEANOR: 52,
  };
  var HOMUN_NAMES = {
    1: 'Lif', 2: 'Amistr', 3: 'Filir', 4: 'Vanilmirth',
    5: 'Lif', 6: 'Amistr', 7: 'Filir', 8: 'Vanilmirth',
    9: 'Lif', 10: 'Amistr', 11: 'Filir', 12: 'Vanilmirth',
    13: 'Lif', 14: 'Amistr', 15: 'Filir', 16: 'Vanilmirth',
    48: 'Eira', 49: 'Bayeri', 50: 'Sera', 51: 'Dieter', 52: 'Eleanor',
  };

  // --- constantes de tática (valores que aparecem nas tuplas de MyTact) ---
  var TACTIC_CONSTS = {
    // campos (índices) — não usados como valor, mas definidos por completude
    TACT_BASIC: 1, TACT_SKILL: 2, TACT_KITE: 3, TACT_CAST: 4, TACT_PUSHBACK: 5,
    TACT_DEBUFF: 6, TACT_SIZE: 7, TACT_SKILLCLASS: 7, TACT_RESCUE: 8, TACT_SP: 9,
    TACT_SNIPE: 10, TACT_FFA: 11, TACT_KS: 11, TACT_WEIGHT: 12, TACT_CHASE: 13,
    // TACT_BASIC (campo 1) — resposta ao monstro
    TACT_TANKMOB: -2, TACT_TANK: -1, TACT_IGNORE: 0,
    TACT_ATTACK_L: 2, TACT_ATTACK_M: 3, TACT_ATTACK_H: 4,
    TACT_REACT_L: 5, TACT_REACT_M: 7, TACT_REACT_H: 8, TACT_REACT_SELF: 9,
    TACT_SNIPE_L: 10, TACT_SNIPE_M: 11, TACT_SNIPE_H: 12,
    TACT_ATK_L_REACT_M: 13, TACT_ATTACK_LAST: 14, TACT_ATTACK_TOP: 15,
    // uso de skill (campo 2)
    SKILL_NEVER: 0, SKILL_ALWAYS: 100,
    // kite (campo 3)
    KITE_ALWAYS: 2, KITE_REACT: 1, KITE_NEVER: 0,
    // cast react (campo 4)
    CAST_REACT: 1, CAST_PASSIVE: 0, CAST_REACT_ANY: 9,
    // pushback (campo 5)
    PUSH_FRIEND: 2, PUSH_SELF: 1, PUSH_NEVER: 0,
    // debuff (campo 6)
    DEBUFF_NEVER: 0, DEBUFF_ANY_C: -1, DEBUFF_ANY_A: 1, DEBUFF_ASH_A: 8043, DEBUFF_ASH_C: -8043,
    // skill class (campo 7)
    CLASS_BOTH: -1, CLASS_OLD: 0, CLASS_S: 1, CLASS_MOB: 2,
    CLASS_COMBO_1: 3, CLASS_COMBO_2: 4, CLASS_MINION: 5, CLASS_GRAPPLE: 6,
    // rescue (campo 8)
    RESCUE_NEVER: 0, RESCUE_FRIEND: 1, RESCUE_RETAINER: 2, RESCUE_SELF: 3, RESCUE_OWNER: 4, RESCUE_ALL: 5,
    // snipe (campo 10)
    SNIPE_OK: 1, SNIPE_DISABLE: 0,
    // KS (campo 11)
    KS_NEVER: 0, KS_ALWAYS: 1, KS_POLITE: -1,
    // chase (campo 13)
    CHASE_NORMAL: -1, CHASE_ALWAYS: 0, CHASE_NEVER: 1, CHASE_CLEVER: 2,
    // friend/pvp
    ALLY: 13, KOS: 12, ENEMY: 11, NEUTRAL: 10, RETAINER: 2, FRIEND: 1, PKFRIEND: 3,
  };

  // --- IDs de skill (name → id). Só p/ resolver SkillList/flags; metadados NÃO migram. ---
  var SKILL_IDS = {
    // mercenário (não-homún, ignorados na prática)
    MS_BASH: 8201, MS_MAGNUM: 8202, MS_BOWLINGBASH: 8203, MS_PARRYING: 8204, MS_REFLECTSHIELD: 8205,
    MS_BERSERK: 8206, MA_DOUBLE: 8207, MA_SHOWER: 8208, MA_SKIDTRAP: 8209, MA_LANDMINE: 8210,
    MA_SANDMAN: 8211, MA_FREEZINGTRAP: 8212, MA_REMOVETRAP: 8213, MA_CHARGEARROW: 8214, MA_SHARPSHOOTING: 8215,
    ML_PIERCE: 8216, ML_BRANDISH: 8217, ML_SPIRALPIERCE: 8218, ML_DEFENDER: 8219, ML_AUTOGUARD: 8220,
    ML_DEVOTION: 8221, MER_MAGNIFICAT: 8222, MER_QUICKEN: 8223, MER_SIGHT: 8224, MER_CRASH: 8225,
    MER_REGAIN: 8226, MER_TENDER: 8227, MER_BENEDICTION: 8228, MER_RECUPERATE: 8229, MER_MENTALCURE: 8230,
    MER_COMPRESS: 8231, MER_PROVOKE: 8232, MER_AUTOBERSERK: 8233, MER_DECAGI: 8234, MER_SCAPEGOAT: 8235,
    MER_LEXDIVINA: 8236, MER_ESTIMATION: 8237,
    // homún clássico
    HLIF_HEAL: 8001, HLIF_AVOID: 8002, HLIF_CHANGE: 8004, HAMI_CASTLE: 8005, HAMI_DEFENCE: 8006,
    HAMI_BLOODLUST: 8008, HFLI_MOON: 8009, HFLI_FLEET: 8010, HFLI_SPEED: 8011, HFLI_SBR44: 8012,
    HVAN_CAPRICE: 8013, HVAN_CHAOTIC: 8014, HVAN_SELFDESTRUCT: 8016,
    // homún S
    MUTATION_BASEJOB: 8017, MH_SUMMON_LEGION: 8018, MH_NEEDLE_OF_PARALYZE: 8019, MH_POISON_MIST: 8020,
    MH_PAIN_KILLER: 8021, MH_LIGHT_OF_REGENE: 8022, MH_OVERED_BOOST: 8023, MH_ERASER_CUTTER: 8024,
    MH_XENO_SLASHER: 8025, MH_SILENT_BREEZE: 8026, MH_STYLE_CHANGE: 8027, MH_SONIC_CRAW: 8028,
    MH_SONIC_CLAW: 8028, MH_SILVERVEIN_RUSH: 8029, MH_MIDNIGHT_FRENZY: 8030, MH_STAHL_HORN: 8031,
    MH_GOLDENE_FERSE: 8032, MH_STEINWAND: 8033, MH_HEILIGE_STANGE: 8034, MH_ANGRIFFS_MODUS: 8035,
    MH_TINDER_BREAKER: 8036, MH_CBC: 8037, MH_EQC: 8038, MH_MAGMA_FLOW: 8039, MH_GRANITIC_ARMOR: 8040,
    MH_LAVA_SLIDE: 8041, MH_PYROCLASTIC: 8042, MH_VOLCANIC_ASH: 8043, MH_BLAST_FORGE: 8044, MH_TEMPERING: 8045,
  };

  function buildFallback() {
    var env = {};
    var src = [HOMUN_TYPES, TACTIC_CONSTS, SKILL_IDS];
    for (var s = 0; s < src.length; s++) for (var k in src[s]) if (src[s].hasOwnProperty(k)) env[k] = src[s][k];
    return env;
  }

  // env de símbolos: FALLBACK + (Const_/Const/H_SkillList do zip, se houver). `files` = {name→texto}.
  function buildEnv(files, parseFn) {
    parseFn = parseFn || (luaParse && luaParse.parse);
    var env = buildFallback();
    var warnings = [];
    files = files || {};
    ['Const_.lua', 'Const.lua', 'H_SkillList.lua'].forEach(function (f) {
      var txt = pick(files, f);
      if (txt != null && parseFn) {
        try { var r = parseFn(txt, env); if (r && r.warnings) warnings = warnings.concat(r.warnings.map(function (w) { return f + ': ' + w; })); }
        catch (e) { warnings.push(f + ': falha ao parsear (' + e.message + ')'); }
      }
    });
    return { env: env, warnings: warnings };
  }

  // procura um arquivo no mapa ignorando caixa e caminho
  function pick(files, name) {
    if (files[name] != null) return files[name];
    var low = String(name).toLowerCase();
    for (var k in files) if (files.hasOwnProperty(k)) {
      var base = String(k).replace(/^.*[\\/]/, '').toLowerCase();
      if (base === low) return files[k];
    }
    return null;
  }

  // tipo de perfil/papel: evoluções (5..16) caem no clássico base (1..4); Homun S (48..52) = ele mesmo
  function baseProfileType(t) {
    t = Number(t) || 0;
    if (t >= 48) return t;
    if (t >= 1 && t <= 16) return ((t - 1) % 4) + 1;
    return t;
  }
  function isHomunS(t) { t = Number(t) || 0; return t >= 48 && t <= 52; }

  var api = {
    HOMUN_TYPES: HOMUN_TYPES, HOMUN_NAMES: HOMUN_NAMES,
    TACTIC_CONSTS: TACTIC_CONSTS, SKILL_IDS: SKILL_IDS,
    buildFallback: buildFallback, buildEnv: buildEnv, pick: pick,
    baseProfileType: baseProfileType, isHomunS: isHomunS,
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.BRAI_MIG_SYMBOLS = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
