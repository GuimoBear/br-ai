-- extras8c_test.lua — Fase 8c: IdleWalk, movimento sticky, ajuste de AoE e skill-S em chase/attack.
-- Uso: texlua tools/extras8c_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function reason(s) return s.intent and s.intent.reason end

print("== IdleWalk: perambula perto do dono ==")
local function idleScen(cfg, sp)
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = sp or 9000, maxsp = 9000, homunType = C.VANILMIRTH },
  } }
end
local idleTree = { type = "action", name = "IdleWalk" }
disp("setTree", idleTree); disp("load", idleScen({ UseIdleWalk = true, IdleWalkDistance = 3 }))
check(reason(disp("step")) == "idlewalk", "UseIdleWalk=true: perambula (reason='idlewalk')")
disp("setTree", idleTree); disp("load", idleScen({ UseIdleWalk = false }))
check(reason(disp("step")) ~= "idlewalk", "UseIdleWalk=false: NÃO perambula")
disp("setTree", idleTree); disp("load", idleScen({ UseIdleWalk = true, IdleWalkSP = 50 }, 20)) -- SP% 20 < 50
check(reason(disp("step")) ~= "idlewalk", "SP% abaixo de IdleWalkSP: NÃO perambula")

print("== MoveToOwner: sticky ==")
local function followScen(cfg, ownerX, withMon)
  local ents = {
    { id = 1, kind = "owner", x = ownerX or 24, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.VANILMIRTH },
  }
  if withMon then ents[#ents + 1] = { id = 200, kind = "monster", x = 20, y = 22, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false } end
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = ents }
end
-- dono a 4; FollowStayBack=3
disp("setTree", { type = "action", name = "MoveToOwner" }); disp("load", followScen({}, 24))
check(reason(disp("step")) == "follow", "sem sticky: dono a 4 (>FollowStayBack 3) → segue")
disp("setTree", { type = "action", name = "MoveToOwner" }); disp("load", followScen({ MoveSticky = true, StickyMargin = 2 }, 24))
check(reason(disp("step")) ~= "follow", "MoveSticky: deadband maior (4 <= 3+2) → NÃO segue")
-- MoveStickyFight: com alvo, não volta ao dono
local followFight = { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, { type = "action", name = "MoveToOwner" } } }
disp("setTree", followFight); disp("load", followScen({}, 28, true))
check(reason(disp("step")) == "follow", "sem MoveStickyFight: com alvo, ainda segue o dono distante")
disp("setTree", followFight); disp("load", followScen({ MoveStickyFight = true }, 28, true))
check(reason(disp("step")) ~= "follow", "MoveStickyFight: com alvo ativo, NÃO volta ao dono")

print("== UseMainSkill: gates de skill-S (chase/attack) ==")
local function vanScen(cfg, monX)
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.VANILMIRTH },
    { id = 200, kind = "monster", x = monX or 21, y = 20, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
  } }
end
local mainTree = { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, { type = "action", name = "UseMainSkill" } } }
local function cast(s) return s.intent and s.intent.skill == SID.HVAN_CAPRICE end
-- alvo colado (dist 1 = melee): UseHomunSSkillAttack
disp("setTree", mainTree); disp("load", vanScen({ UseHomunSSkillAttack = false }, 21))
check(not cast(disp("step")), "em alcance + UseHomunSSkillAttack=false: NÃO usa skill principal")
disp("setTree", mainTree); disp("load", vanScen({ UseHomunSSkillAttack = true }, 21))
check(cast(disp("step")), "em alcance + UseHomunSSkillAttack=true: usa skill principal")
-- alvo a 5 (dentro do range 9 do Caprice, fora do AttackRange 1 = chase): UseHomunSSkillChase
disp("setTree", mainTree); disp("load", vanScen({ UseHomunSSkillChase = false }, 25))
check(not cast(disp("step")), "aproximando + UseHomunSSkillChase=false: NÃO usa skill principal")
disp("setTree", mainTree); disp("load", vanScen({ UseHomunSSkillChase = true }, 25))
check(cast(disp("step")), "aproximando + UseHomunSSkillChase=true: usa skill principal")

print("== UseAoESkill: AutoMobMode / AoEFixedLevel / AoEMaximizeTargets ==")
local aoeTree = { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, { type = "action", name = "UseAoESkill" } } }
-- cluster colado de 3 monstros
local function dieterScen(cfg, ents)
  local base = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.DIETER },
  }
  for _, e in ipairs(ents) do base[#base + 1] = e end
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = base }
end
local cluster = {
  { id = 200, kind = "monster", x = 22, y = 20, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
  { id = 201, kind = "monster", x = 22, y = 21, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
  { id = 202, kind = "monster", x = 23, y = 20, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
}
local function aoeStep()
  for i = 1, 3 do local s = disp("step"); if s.intent and s.intent.skill == SID.MH_LAVA_SLIDE then return s.intent end end; return nil
end
disp("setTree", aoeTree); disp("load", dieterScen({ AutoMobCount = 2, AutoMobMode = 0 }, cluster))
check(aoeStep() == nil, "AutoMobMode=0: NÃO usa AoE automática")
disp("setTree", aoeTree); disp("load", dieterScen({ AutoMobCount = 2, AoEFixedLevel = 3 }, cluster))
local i1 = aoeStep()
check(i1 and i1.level == 3, "AoEFixedLevel=3: lança a AoE no nível 3 (lvl=" .. tostring(i1 and i1.level) .. ")")
-- maximize: alvo isolado colado + cluster afastado; nível 3 (área pequena, half=1)
local maxEnts = {
  { id = 200, kind = "monster", x = 20, y = 21, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false }, -- isolado, mais perto (vira alvo)
  { id = 210, kind = "monster", x = 24, y = 20, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
  { id = 211, kind = "monster", x = 24, y = 21, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
  { id = 212, kind = "monster", x = 25, y = 20, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
}
disp("setTree", aoeTree); disp("load", dieterScen({ AutoMobCount = 2, AoEFixedLevel = 3, AoEMaximizeTargets = false }, maxEnts))
local i0 = aoeStep()
check(i0 and i0.x < 24, "sem maximize: Dieter (sem mainAtk) mira no ALVO isolado (x=" .. tostring(i0 and i0.x) .. " < 24, dispara em 1) [#1]")
disp("setTree", aoeTree); disp("load", dieterScen({ AutoMobCount = 2, AoEFixedLevel = 3, AoEMaximizeTargets = true }, maxEnts))
local i2 = aoeStep()
check(i2 and i2.x >= 24, "AoEMaximizeTargets: mira no aglomerado (x=" .. tostring(i2 and i2.x) .. " >= 24)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
