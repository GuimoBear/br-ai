-- rescue8b_test.lua — Fase 8b: RescueOwner (HP do dono) + gates de mira (OpportunisticTargeting, UseSkillOnly).
-- Uso: texlua tools/rescue8b_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C = BRAI.json, BRAI.const

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function ent(s, id) for _, e in ipairs(s.entities) do if e.id == id then return e end end end
local function cheb(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

print("== RescueOwner: dono com HP baixo puxa o homún ==")
-- dono ferido (hp 10/100) longe do homún; sem monstros
local function rescScen(cfg, ownerHp)
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = ownerHp or 10, maxhp = 100 },
    { id = 100, kind = "homun", x = 28, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.VANILMIRTH },
  } }
end
local rescTree = { type = "action", name = "RescueOwner" }
disp("setTree", rescTree); disp("load", rescScen({ RescueOwnerLowHP = 50 }, 10))
local d0 = cheb(ent(disp("step"), 100), ent(disp("step"), 1)) -- pós 2 passos
local sR = disp("step"); local dN = cheb(ent(sR, 100), ent(sR, 1))
check(sR.intent and sR.intent.reason == "rescue", "intent de resgate (reason='rescue')")
check(dN < 8, "homún se aproxima do dono (dist " .. tostring(dN) .. " < 8 inicial)")

disp("setTree", rescTree); disp("load", rescScen({ RescueOwnerLowHP = 50 }, 100)) -- dono são (hp 100/100)
local sH = disp("step")
check(not (sH.intent and sH.intent.reason == "rescue"), "dono são (HP 100%): NÃO resgata")

disp("setTree", rescTree); disp("load", rescScen({ RescueOwnerLowHP = 0 }, 10)) -- desligado
local sOff = disp("step")
check(not (sOff.intent and sOff.intent.reason == "rescue"), "RescueOwnerLowHP=0 (padrão): NÃO resgata")

print("== OpportunisticTargeting: liga o ReacquireIfBetter ==")
-- m1 colado e cheio de HP (vira alvo por 'nearest'); m2 longe e com HP baixo (melhor por 'lowestHp')
local function tgtScen(cfg)
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.VANILMIRTH },
    { id = 200, kind = "monster", x = 21, y = 20, hp = 1000, maxhp = 1000, atkInterval = 100000, aggressive = false },
    { id = 201, kind = "monster", x = 24, y = 20, hp = 100,  maxhp = 1000, atkInterval = 100000, aggressive = false },
  } }
end
local tgtTree = { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },             -- 'nearest' → m1
  { type = "action", name = "ReacquireIfBetter", params = { by = "lowestHp", gate = "OpportunisticTargeting" } },
} }
disp("setTree", tgtTree); disp("load", tgtScen({ OpportunisticTargeting = false }))
local sOffT = disp("step")
check(sOffT.target == 200, "gate OFF: mantém o alvo 'nearest' (m1=" .. tostring(sOffT.target) .. ")")
disp("setTree", tgtTree); disp("load", tgtScen({ OpportunisticTargeting = true }))
local sOnT = disp("step")
check(sOnT.target == 201, "gate ON: troca p/ o de menor HP (m2=" .. tostring(sOnT.target) .. ")")

print("== UseSkillOnly: bloqueia o ataque normal (AttackTarget) ==")
local function atkScen(cfg)
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.VANILMIRTH },
    { id = 200, kind = "monster", x = 21, y = 20, hp = 100000, maxhp = 100000, atkInterval = 100000, aggressive = false },
  } }
end
local atkTree = { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
  { type = "action", name = "AttackTarget", params = { blockIf = "UseSkillOnly" } },
} }
local function attacked(steps)
  local saw = false; for i = 1, (steps or 4) do local s = disp("step"); if s.intent and s.intent.kind == "attack" then saw = true end end; return saw
end
disp("setTree", atkTree); disp("load", atkScen({ UseSkillOnly = false }))
check(attacked(4), "blockIf OFF: ataca normalmente")
disp("setTree", atkTree); disp("load", atkScen({ UseSkillOnly = true }))
check(not attacked(4), "UseSkillOnly=true: NÃO ataca (só skill)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
