-- skill_params_test.lua — parâmetros GLOBAIS das ações de skill (rework global).
-- (1) setSkillParams/skillParamFor(role,key): round-trip + validação (papel/knob/tipo) + descarte
--     do formato antigo por-homúnculo. (2) paramConfig(): 8 papéis, knobs com default global + valor,
--     rótulo+descrição (sem skill por homún). (3) precedência no MOTOR via loadDist:
--     nó > skillParams GLOBAL (este modal) > config global > default; a MESMA config vale p/ TODOS.
-- Uso: texlua tools/skill_params_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, S = BRAI.json, BRAI.const, BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function roleOf(pc, role) for _, r in ipairs(pc) do if r.role == role then return r end end end
local function knobOf(r, key) for _, k in ipairs(r.knobs) do if k.key == key then return k end end end

-- ===== (1) setSkillParams / skillParamFor / validação (GLOBAL: chave = papel) =====
print("== setSkillParams / skillParamFor (global) ==")
BRAI.setSkillParams({ params = {
  aoeAtk = { AutoMobCount = 1, AoEMaximizeTargets = true, BOGUS = 9 },
  BOGUSROLE = { X = 1 },
} })
check(BRAI.skillParamFor("aoeAtk", "AutoMobCount") == 1, "número armazenado (AutoMobCount=1)")
check(BRAI.skillParamFor("aoeAtk", "AoEMaximizeTargets") == true, "booleano armazenado (true)")
check(BRAI.skillParamFor("aoeAtk", "BOGUS") == nil, "knob fora do contrato -> descartado")
check(BRAI.skillParamFor("BOGUSROLE", "X") == nil, "papel fora do contrato -> descartado")
check(BRAI.skillParamFor("offBuff", "UseOffensiveBuff") == nil, "papel sem config -> nil")
BRAI.setSkillParams({ params = { aoeAtk = { AutoMobCount = true, AoEMaximizeTargets = 3 } } })
check(BRAI.skillParamFor("aoeAtk", "AutoMobCount") == nil, "number recebendo boolean -> descartado")
check(BRAI.skillParamFor("aoeAtk", "AoEMaximizeTargets") == nil, "boolean recebendo number -> descartado")
-- retrocompat: o formato ANTIGO por-homúnculo (chave numérica) não é mais aceito (vira vazio)
BRAI.setSkillParams({ params = { [tostring(C.DIETER)] = { aoeAtk = { AutoMobCount = 1 } } } })
check(BRAI.skillParamFor("aoeAtk", "AutoMobCount") == nil, "formato antigo por-homúnculo -> descartado (global agora)")
BRAI.setSkillParams({})

-- ===== (2) paramConfig (global, sem homúnculo, sem skills) =====
print("== paramConfig (global) ==")
local pc = BRAI.paramConfig()
check(#pc == 8, "8 papéis (4 + healSelf/healOwner/ownerBuff/castling)")
local aoe = roleOf(pc, "aoeAtk")
check(aoe and #aoe.knobs == 6, "aoeAtk: 6 knobs")
local amc = aoe and knobOf(aoe, "AutoMobCount")
check(amc and amc.type == "number" and amc.default == 2 and amc.value == nil, "AutoMobCount: number, default global 2, value nil")
check(aoe.label == "Skill em área (AoE)" and type(aoe.desc) == "string" and #aoe.desc > 0, "aoeAtk: rótulo + descrição da ação")
check(aoe.skills == nil and aoe.hasSkill == nil, "paramConfig NÃO traz skill por homúnculo (é global por ação)")
check(roleOf(pc, "castling") ~= nil and roleOf(pc, "healSelf") ~= nil, "inclui os papéis castling/healSelf")
-- valor configurado reflete (global)
BRAI.setSkillParams({ params = { aoeAtk = { AutoMobCount = 1 } } })
amc = knobOf(roleOf(BRAI.paramConfig(), "aoeAtk"), "AutoMobCount")
check(amc.value == 1, "paramConfig reflete o valor configurado (AutoMobCount=1)")
check(knobOf(roleOf(BRAI.paramConfig(), "healSelf"), "HealSelfHP").default == 40, "healSelf HealSelfHP default global 40")
BRAI.setSkillParams({})

-- ===== (3) precedência no motor (via loadDist) — config GLOBAL p/ todos =====
print("== precedência no motor (loadDist, global) ==")
local function scen(homun, layout)
  local ents = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = homun },
  }
  if layout == "single" then
    ents[#ents+1] = { id = 200, kind = "monster", x = 21, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
  elseif layout == "cluster" then
    ents[#ents+1] = { id = 200, kind = "monster", x = 21, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
    ents[#ents+1] = { id = 201, kind = "monster", x = 21, y = 21, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
    ents[#ents+1] = { id = 202, kind = "monster", x = 20, y = 21, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
  end
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = ents }
end
local function aoeTree(params)
  return { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
    { type = "action", name = "UseAoESkill", params = params } } }
end
local function run(homun, layout, params, skillParams)
  disp("loadDist", { scenario = scen(homun, layout), spec = aoeTree(params), skillParams = skillParams })
  local seen = {}; for _ = 1, 16 do local s = disp("step"); if s.intent and s.intent.skill then seen[s.intent.skill] = true end end; return seen
end
local function any(t) return next(t) ~= nil end

-- sem config: global=2 -> Bayeri segura em 1 alvo
check(not run(C.BAYERI, "single", nil, {})[S.MH_HEILIGE_STANGE], "vazio: Bayeri (global=2) segura em 1 alvo")
-- GLOBAL AutoMobCount=1 vale p/ TODOS: Bayeri passa a disparar em 1 alvo
local sp1 = { params = { aoeAtk = { AutoMobCount = 1 } } }
check(run(C.BAYERI, "single", nil, sp1)[S.MH_HEILIGE_STANGE], "global AutoMobCount=1 -> Bayeri dispara em 1 alvo")
check(run(C.DIETER, "single", nil, sp1)[S.MH_LAVA_SLIDE], "MESMA config global vale p/ Dieter também (dispara em 1 alvo)")
-- precedência NÓ > global: nó AutoMobCount=5 vence o global=1 -> segura
check(not run(C.BAYERI, "single", { AutoMobCount = 5 }, sp1)[S.MH_HEILIGE_STANGE], "nó AutoMobCount=5 vence o global=1 -> segura")
-- booleano global: UseAttackSkill=false -> ninguém conjura (nem no cluster)
check(not any(run(C.DIETER, "cluster", nil, { params = { aoeAtk = { UseAttackSkill = false } } })),
  "global aoeAtk UseAttackSkill=false -> Dieter não conjura nem no cluster")
-- retrocompat: formato antigo por-homún é IGNORADO no motor (Bayeri usa o default global=2)
check(not run(C.BAYERI, "single", nil, { params = { [tostring(C.BAYERI)] = { aoeAtk = { AutoMobCount = 1 } } } })[S.MH_HEILIGE_STANGE],
  "formato antigo por-homún -> ignorado (Bayeri segura, usa default global)")
-- retrocompat: vazio == comportamento atual (Dieter dispara em 1 alvo)
check(run(C.DIETER, "single", nil, {})[S.MH_LAVA_SLIDE], "vazio: comportamento idêntico ao atual (Dieter dispara)")

-- ===== (4) heal/castling no motor (papéis extras) + independência healSelf/healOwner =====
print("== heal global no motor + independência ==")
do
  local function healScen(homun, selfHp, ownerHp)
    return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
      { id = 1, kind = "owner", x = 20, y = 20, hp = ownerHp, maxhp = 100 },
      { id = 100, kind = "homun", x = 20, y = 20, hp = selfHp, maxhp = 100, sp = 1000, maxsp = 1000, homunType = homun } } }
  end
  local function healRun(homun, selfHp, ownerHp, spec, skillParams)
    disp("loadDist", { scenario = healScen(homun, selfHp, ownerHp), spec = spec, skillParams = skillParams })
    local seen = {}
    for _ = 1, 4 do local s = disp("step"); if s.intent and s.intent.heal then seen[s.intent.heal] = true end end
    return seen
  end
  local selfTree = { type = "action", name = "UseHealSelf" }
  local ownerTree = { type = "action", name = "UseHealOwner" }
  -- HealOwnerHP global: Lif dono 60% NÃO cura (default 50); com 70 global -> cura
  check(not healRun(C.LIF, 100, 60, ownerTree, {})["owner"], "Lif healOwner: dono 60% >= default 50 -> NÃO cura")
  check(healRun(C.LIF, 100, 60, ownerTree, { params = { healOwner = { HealOwnerHP = 70 } } })["owner"],
    "global healOwner HealOwnerHP=70: dono 60% < 70 -> cura (effRole no papel heal)")
  -- healSelf vs healOwner independentes (UseAutoHeal por papel)
  local offSelf = { params = { healSelf = { UseAutoHeal = false } } }
  check(healRun(C.VANILMIRTH, 30, 100, selfTree, {})["self"], "Vanilmirth UseHealSelf: cura a si (30% < 40)")
  check(not healRun(C.VANILMIRTH, 30, 100, selfTree, offSelf)["self"], "global healSelf.UseAutoHeal=false: NÃO cura a si")
  check(healRun(C.VANILMIRTH, 100, 40, ownerTree, offSelf)["owner"], "healSelf.UseAutoHeal=false NÃO afeta UseHealOwner (papéis independentes)")
end

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
