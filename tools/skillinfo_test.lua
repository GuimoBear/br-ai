-- skillinfo_test.lua — log de skill + bloco skills{cooldowns,buffs} no snapshot do sim.
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C = BRAI.json, BRAI.const
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function scn(ht) return { grid={w=40,h=40},dt=50,homunId=100,ownerId=1,
  entities={ {id=1,kind="owner",x=10,y=10,hp=1000,maxhp=1000},
    {id=100,kind="homun",x=20,y=20,hp=100,maxhp=100,sp=1000,maxsp=1000,homunType=ht},
    {id=200,kind="monster",x=24,y=20,hp=400,maxhp=400,atk=3,aggro=12,etype=1042}}} end
local function logHasSkill(log) for _,l in ipairs(log) do if l:find("SP ") then return l end end return nil end

print("== snapshot: skills/buffs + log ==")
-- frame 0 já traz o bloco skills (vazio)
local s0 = disp("load", scn(C.SERA))
check(s0.skills and s0.skills.cooldowns ~= nil and s0.skills.buffs ~= nil, "load: bloco skills presente (cooldowns/buffs)")

-- Sera casta Summon Legion -> log + cooldown + buff
local s
for i = 1, 6 do s = disp("step"); if s.intent and s.intent.kind == "skill" then break end end
check(logHasSkill(s.log) ~= nil, "log registra a skill usada (com SP)")
check(#s.skills.cooldowns >= 1, "cooldown ativo aparece após cast")
local cd = s.skills.cooldowns[1]
check(cd.name ~= nil and cd.remaining and cd.remaining > 0, "cooldown traz nome e tempo restante")
check(cd.total and cd.total > 0 and cd.remaining <= cd.total, "cooldown traz total (p/ barra de progresso)")
check(#s.skills.buffs >= 1, "buff ativo aparece (Summon Legion tem duração)")

-- o tempo restante diminui no próximo tick
local prev = s.skills.cooldowns[1].remaining
local s2 = disp("step")
local cur
for _, c in ipairs(s2.skills.cooldowns) do if c.skill == cd.skill then cur = c.remaining end end
check(cur ~= nil and cur < prev, "tempo restante do cooldown diminui a cada tick")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
