-- dist_matrix_test.lua — MATRIZ §4: paridade sim<->dist p/ TODO cenario.
-- Para cada homun (9) x papel (com skill) x layout x config, exige que o intent do
-- PACOTE (loadDist) == intent do SIMULADOR ao vivo (load+setSkillChoice). Mais a
-- regressao do bug do Dieter e os comportamentos-chave em valor absoluto.
-- [PLANO-GERACAO-LUA G4]  Uso: texlua tools/dist_matrix_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, S = BRAI.json, BRAI.const, BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

local ACTION = { mainAtk = "UseMainSkill", aoeAtk = "UseAoESkill", offBuff = "UseOffensiveBuff", defBuff = "UseDefensiveBuff" }
local function treeFor(role)
  local act = { type = "action", name = ACTION[role] }
  if role == "mainAtk" or role == "aoeAtk" then
    return { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, act } }
  end
  return act
end
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
local function collect(steps)
  local seen = {}
  for _ = 1, (steps or 16) do local s = disp("step"); if s.intent and s.intent.skill then seen[s.intent.skill] = true end end
  return seen
end
local function distCast(homun, layout, role, cfg, choices, steps)
  disp("loadDist", { scenario = scen(homun, layout), config = cfg, choices = choices, spec = treeFor(role) })
  return collect(steps)
end
-- C1: variantes com skillParams GLOBAIS (por papel) + params de nó opcionais
local function treeForP(role, params)
  local act = { type = "action", name = ACTION[role], params = params }
  if role == "mainAtk" or role == "aoeAtk" then
    return { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, act } }
  end
  return act
end
local function distCastSP(homun, layout, role, sp, params)
  disp("loadDist", { scenario = scen(homun, layout), skillParams = sp, spec = treeForP(role, params) })
  return collect()
end
local function liveCastSP(homun, layout, role, sp, params)
  disp("setSkillParams", sp or {})
  disp("setTree", treeForP(role, params))
  disp("load", scen(homun, layout))
  local r = collect()
  disp("setSkillParams", {})
  return r
end
local function liveCast(homun, layout, role, cfg, choices, steps)
  disp("setSkillChoice", choices or {})
  disp("setTree", treeFor(role))
  local sc = scen(homun, layout); sc.config = cfg
  disp("load", sc)
  local r = collect(steps)
  disp("setSkillChoice", {})
  return r
end
local function castStr(set) local o = {}; for k in pairs(set) do o[#o+1] = k end; table.sort(o); return table.concat(o, ",") end
local function rolesWithSkills(homun)
  local rc, out = BRAI.roleConfig(homun), {}
  for _, r in ipairs(rc) do if r.effective and #r.effective > 0 then out[r.key] = true end end
  return out
end

local HN = { [C.LIF]="Lif",[C.AMISTR]="Amistr",[C.FILIR]="Filir",[C.VANILMIRTH]="Vanilmirth",[C.EIRA]="Eira",[C.BAYERI]="Bayeri",[C.SERA]="Sera",[C.DIETER]="Dieter",[C.ELEANOR]="Eleanor" }
local TYPES = { C.LIF,C.AMISTR,C.FILIR,C.VANILMIRTH,C.EIRA,C.BAYERI,C.SERA,C.DIETER,C.ELEANOR }
local LAYOUTS = { mainAtk={"single"}, aoeAtk={"single","cluster"}, offBuff={"none"}, defBuff={"none"} }

print("== Paridade dist<->live: 9 homuns x papeis x layouts (config padrao) ==")
for _, homun in ipairs(TYPES) do
  local roles = rolesWithSkills(homun)
  for _, key in ipairs({ "mainAtk","aoeAtk","offBuff","defBuff" }) do
    if roles[key] then
      for _, layout in ipairs(LAYOUTS[key]) do
        local d, l = distCast(homun, layout, key, {}, nil), liveCast(homun, layout, key, {}, nil)
        check(castStr(d) == castStr(l), HN[homun].."/"..key.."/"..layout..": dist==live {"..castStr(d).."}")
      end
    end
  end
end

print("== Paridade de CONFIG (dist==live) ==")
local CFG = {
  { "AutoMobCount=1", { AutoMobCount = 1 } },
  { "AutoMobMode=0", { AutoMobMode = 0 } },
  { "UseAttackSkill=false", { UseAttackSkill = false } },
  { "AoEFixedLevel=3", { AoEFixedLevel = 3 } },
  { "AttackRange=3", { AttackRange = 3 } },
  { "UseHomunSSkillChase=false", { UseHomunSSkillChase = false } },
}
local PROBES = {
  { C.DIETER, "aoeAtk", "single" }, { C.DIETER, "aoeAtk", "cluster" },
  { C.BAYERI, "mainAtk", "single" }, { C.BAYERI, "aoeAtk", "cluster" },
  { C.VANILMIRTH, "mainAtk", "single" }, { C.EIRA, "aoeAtk", "cluster" },
}
for _, cc in ipairs(CFG) do
  for _, pr in ipairs(PROBES) do
    local d, l = distCast(pr[1], pr[3], pr[2], cc[2], nil), liveCast(pr[1], pr[3], pr[2], cc[2], nil)
    check(castStr(d) == castStr(l), HN[pr[1]].."/"..pr[2].."/"..pr[3].." ["..cc[1].."]: dist==live {"..castStr(d).."}")
  end
end

print("== Paridade de NIVEL (AoEFixedLevel=3) ==")
local function firstLevelDist(homun, layout, role, cfg)
  disp("loadDist", { scenario = scen(homun, layout), config = cfg, spec = treeFor(role) })
  for _ = 1, 16 do local s = disp("step"); if s.intent and s.intent.skill then return s.intent.level end end; return nil
end
local function firstLevelLive(homun, layout, role, cfg)
  disp("setTree", treeFor(role)); local sc = scen(homun, layout); sc.config = cfg; disp("load", sc)
  for _ = 1, 16 do local s = disp("step"); if s.intent and s.intent.skill then return s.intent.level end end; return nil
end
do
  local ld = firstLevelDist(C.DIETER, "cluster", "aoeAtk", { AoEFixedLevel = 3 })
  local ll = firstLevelLive(C.DIETER, "cluster", "aoeAtk", { AoEFixedLevel = 3 })
  check(ld == ll and ld == 3, "Dieter aoe AoEFixedLevel=3: dist nivel == live nivel == 3 (ld="..tostring(ld)..")")
end

print("== Regressao do bug + comportamentos-chave (valor absoluto, dist) ==")
local function has(homun, layout, role, cfg, id) return distCast(homun, layout, role, cfg, nil)[id] == true end
check(has(C.DIETER, "single", "aoeAtk", { AutoMobCount = 2 }, S.MH_LAVA_SLIDE), "REGRESSAO: Dieter 1 mob (AutoMobCount=2) -> Lava Slide (antes: nada)")
check(not has(C.BAYERI, "single", "aoeAtk", { AutoMobCount = 2 }, S.MH_HEILIGE_STANGE), "GUARDA: Bayeri 1 mob (AutoMobCount=2) -> AoE NAO dispara (tem mainAtk)")
check(has(C.BAYERI, "cluster", "aoeAtk", { AutoMobCount = 2 }, S.MH_HEILIGE_STANGE), "Bayeri cluster (>=AutoMobCount) -> Heilige Stange")
check(not has(C.DIETER, "cluster", "aoeAtk", { AutoMobMode = 0 }, S.MH_LAVA_SLIDE), "AutoMobMode=0: Dieter cluster -> NAO dispara AoE")
check(not has(C.VANILMIRTH, "single", "mainAtk", { UseAttackSkill = false }, S.HVAN_CAPRICE), "UseAttackSkill=false: Vanilmirth -> NAO conjura mainAtk")
do
  local b = distCast(C.BAYERI, "none", "offBuff", {}, nil)
  check(b[S.MH_GOLDENE_FERSE] and b[S.MH_ANGRIFFS_MODUS], "offBuff: Bayeri mantem TODAS do perfil (Golden Ferse + Angriff Modus)")
end

print("== Paridade dist<->live com skillParams GLOBAIS (C1) ==")
do
  local spAMC = { params = { aoeAtk = { AutoMobCount = 1 } } }       -- GLOBAL: vale p/ todos
  local spOff = { params = { aoeAtk = { UseAttackSkill = false } } } -- GLOBAL
  local spVan = { params = { mainAtk = { AttackRange = 3 } } }       -- GLOBAL
  local PROBES = {
    { C.DIETER, "aoeAtk", "single", spAMC, nil },
    { C.BAYERI, "aoeAtk", "single", spAMC, nil },                  -- global afeta TODOS os homúns
    { C.BAYERI, "aoeAtk", "single", spAMC, { AutoMobCount = 5 } },  -- nó vence o global
    { C.DIETER, "aoeAtk", "cluster", spOff, nil },
    { C.BAYERI, "aoeAtk", "cluster", spAMC, nil },
    { C.VANILMIRTH, "mainAtk", "single", spVan, nil },
  }
  for _, pr in ipairs(PROBES) do
    local d = distCastSP(pr[1], pr[3], pr[2], pr[4], pr[5])
    local l = liveCastSP(pr[1], pr[3], pr[2], pr[4], pr[5])
    check(castStr(d) == castStr(l), HN[pr[1]] .. "/" .. pr[2] .. "/" .. pr[3] .. " [skillParams]: dist==live {" .. castStr(d) .. "}")
  end
  -- GLOBAL (absoluto, via dist): a MESMA config vale p/ TODOS os homúns
  check(distCastSP(C.BAYERI, "single", "aoeAtk", spAMC)[S.MH_HEILIGE_STANGE], "skillParams global AutoMobCount=1 -> Bayeri dispara em 1 alvo")
  check(not distCastSP(C.BAYERI, "single", "aoeAtk", {})[S.MH_HEILIGE_STANGE], "sem config (global=2) -> Bayeri segura em 1 alvo")
  check(not distCastSP(C.BAYERI, "single", "aoeAtk", spAMC, { AutoMobCount = 5 })[S.MH_HEILIGE_STANGE], "nó AutoMobCount=5 vence o global=1 -> segura")
  -- retrocompat: skillParams vazio == dist sem skillParams (matriz padrão)
  check(castStr(distCastSP(C.DIETER, "single", "aoeAtk", {})) == castStr(distCast(C.DIETER, "single", "aoeAtk", {}, nil)),
    "retrocompat: dist skillParams{} == dist sem skillParams")
end

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
