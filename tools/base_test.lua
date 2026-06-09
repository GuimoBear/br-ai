-- base_test.lua — verifica a mescla de perfil S + tipo base (OldHomunType).
-- Uso: texlua tools/base_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json = BRAI.json
local C = BRAI.const
local SID = BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

local function scenario(htype, base, ownerHp, mobs)
	local ents = {
		{ id = 1, kind = "owner", x = 10, y = 10, hp = ownerHp or 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 100, maxhp = 100, sp = 1000, maxsp = 1000, homunType = htype },
	}
	for i, m in ipairs(mobs or {}) do
		ents[#ents + 1] = { id = 200 + i, kind = "monster", x = m.x, y = m.y, hp = 300, maxhp = 300, atk = 3, aggro = 12, etype = 1042 }
	end
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = ents, config = { BaseHomunType = base } }
end
local function runUntil(pred, max)
	for i = 1, (max or 10) do local s = disp("step"); if pred(s.intent) then return s end end
	return disp("snapshot")
end
local function isSkill(id) return function(it) return it and it.kind == "skill" and it.skill == id end end

print("== Homunculus S + tipo base ==")

-- Dieter (so AoE) base Vanilmirth: ganha Caprice p/ alvo unico (alcance 9)
disp("load", scenario(C.DIETER, C.VANILMIRTH, 1000, { { x = 25, y = 20 } }))
local s = runUntil(isSkill(SID.HVAN_CAPRICE))
check(s.intent and s.intent.skill == SID.HVAN_CAPRICE, "Dieter base Vanilmirth usa Caprice em alvo unico")

-- Dieter SEM base, alvo unico: sem mainAtk, a AoE e a ofensiva principal -> Lava Slide
-- (PLANO-GERACAO-LUA #1: a AoE dispara em alvo unico quando nao ha single-target)
disp("load", scenario(C.DIETER, 0, 1000, { { x = 21, y = 20 } }))
s = runUntil(isSkill(SID.MH_LAVA_SLIDE))
check(s.intent and s.intent.kind == "skill" and s.intent.skill == SID.MH_LAVA_SLIDE, "Dieter sem base usa AoE (Lava Slide) em alvo unico [#1]")

-- Dieter base Amistr: dono cercado -> Castling (skill da base Amistr)
disp("load", scenario(C.DIETER, C.AMISTR, 1000, { { x = 9, y = 10 }, { x = 11, y = 10 }, { x = 10, y = 9 } }))
disp("setOwner", { x = 10, y = 10 })
s = runUntil(function(it) return it and it.kind == "skill" and it.castling end, 6)
check(s.intent and s.intent.castling == true, "Dieter base Amistr usa Castling (skill da base)")

-- Sera base Vanilmirth: pode curar a si (Chaotic Blessing da base) com HP baixo
disp("load", scenario(C.SERA, C.VANILMIRTH, 1000, {}))
-- derruba o HP do homun via varios ataques? mais simples: cenario sem mob, HP baixo manual
-- recarrega com HP baixo
local scn = scenario(C.SERA, C.VANILMIRTH, 1000, {})
scn.entities[2].hp = 30   -- 30% < HealSelfHP(40)
disp("load", scn)
s = runUntil(function(it) return it and it.kind == "skill" and it.heal == "self" end, 3)
check(s.intent and s.intent.skill == SID.HVAN_CHAOTIC and s.intent.heal == "self", "Sera base Vanilmirth cura a si (Chaotic Blessing)")

-- Sera SEM base: nao tem cura propria -> nao emite heal self
scn = scenario(C.SERA, 0, 1000, {})
scn.entities[2].hp = 30
disp("load", scn)
s = runUntil(function(it) return it and it.kind == "skill" and it.heal == "self" end, 3)
check(not (s.intent and s.intent.heal == "self"), "Sera sem base NAO cura a si (sem skill de cura)")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
