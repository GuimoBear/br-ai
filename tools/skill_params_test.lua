-- skill_params_test.lua — parâmetros de skill por homúnculo/papel (PLANO-CONFIG-SKILLS C0).
-- (1) setSkillParams/skillParamFor: round-trip + validação (papel/knob/tipo). (2) paramConfig:
-- 8 papéis, knobs com default global + valor, skill efetiva. (3) precedência no MOTOR via loadDist:
-- nó > skillParams(homún/papel) > config global > default; MESMA árvore muda por homún.
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

-- ===== (1) setSkillParams / skillParamFor / validação =====
print("== setSkillParams / skillParamFor ==")
BRAI.setSkillParams({ params = {
  [tostring(C.DIETER)] = { aoeAtk = { AutoMobCount = 1, AoEMaximizeTargets = true, BOGUS = 9 }, BOGUSROLE = { X = 1 } },
} })
check(BRAI.skillParamFor(C.DIETER, "aoeAtk", "AutoMobCount") == 1, "número armazenado (AutoMobCount=1)")
check(BRAI.skillParamFor(C.DIETER, "aoeAtk", "AoEMaximizeTargets") == true, "booleano armazenado (true)")
check(BRAI.skillParamFor(C.DIETER, "aoeAtk", "BOGUS") == nil, "knob fora do contrato -> descartado")
check(BRAI.skillParamFor(C.DIETER, "BOGUSROLE", "X") == nil, "papel fora do contrato -> descartado")
check(BRAI.skillParamFor(C.BAYERI, "aoeAtk", "AutoMobCount") == nil, "homún sem config -> nil")
BRAI.setSkillParams({ params = { [tostring(C.DIETER)] = { aoeAtk = { AutoMobCount = true, AoEMaximizeTargets = 3 } } } })
check(BRAI.skillParamFor(C.DIETER, "aoeAtk", "AutoMobCount") == nil, "number recebendo boolean -> descartado")
check(BRAI.skillParamFor(C.DIETER, "aoeAtk", "AoEMaximizeTargets") == nil, "boolean recebendo number -> descartado")
BRAI.setSkillParams({})

-- ===== (2) paramConfig =====
print("== paramConfig ==")
local pc = BRAI.paramConfig(C.DIETER)
check(#pc == 8, "8 papéis (4 + healSelf/healOwner/ownerBuff/castling)")
local aoe = roleOf(pc, "aoeAtk")
check(aoe and #aoe.knobs == 6, "aoeAtk: 6 knobs")
local amc = aoe and knobOf(aoe, "AutoMobCount")
check(amc and amc.type == "number" and amc.default == 2 and amc.value == nil, "AutoMobCount: tipo number, default global 2, value nil (herda)")
check(aoe.hasSkill and aoe.skills[1].name == "Lava Slide", "aoeAtk: skill efetiva em destaque (Lava Slide)")
check(roleOf(pc, "mainAtk") and not roleOf(pc, "mainAtk").hasSkill, "Dieter mainAtk: sem skill (papel vazio)")
-- valor configurado reflete
BRAI.setSkillParams({ params = { [tostring(C.DIETER)] = { aoeAtk = { AutoMobCount = 1 } } } })
amc = knobOf(roleOf(BRAI.paramConfig(C.DIETER), "aoeAtk"), "AutoMobCount")
check(amc.value == 1, "paramConfig reflete o valor configurado (AutoMobCount=1)")
BRAI.setSkillParams({})
-- heal/castling (perfil próprio)
check(roleOf(BRAI.paramConfig(C.LIF), "healOwner").hasSkill, "Lif healOwner: tem skill (Healing Hands)")
check(roleOf(BRAI.paramConfig(C.AMISTR), "castling").hasSkill, "Amistr castling: tem skill")
check(knobOf(roleOf(BRAI.paramConfig(C.LIF), "healSelf"), "HealSelfHP").default == 40, "healSelf HealSelfHP default global 40")

-- ===== (3) precedência no motor (via loadDist) =====
print("== precedência no motor (loadDist) ==")
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

-- MESMA árvore: Dieter aoeAtk AutoMobCount=1 (homún) dispara em 1 alvo; Bayeri (global=2) segura
local spD = { params = { [tostring(C.DIETER)] = { aoeAtk = { AutoMobCount = 1 } } } }
check(run(C.DIETER, "single", nil, spD)[S.MH_LAVA_SLIDE], "Dieter aoeAtk AutoMobCount=1 (homún) -> dispara em 1 alvo")
check(not run(C.BAYERI, "single", nil, spD)[S.MH_HEILIGE_STANGE], "MESMA árvore: Bayeri (sem config, global=2) -> segura em 1 alvo")
-- Bayeri com config=1 dispara
local spB = { params = { [tostring(C.BAYERI)] = { aoeAtk = { AutoMobCount = 1 } } } }
check(run(C.BAYERI, "single", nil, spB)[S.MH_HEILIGE_STANGE], "Bayeri aoeAtk AutoMobCount=1 (homún) -> dispara em 1 alvo")
-- precedência NÓ > homún: nó AutoMobCount=5 vence homún=1 -> segura
check(not run(C.BAYERI, "single", { AutoMobCount = 5 }, spB)[S.MH_HEILIGE_STANGE], "nó AutoMobCount=5 vence homún=1 -> segura em 1 alvo")
-- booleano por homún: Dieter aoeAtk UseAttackSkill=false -> não conjura nem no cluster
check(not any(run(C.DIETER, "cluster", nil, { params = { [tostring(C.DIETER)] = { aoeAtk = { UseAttackSkill = false } } } })),
  "Dieter aoeAtk UseAttackSkill=false (homún) -> não conjura")
-- retrocompat: skillParams vazio == comportamento atual (#1: Dieter dispara em 1 alvo)
check(run(C.DIETER, "single", nil, {})[S.MH_LAVA_SLIDE], "vazio: comportamento idêntico ao atual (retrocompat)")

-- heal (papel extra) no MOTOR: HealOwnerHP por homún muda quando cura
do
  local function healScen(ownerHpPct)
    return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
      { id = 1, kind = "owner", x = 20, y = 20, hp = ownerHpPct * 10, maxhp = 1000 },
      { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.LIF } } }
  end
  local function healRun(ownerHpPct, skillParams)
    disp("loadDist", { scenario = healScen(ownerHpPct), spec = { type = "action", name = "UseHealOwner" }, skillParams = skillParams })
    for _ = 1, 4 do local s = disp("step"); if s.intent and s.intent.heal == "owner" then return true end end; return false
  end
  check(not healRun(60, {}), "Lif healOwner: dono 60% >= default 50 -> NÃO cura")
  check(healRun(60, { params = { [tostring(C.LIF)] = { healOwner = { HealOwnerHP = 70 } } } }),
    "Lif healOwner HealOwnerHP=70 (homún): dono 60% < 70 -> cura (effRole no papel heal)")
end

-- ===== C7: edge-cases (base-aware + healSelf/healOwner independentes) =====
print("== C7: paramConfig ciente da forma base ==")
check(roleOf(BRAI.paramConfig(C.SERA, C.VANILMIRTH), "healOwner").hasSkill, "Sera + base Vanilmirth: healOwner herda a cura (Chaotic)")
check(not roleOf(BRAI.paramConfig(C.SERA), "healOwner").hasSkill, "Sera sem base: healOwner sem skill (perfil próprio)")
check(roleOf(BRAI.paramConfig(C.DIETER, C.AMISTR), "castling").hasSkill, "Dieter + base Amistr: castling herdado")
check(not roleOf(BRAI.paramConfig(C.DIETER), "castling").hasSkill, "Dieter sem base: castling sem skill")

print("== C7: healSelf vs healOwner independentes (UseAutoHeal por papel) ==")
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
  local offSelf = { params = { [tostring(C.VANILMIRTH)] = { healSelf = { UseAutoHeal = false } } } }
  check(healRun(C.VANILMIRTH, 30, 100, selfTree, {})["self"], "Vanilmirth UseHealSelf: cura a si (30% < 40)")
  check(not healRun(C.VANILMIRTH, 30, 100, selfTree, offSelf)["self"], "healSelf.UseAutoHeal=false (homún): NÃO cura a si")
  check(healRun(C.VANILMIRTH, 100, 40, ownerTree, offSelf)["owner"], "healSelf.UseAutoHeal=false NÃO afeta UseHealOwner (papéis independentes)")
end

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
