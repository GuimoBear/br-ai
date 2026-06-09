-- node_config_test.lua — #4: override de config POR NÓ (param do nó > Config global > default).
-- Precedência testada nas 4 ações automáticas; booleano tri-estado (ausente herda); paridade
-- dist↔live. [PLANO-GERACAO-LUA G6]  Uso: texlua tools/node_config_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, S = BRAI.json, BRAI.const, BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

local function scen(homun, mobx)
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = homun },
    { id = 200, kind = "monster", x = mobx, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false } } }
end
local function aoeTree(params)  return { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, { type = "action", name = "UseAoESkill", params = params } } } end
local function mainTree(params) return { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, { type = "action", name = "UseMainSkill", params = params } } } end
local function buffTree(params) return { type = "action", name = "UseOffensiveBuff", params = params } end
local function collect()
  local seen = {}; for _ = 1, 16 do local s = disp("step"); if s.intent and s.intent.skill then seen[s.intent.skill] = true end end; return seen
end
local function castDist(homun, mobx, spec, config)
  disp("loadDist", { scenario = scen(homun, mobx), spec = spec, config = config }); return collect()
end
local function castLive(homun, mobx, spec, config)
  disp("setTree", spec); local sc = scen(homun, mobx); sc.config = config; disp("load", sc); return collect()
end
local function any(t) return next(t) ~= nil end
local function setStr(t) local o = {}; for k in pairs(t) do o[#o+1] = k end; table.sort(o); return table.concat(o, ",") end

print("== #4 override por nó (param do nó > Config global > default) ==")

-- 1) AutoMobCount por nó vence o global: Bayeri (com mainAtk) em 1 alvo
check(not castDist(C.BAYERI, 21, aoeTree(nil), {})[S.MH_HEILIGE_STANGE], "sem param: Bayeri AoE em 1 alvo NAO dispara (global AutoMobCount=2)")
check(castDist(C.BAYERI, 21, aoeTree({ AutoMobCount = 1 }), {})[S.MH_HEILIGE_STANGE], "nó AutoMobCount=1 vence global=2: AoE dispara em 1 alvo")

-- 2) UseHomunSSkillChase=false por nó: não conjura aproximando (alvo fora do AttackRange, em alcance da skill)
check(castDist(C.VANILMIRTH, 25, mainTree(nil), {})[S.HVAN_CAPRICE], "sem param: Caprice conjura aproximando (chase default=true)")
check(not castDist(C.VANILMIRTH, 25, mainTree({ UseHomunSSkillChase = false }), {})[S.HVAN_CAPRICE], "nó UseHomunSSkillChase=false: NAO conjura aproximando")

-- 3) UseAttackSkill=false por nó desliga SÓ aquele nó (global continua true)
check(castDist(C.VANILMIRTH, 21, mainTree(nil), {})[S.HVAN_CAPRICE], "sem param: Caprice conjura (1 alvo em alcance)")
check(not any(castDist(C.VANILMIRTH, 21, mainTree({ UseAttackSkill = false }), {})), "nó UseAttackSkill=false: desliga só este nó")

-- 4) booleano TRI-ESTADO: ausente HERDA o global; nó explícito VENCE o global
check(not any(castDist(C.VANILMIRTH, 21, mainTree(nil), { UseAttackSkill = false })), "tri-estado: ausente herda global=false -> NAO conjura")
check(castDist(C.VANILMIRTH, 21, mainTree({ UseAttackSkill = true }), { UseAttackSkill = false })[S.HVAN_CAPRICE], "tri-estado: nó=true vence global=false -> conjura")

-- 5) buffs: UseOffensiveBuff=false por nó desliga o buff só neste nó
check(any(castDist(C.BAYERI, 21, buffTree(nil), {})), "sem param: offBuff conjura")
check(not any(castDist(C.BAYERI, 21, buffTree({ UseOffensiveBuff = false }), {})), "nó UseOffensiveBuff=false: desliga o buff só neste nó")

-- 6) AoEFixedLevel por nó: fixa o nível só neste nó (Dieter em cluster)
do
  local cl = { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.DIETER },
    { id = 200, kind = "monster", x = 21, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false },
    { id = 201, kind = "monster", x = 21, y = 21, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false } } }
  disp("loadDist", { scenario = cl, spec = aoeTree({ AoEFixedLevel = 2 }) })
  local lvl
  for _ = 1, 16 do local s = disp("step"); if s.intent and s.intent.skill then lvl = s.intent.level; break end end
  check(lvl == 2, "nó AoEFixedLevel=2: conjura no nível 2 (lvl=" .. tostring(lvl) .. ")")
end

print("== paridade dist == live com overrides por nó ==")
check(setStr(castDist(C.BAYERI, 21, aoeTree({ AutoMobCount = 1 }), {})) == setStr(castLive(C.BAYERI, 21, aoeTree({ AutoMobCount = 1 }), {})), "paridade: nó AutoMobCount=1")
check(setStr(castDist(C.VANILMIRTH, 25, mainTree({ UseHomunSSkillChase = false }), {})) == setStr(castLive(C.VANILMIRTH, 25, mainTree({ UseHomunSSkillChase = false }), {})), "paridade: nó UseHomunSSkillChase=false")
check(setStr(castDist(C.VANILMIRTH, 21, mainTree({ UseAttackSkill = true }), { UseAttackSkill = false })) == setStr(castLive(C.VANILMIRTH, 21, mainTree({ UseAttackSkill = true }), { UseAttackSkill = false })), "paridade: tri-estado nó=true vs global=false")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
