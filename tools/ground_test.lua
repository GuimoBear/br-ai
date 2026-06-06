-- ground_test.lua — efeitos de skill de área no solo (lingering) no snapshot.
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

-- Dieter casta Lava Slide (ground, com duração) num monstro
local scn = { grid={w=40,h=40}, dt=50, homunId=100, ownerId=1,
  entities={ {id=1,kind="owner",x=19,y=20,hp=1000,maxhp=1000},
    {id=100,kind="homun",x=20,y=20,hp=100,maxhp=100,sp=1000,maxsp=1000,homunType=C.DIETER},
    {id=200,kind="monster",x=24,y=20,hp=2000,maxhp=2000,atk=2,aggro=12,etype=1042} } }
local tree = { type="selector", children={
  { type="check", name="HasValidTarget", child={ type="action", name="UseSkill", params={ skill=SID.MH_LAVA_SLIDE, level=1 } } },
  { type="check", name="CanEngage", child={ type="action", name="AcquireTarget" } },
} }
disp("load", scn); disp("setTree", tree)

print("== efeito de área no solo ==")
local s
for i=1,8 do s = disp("step"); if #s.ground > 0 then break end end
check(#s.ground >= 1, "skill de área cria um efeito no solo")
local fx = s.ground[1]
check(fx.size and fx.size > 0, "efeito traz o tamanho da área (size)")
check(fx.remaining and fx.remaining > 0 and fx.total and fx.total > 0, "efeito traz tempo restante e total")
check(fx.x ~= nil and fx.y ~= nil and fx.skill == SID.MH_LAVA_SLIDE, "efeito traz posição e a skill")

local total = fx.total
-- some quando o tempo acaba
disp("clearTree")   -- para de recastar, deixa o efeito existente expirar
for i=1, math.floor(total/50) + 3 do s = disp("step") end
check(#s.ground == 0, "o destaque some quando o tempo acaba")

-- tempo restante diminui
disp("load", scn); disp("setTree", tree)
for i=1,8 do s = disp("step"); if #s.ground > 0 then break end end
local r1 = s.ground[1].remaining
disp("clearTree")
s = disp("step")
check(s.ground[1] and s.ground[1].remaining < r1, "tempo restante do efeito diminui a cada tick")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
