-- monsters_test.lua — monstros configuráveis no simulador.
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C = BRAI.json, BRAI.const
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function ent(snap, id) for _, e in ipairs(snap.entities) do if e.id == id then return e end end end
local function nMon(snap) local n=0 for _,e in ipairs(snap.entities) do if e.kind=="monster" then n=n+1 end end return n end

-- homun SuperPassive: não ataca, p/ isolar o comportamento do monstro
local scn = { grid={w=40,h=40}, dt=50, homunId=100, ownerId=1, config={ SuperPassive=true },
  entities={ {id=1,kind="owner",x=19,y=20,hp=1000,maxhp=1000},
    {id=100,kind="homun",x=20,y=20,hp=100,maxhp=100,sp=100,maxsp=100,homunType=C.VANILMIRTH} } }

print("== criar / configurar monstros ==")
local s = disp("load", scn)
check(nMon(s) == 0, "cenário inicia sem monstros")
disp("addMonster", { x=21, y=20, hp=200, atk=6, atkInterval=100000, aggressive=true })
s = disp("snapshot")
check(nMon(s) == 1, "addMonster cria um monstro")
local mid
for _,e in ipairs(s.entities) do if e.kind=="monster" then mid=e.id end end
local m = ent(s, mid)
check(m.aggressive == true and m.atkInterval == 100000 and m.atk == 6, "monstro traz atk/intervalo/agressivo no snapshot")

print("== intervalo de ataque (cadência) ==")
for i=1,10 do s = disp("step") end
check(ent(s,100).hp == 94, "com intervalo enorme, ataca só uma vez em 10 ticks (HP 94)")

print("== passivo não persegue/ataca ==")
s = disp("load", scn)
disp("addMonster", { x=21, y=20, hp=200, atk=6, aggressive=false })
local pid
for _,e in ipairs(disp("snapshot").entities) do if e.kind=="monster" then pid=e.id end end
for i=1,8 do s = disp("step") end
check(ent(s,100).hp == 100, "homún não toma dano de monstro passivo")
check(ent(s,pid).x == 21, "monstro passivo fica parado (não persegue)")
-- tornar agressivo via updateMonster faz ele agir
disp("updateMonster", { id=pid, aggressive=true })
for i=1,4 do s = disp("step") end
check(ent(s,100).hp < 100, "updateMonster aggressive=true faz ele atacar")

print("== mover e remover ==")
disp("moveEntity", { id=pid, x=5, y=5 })
s = disp("snapshot")
check(ent(s,pid).x == 5 and ent(s,pid).y == 5, "moveEntity reposiciona o monstro")
disp("removeMonster", { id=pid })
s = disp("snapshot")
check(ent(s,pid) == nil, "removeMonster remove o monstro")

print("== estado e alcance ==")
s = disp("load", scn)
disp("addMonster", { x=21, y=20, hp=200, atk=6, aggressive=false, aggro=8 })
local eid
for _,e in ipairs(disp("snapshot").entities) do if e.kind=="monster" then eid=e.id end end
check(ent(disp("snapshot"), eid).state == "passivo", "não-agressivo: estado 'passivo'")
check(ent(disp("snapshot"), eid).aggro == 8, "aggro exposto no snapshot")
disp("updateMonster", { id=eid, aggro=15 })
check(ent(disp("snapshot"), eid).aggro == 15, "updateMonster ajusta o alcance (aggro)")
disp("command", { cmd=C.ATTACK_OBJECT_CMD, a=eid })
for i=1,3 do s = disp("step") end
check(ent(s, eid).state == "provocado", "monstro passivo atacado fica 'provocado'")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
