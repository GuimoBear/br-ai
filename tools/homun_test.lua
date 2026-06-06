-- homun_test.lua — verifica que cada homunculo usa a skill certa (perfis adaptativos).
-- Uso: texlua tools/homun_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json = BRAI.json
local C = BRAI.const
local SID = BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end

local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

-- monta cenario: homun de um tipo + dono + lista de monstros {x,y}
local function scenario(htype, ownerHp, mobs)
	local ents = {
		{ id = 1, kind = "owner", x = 10, y = 10, hp = ownerHp or 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 100, maxhp = 100, sp = 1000, maxsp = 1000, homunType = htype },
	}
	for i, m in ipairs(mobs or {}) do
		ents[#ents + 1] = { id = 200 + i, kind = "monster", x = m.x, y = m.y, hp = 200, maxhp = 200, atk = 4, aggro = 12, etype = 1042 }
	end
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = ents }
end

-- avanca ate intent satisfazer pred (ou max passos); devolve o snapshot
local function runUntil(pred, max)
	for i = 1, (max or 8) do
		local s = disp("step")
		if pred(s.intent) then return s end
	end
	return disp("snapshot")
end
local function isSkill(id) return function(it) return it and it.kind == "skill" and it.skill == id end end

print("== skills por homunculo ==")

-- Vanilmirth: Caprice (bolt alcance 9)
disp("load", scenario(C.VANILMIRTH, 1000, { { x = 24, y = 20 } }))
local s = runUntil(isSkill(SID.HVAN_CAPRICE))
check(s.intent and s.intent.skill == SID.HVAN_CAPRICE, "Vanilmirth usa Caprice")

-- Filir: Moonlight (melee, single) — monstro adjacente
disp("load", scenario(C.FILIR, 1000, { { x = 21, y = 20 } }))
s = runUntil(isSkill(SID.HFLI_MOON))
check(s.intent and s.intent.skill == SID.HFLI_MOON, "Filir usa Moonlight")

-- Sera: Summon Legion como primeira acao de combate
disp("load", scenario(C.SERA, 1000, { { x = 24, y = 20 } }))
s = runUntil(function(it) return it and it.kind == "skill" end)
check(s.intent and s.intent.skill == SID.MH_SUMMON_LEGION, "Sera invoca a Legiao primeiro")

-- Eira, alvo unico: Erase Cutter
disp("load", scenario(C.EIRA, 1000, { { x = 25, y = 20 } }))
s = runUntil(isSkill(SID.MH_ERASER_CUTTER))
check(s.intent and s.intent.skill == SID.MH_ERASER_CUTTER, "Eira (1 alvo) usa Erase Cutter")

-- Eira, mob: Xeno Slasher (AoE) — 3 monstros agrupados
disp("load", scenario(C.EIRA, 1000, { { x = 25, y = 20 }, { x = 25, y = 21 }, { x = 24, y = 21 } }))
s = runUntil(isSkill(SID.MH_XENO_SLASHER))
check(s.intent and s.intent.skill == SID.MH_XENO_SLASHER, "Eira (mob) usa Xeno Slasher (AoE)")

-- Dieter, mob: Lava Slide (AoE)
disp("load", scenario(C.DIETER, 1000, { { x = 25, y = 20 }, { x = 25, y = 21 }, { x = 24, y = 21 } }))
s = runUntil(isSkill(SID.MH_LAVA_SLIDE))
check(s.intent and s.intent.skill == SID.MH_LAVA_SLIDE, "Dieter (mob) usa Lava Slide (AoE)")

-- Bayeri: Stahl Horn
disp("load", scenario(C.BAYERI, 1000, { { x = 24, y = 20 } }))
s = runUntil(isSkill(SID.MH_STAHL_HORN))
check(s.intent and s.intent.skill == SID.MH_STAHL_HORN, "Bayeri usa Stahl Horn")

-- Eleanor: Sonic Claw (melee) — adjacente
disp("load", scenario(C.ELEANOR, 1000, { { x = 21, y = 20 } }))
s = runUntil(isSkill(SID.MH_SONIC_CLAW))
check(s.intent and s.intent.skill == SID.MH_SONIC_CLAW, "Eleanor usa Sonic Claw")

-- Lif: cura o dono quando ele esta com HP baixo
disp("load", scenario(C.LIF, 250, {}))   -- dono 25% (<HealOwnerHP 50)
s = runUntil(function(it) return it and it.kind == "skill" and it.heal == "owner" end, 3)
check(s.intent and s.intent.skill == SID.HLIF_HEAL and s.intent.heal == "owner", "Lif cura o dono (Healing Hands)")

-- Amistr: Castling quando o dono esta cercado
disp("load", scenario(C.AMISTR, 1000, { { x = 9, y = 10 }, { x = 11, y = 10 }, { x = 10, y = 9 } }))
-- coloca o homun perto do dono para os monstros mirarem o dono
disp("setOwner", { x = 10, y = 10 })
s = runUntil(function(it) return it and it.kind == "skill" and it.castling end, 6)
check(s.intent and s.intent.castling == true, "Amistr usa Castling com dono cercado")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
