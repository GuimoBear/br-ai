-- check_test.lua — nó condicional 'check' (condição com 1 filho).
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local C, S, bt, json = BRAI.const, BRAI.status, BRAI.bt, BRAI.json

local pass, fail = 0, 0
local function eq(a, b, n) if a == b then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n .. " (esperado " .. tostring(b) .. ", obtido " .. tostring(a) .. ")") end end

-- backend mínimo p/ bb:now()
BRAI.ro.bind({ GetTick = function() return 0 end, TraceAI = function() end })

print("== unitário: check ==")
local function leaf(st) return bt.node("leaf", "leaf", function() return st end) end
local bb = BRAI.Blackboard.new()
bb.self.hpPct = 30
eq(bt.check("HpBelow", { pct = 50 }, leaf(S.SUCCESS)):tick(bb), S.SUCCESS, "cond verdadeira -> executa filho (SUCCESS)")
eq(bt.check("HpBelow", { pct = 50 }, leaf(S.RUNNING)):tick(bb), S.RUNNING, "cond verdadeira -> propaga RUNNING do filho")
bb.self.hpPct = 80
eq(bt.check("HpBelow", { pct = 50 }, leaf(S.SUCCESS)):tick(bb), S.FAILURE, "cond falsa -> FAILURE (não executa filho)")
bb.self.hpPct = 30
eq(bt.check("HpBelow", { pct = 50 }, nil):tick(bb), S.SUCCESS, "sem filho + cond verdadeira -> SUCCESS (age como condição)")

print("== integração: check na árvore via sim ==")
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local scn = { grid = {w=40,h=40}, dt=50, homunId=100, ownerId=1,
  entities = {
    {id=1,kind="owner",x=10,y=10,hp=1000,maxhp=1000},
    {id=100,kind="homun",x=20,y=20,hp=100,maxhp=100,sp=100,maxsp=100,homunType=C.LIF},
    {id=200,kind="monster",x=21,y=20,hp=300,maxhp=300,atk=3,aggro=12,etype=1042} } }
-- check{HasValidTarget -> AttackTarget} equivale a sequence[HasValidTarget, AttackTarget]
local tree = { type = "selector", children = {
  { type = "check", name = "HasValidTarget", child = { type = "action", name = "AttackTarget" } },
  { type = "sequence", children = { {type="condition",name="CanEngage"}, {type="action",name="AcquireTarget"} } },
} }
disp("load", scn); disp("setTree", tree)
local snap
for i = 1, 4 do snap = disp("step"); if snap.intent and snap.intent.kind == "attack" then break end end
eq(snap.intent and snap.intent.kind, "attack", "check{HasValidTarget->AttackTarget} ataca após adquirir alvo")
disp("clearTree")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
