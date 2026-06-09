-- summon_override_test.lua — F5: nível da invocação (Sera) — padrão (homun_summons.json) aplicado e
-- SOBREPOSTO pelo param do nó; nível inválido cai no conhecido (não desliga em silêncio).
-- Uso: texlua tools/summon_override_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

local function seraScen()
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = { UseSummon = true }, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.SERA },
    { id = 200, kind = "monster", x = 22, y = 20, hp = 100000, maxhp = 100000, atkInterval = 100000, aggressive = false },
  } }
end
local function withTarget(node) return { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, node } } end
local function summonLevelSeen(steps)
  for i = 1, (steps or 4) do local s = disp("step"); if s.intent and s.intent.skill == SID.MH_SUMMON_LEGION then return s.intent.level end end
  return nil
end

print("== padrão (homun_summons.json) aplicado ==")
disp("setSummonChoice", { choices = { ["50"] = { level = 3 } } })
disp("setTree", withTarget({ type = "action", name = "UseSeraLegion" }))
disp("load", seraScen())
check(summonLevelSeen(4) == 3, "summonChoice level=3 → invoca no nível 3")

print("== param do nó sobrepõe o padrão ==")
disp("setSummonChoice", { choices = { ["50"] = { level = 3 } } })
disp("setTree", withTarget({ type = "action", name = "UseSeraLegion", params = { level = 2 } }))
disp("load", seraScen())
check(summonLevelSeen(4) == 2, "param do nó level=2 sobrepõe o padrão (3)")

print("== nível inválido não desliga (cai no conhecido) ==")
disp("setSummonChoice", { choices = { ["50"] = { level = 3 } } })
disp("setTree", withTarget({ type = "action", name = "UseSeraLegion", params = { level = 99 } }))
disp("load", seraScen())
local lv = summonLevelSeen(4)
check(lv ~= nil, "nível 99 inválido NÃO desliga a invocação (ainda invoca)")
check(lv == 5, "cai no nível conhecido pela Sera (5), não no inválido (lv=" .. tostring(lv) .. ")")
disp("setSummonChoice", { choices = {} })

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
