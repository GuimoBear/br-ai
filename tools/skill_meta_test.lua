-- skill_meta_test.lua — catálogo de skills + ação UseSkill.
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json = BRAI.json
local C = BRAI.const
local SID = BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function findCat(cat, list) local out = {} for _, s in ipairs(list) do if s.cat == cat then out[#out+1]=s.id end end return out end
local function has(list, id) for _, s in ipairs(list) do if s.id == id then return s end end return nil end

print("== catálogo de skills ==")
-- Sera base Vanilmirth: skills da Sera + Caprice/Chaotic da base
local cat = disp("skillCatalog", { homunType = C.SERA, baseType = C.VANILMIRTH })
check(has(cat, SID.MH_NEEDLE_OF_PARALYZE) ~= nil, "catálogo Sera tem Needle of Paralysis")
check(has(cat, SID.HVAN_CAPRICE) ~= nil, "catálogo Sera+base Vanilmirth inclui Caprice (da base)")
local caprice = has(cat, SID.HVAN_CAPRICE)
check(caprice and caprice.cat == "single", "Caprice classificada como 'single'")
check(caprice and caprice.maxLevel == 5, "Caprice maxLevel 5")
check(caprice and caprice.range and caprice.range[5] == 9, "Caprice alcance 9 no nível 5")
local poison = has(cat, SID.MH_POISON_MIST)
check(poison and poison.cat == "aoe", "Poison Mist classificada como 'aoe'")
check(poison and poison.area ~= nil, "Poison Mist tem área")
local painkiller = has(cat, SID.MH_PAIN_KILLER)
check(painkiller and painkiller.cat == "buff", "Painkiller classificada como 'buff' (defensivo)")

-- Dieter sem base: só skills do Dieter, sem Caprice
local catD = disp("skillCatalog", { homunType = C.DIETER, baseType = 0 })
check(has(catD, SID.HVAN_CAPRICE) == nil, "Dieter sem base NÃO tem Caprice")
check(has(catD, SID.MH_LAVA_SLIDE) ~= nil and has(catD, SID.MH_LAVA_SLIDE).cat == "aoe", "Dieter tem Lava Slide (aoe)")

check(caprice and caprice.reuse and caprice.reuse[5] == 3000, "Caprice expoe recarga (3000ms)")
check(caprice and caprice.fixedCast ~= nil and caprice.varCast ~= nil and caprice.delay ~= nil, "Caprice expoe cast fixo/variavel/pos-conj")
local catA = disp("skillCatalog", { homunType = C.AMISTR, baseType = 0 })
local bl = has(catA, SID.HAMI_BLOODLUST)
check(bl and bl.duration and bl.duration[1] == 310000, "Bloodlust expoe duracao (310000ms)")

print("== ação UseSkill ==")
-- árvore só com UseSkill(Caprice, nível 3) p/ um Vanilmirth
local function scn(htype, base)
  return { grid={w=40,h=40}, dt=50, homunId=100, ownerId=1, config={BaseHomunType=base},
    entities={
      {id=1,kind="owner",x=10,y=10,hp=1000,maxhp=1000},
      {id=100,kind="homun",x=20,y=20,hp=100,maxhp=100,sp=1000,maxsp=1000,homunType=htype},
      {id=200,kind="monster",x=24,y=20,hp=300,maxhp=300,atk=3,aggro=12,etype=1042}}}
end
local tree = { type="selector", children={
  { type="sequence", children={ {type="condition",name="HasValidTarget"}, {type="action",name="UseSkill",params={skill=SID.HVAN_CAPRICE, level=3}} } },
  { type="sequence", children={ {type="condition",name="CanEngage"}, {type="action",name="AcquireTarget"} } },
}}
disp("load", scn(C.VANILMIRTH, 0))
disp("setTree", tree)
local snap
for i=1,5 do snap = disp("step"); if snap.intent and snap.intent.kind=="skill" then break end end
check(snap.intent and snap.intent.skill == SID.HVAN_CAPRICE, "UseSkill usa Caprice")
check(snap.intent and snap.intent.level == 3, "UseSkill respeita o nível escolhido (3)")

-- nível acima do conhecido é limitado ao conhecido (Caprice conhecido 5)
local tree2 = { type="selector", children={
  { type="sequence", children={ {type="condition",name="HasValidTarget"}, {type="action",name="UseSkill",params={skill=SID.HVAN_CAPRICE, level=9}} } },
  { type="sequence", children={ {type="condition",name="CanEngage"}, {type="action",name="AcquireTarget"} } },
}}
disp("load", scn(C.VANILMIRTH, 0)); disp("setTree", tree2)
for i=1,5 do snap = disp("step"); if snap.intent and snap.intent.kind=="skill" then break end end
check(snap.intent and snap.intent.level == 5, "UseSkill limita nível ao que o homúnculo conhece (5)")
disp("clearTree")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
