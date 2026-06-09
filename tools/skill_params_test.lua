-- skill_params_test.lua — parâmetros das ações em DUAS camadas: global + override por homúnculo.
-- (1) setSkillParams/skillParamFor: round-trip + validação + override > global. (2) paramConfig (global).
-- (3) overrideConfig (globalValue/value/hasOverride). (4) precedência no MOTOR via loadDist:
--     nó > byHomun > global > config > default.
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, S = BRAI.json, BRAI.const, BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function roleOf(pc, role) for _, r in ipairs(pc) do if r.role == role then return r end end end
local function knobOf(r, key) for _, k in ipairs(r.knobs) do if k.key == key then return k end end end

-- ===== (1) setSkillParams / skillParamFor (global + override por homún) =====
print("== setSkillParams / skillParamFor ==")
BRAI.setSkillParams({
  params = { aoeAtk = { AutoMobCount = 2, AoEMaximizeTargets = true, BOGUS = 9 }, BOGUSROLE = { X = 1 } },
  overrides = { [tostring(C.DIETER)] = { aoeAtk = { AutoMobCount = 1 } }, ["nan"] = { aoeAtk = { AutoMobCount = 9 } } },
})
check(BRAI.skillParamFor(C.DIETER, "aoeAtk", "AutoMobCount") == 1, "override do Dieter vence (=1)")
check(BRAI.skillParamFor(C.BAYERI, "aoeAtk", "AutoMobCount") == 2, "Bayeri sem override usa o global (=2)")
check(BRAI.skillParamFor(0, "aoeAtk", "AutoMobCount") == 2, "sem homún (0) usa o global (=2)")
check(BRAI.skillParamFor(C.BAYERI, "aoeAtk", "AoEMaximizeTargets") == true, "boolean global lido")
check(BRAI.skillParamFor(C.DIETER, "aoeAtk", "BOGUS") == nil, "knob fora do contrato -> descartado")
check(BRAI.skillParamFor(C.BAYERI, "BOGUSROLE", "X") == nil, "papel fora do contrato -> descartado")
check(BRAI.skillParamFor(C.BAYERI, "offBuff", "UseOffensiveBuff") == nil, "papel/knob sem valor -> nil")
BRAI.setSkillParams({ params = { aoeAtk = { AutoMobCount = true } }, overrides = { [tostring(C.DIETER)] = { aoeAtk = { AutoMobCount = "x" } } } })
check(BRAI.skillParamFor(0, "aoeAtk", "AutoMobCount") == nil, "global number recebendo boolean -> descartado")
check(BRAI.skillParamFor(C.DIETER, "aoeAtk", "AutoMobCount") == nil, "override number inválido -> descartado")
BRAI.setSkillParams({})

-- ===== (2) paramConfig (GLOBAL, sem homún) =====
print("== paramConfig (global) ==")
local pc = BRAI.paramConfig()
check(#pc == 8, "8 papéis")
local aoe = roleOf(pc, "aoeAtk")
check(aoe and #aoe.knobs == 6, "aoeAtk: 6 knobs")
local amc = aoe and knobOf(aoe, "AutoMobCount")
check(amc and amc.type == "number" and amc.default == 2 and amc.value == nil, "AutoMobCount: number, default 2, value nil")
-- value reflete o GLOBAL; override por homún NÃO afeta paramConfig
BRAI.setSkillParams({ params = { aoeAtk = { AutoMobCount = 3 } }, overrides = { [tostring(C.DIETER)] = { aoeAtk = { AutoMobCount = 1 } } } })
check(knobOf(roleOf(BRAI.paramConfig(), "aoeAtk"), "AutoMobCount").value == 3, "paramConfig reflete só o global (=3), ignora override")
BRAI.setSkillParams({})

-- ===== (3) overrideConfig (modal de Skills) =====
print("== overrideConfig ==")
BRAI.setSkillParams({ params = { aoeAtk = { AutoMobCount = 3 } }, overrides = { [tostring(C.DIETER)] = { aoeAtk = { AutoMobCount = 1 } } } })
local oc = BRAI.overrideConfig(C.DIETER)
check(#oc == 8, "overrideConfig: 8 papéis")
local ocAoe = roleOf(oc, "aoeAtk")
check(ocAoe.hasOverride == true, "Dieter aoeAtk: hasOverride=true")
local ocAmc = knobOf(ocAoe, "AutoMobCount")
check(ocAmc.globalValue == 3 and ocAmc.value == 1, "knob: globalValue=3 (global), value=1 (override)")
check(roleOf(oc, "offBuff").hasOverride == false, "Dieter offBuff: hasOverride=false (sem override)")
-- globalValue cai no DEFAULT da config quando não há global p/ aquele knob
check(knobOf(roleOf(BRAI.overrideConfig(C.DIETER), "healSelf"), "HealSelfHP").globalValue == 40, "healSelf HealSelfHP globalValue = default 40")
-- homún sem nenhum override: tudo hasOverride=false, value=nil
local ocB = BRAI.overrideConfig(C.BAYERI)
check(roleOf(ocB, "aoeAtk").hasOverride == false and knobOf(roleOf(ocB, "aoeAtk"), "AutoMobCount").value == nil, "Bayeri: sem override (value nil), globalValue do global")
check(knobOf(roleOf(ocB, "aoeAtk"), "AutoMobCount").globalValue == 3, "Bayeri aoeAtk globalValue = global (3)")
BRAI.setSkillParams({})

-- ===== (4) precedência no motor (loadDist): nó > byHomun > global > config > default =====
print("== precedência no motor ==")
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

local spG1 = { params = { aoeAtk = { AutoMobCount = 1 } } }                                                  -- global=1
local spOv = { params = { aoeAtk = { AutoMobCount = 1 } }, overrides = { [tostring(C.BAYERI)] = { aoeAtk = { AutoMobCount = 5 } } } }  -- Bayeri override=5
check(run(C.BAYERI, "single", nil, spG1)[S.MH_HEILIGE_STANGE], "global AMC=1 -> Bayeri dispara em 1 alvo")
check(not run(C.BAYERI, "single", nil, spOv)[S.MH_HEILIGE_STANGE], "override do Bayeri AMC=5 vence o global=1 -> segura")
check(run(C.DIETER, "single", nil, spOv)[S.MH_LAVA_SLIDE], "override do Bayeri NÃO afeta Dieter (usa o global=1) -> dispara")
check(run(C.BAYERI, "single", { AutoMobCount = 1 }, spOv)[S.MH_HEILIGE_STANGE], "nó AMC=1 vence o override do Bayeri (5) -> dispara")
check(not any(run(C.DIETER, "cluster", nil, { overrides = { [tostring(C.DIETER)] = { aoeAtk = { UseAttackSkill = false } } } })),
  "override booleano Dieter UseAttackSkill=false -> não conjura nem no cluster")
check(run(C.DIETER, "single", nil, {})[S.MH_LAVA_SLIDE], "retrocompat: vazio == comportamento atual (Dieter dispara)")

-- heal: override de HealOwnerHP por homún
print("== heal override no motor ==")
do
  local function healScen(homun, ownerHp)
    return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
      { id = 1, kind = "owner", x = 20, y = 20, hp = ownerHp, maxhp = 100 },
      { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 1000, maxsp = 1000, homunType = homun } } }
  end
  local function healRun(homun, ownerHp, skillParams)
    disp("loadDist", { scenario = healScen(homun, ownerHp), spec = { type = "action", name = "UseHealOwner" }, skillParams = skillParams })
    for _ = 1, 4 do local s = disp("step"); if s.intent and s.intent.heal == "owner" then return true end end; return false
  end
  check(not healRun(C.LIF, 60, {}), "Lif healOwner: dono 60% >= default 50 -> NÃO cura")
  check(healRun(C.LIF, 60, { overrides = { [tostring(C.LIF)] = { healOwner = { HealOwnerHP = 70 } } } }),
    "override do Lif HealOwnerHP=70: dono 60% < 70 -> cura")
  check(not healRun(C.VANILMIRTH, 60, { overrides = { [tostring(C.LIF)] = { healOwner = { HealOwnerHP = 70 } } } }),
    "override do Lif NÃO afeta Vanilmirth (usa default 50) -> NÃO cura")
end

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
