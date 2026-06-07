-- skill_effects_test.lua — efeitos representativos (Renewal) no simulador:
-- dano por ATK/MATK, dano fixo, %HP, DoT (dano por segundo), cura por % e status.
-- Uso: texlua tools/skill_effects_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json = BRAI.json

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function dispatch(method, obj)
	return json.decode(SIM_DISPATCH(method, obj and json.encode(obj) or ""))
end
local function mon(snap, id) for _, e in ipairs(snap.entities) do if e.id == id then return e end end end

local function scenario(homunType, atk, matk)
	return {
		grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
		config = { AggroDist = 20, AggroHP = 0, AggroSP = 0, AttackRange = 1, MoveBounds = 40, FollowStayBack = 3, UseAttackSkill = true, AttackSkillReserveSP = 0 },
		entities = {
			{ id = 1,   kind = "owner",   x = 20, y = 20, hp = 2000, maxhp = 2000 },
			{ id = 100, kind = "homun",   x = 20, y = 20, hp = 300, maxhp = 300, sp = 5000, maxsp = 5000, homunType = homunType, atk = atk, matk = matk },
			{ id = 200, kind = "monster", x = 22, y = 20, hp = 9000, maxhp = 9000, atk = 1, aggro = 2, aggressive = false, etype = 1002 },
		},
	}
end

local function useSkillTree(skill, level, on)
	return { type = "sequence", children = {
		{ type = "action", name = "AcquireTarget", params = { by = "nearest" } },
		{ type = "action", name = "UseSkill", params = { skill = skill, level = level, on = on or "enemy" } },
	} }
end

print("== efeitos de skill no simulador (Renewal representativo) ==")

-- 1) Caprice (Vanilmirth, mágico): dano = MATK * 500% no Lv5
dispatch("setTree", useSkillTree(8013, 5, "enemy"))
dispatch("load", scenario(4, 100, 200))
local s; for _ = 1, 3 do s = dispatch("step") end
check(mon(s, 200).hp == 9000 - 1000, "Caprice usa MATK (200*500% = 1000 de dano)")

-- 2) mesma Caprice com MATK diferente prova que escala por MATK (não ATK)
dispatch("setTree", useSkillTree(8013, 5, "enemy"))
dispatch("load", scenario(4, 100, 50))
for _ = 1, 3 do s = dispatch("step") end
check(mon(s, 200).hp == 9000 - 250, "Caprice escala por MATK (50*500% = 250), ignora ATK")

-- 3) Needle of Paralysis (Sera, físico) Lv1: dano = ATK * 450% + status Paralisia
dispatch("setTree", useSkillTree(8019, 1, "enemy"))
dispatch("load", scenario(50, 100, 999))
for _ = 1, 3 do s = dispatch("step") end
check(mon(s, 200).hp == 9000 - 450, "Needle usa ATK (100*450% = 450), ignora MATK")
check(mon(s, 200).status ~= nil, "Needle aplica status (Paralisia) no monstro")

-- 4) Lava Slide (Dieter, DoT físico) Lv10: ~ATK*500% por segundo durante 15s
dispatch("setTree", useSkillTree(8041, 10, "enemy"))
dispatch("load", scenario(51, 100, 50))
local hp0 = 9000
for _ = 1, 25 do s = dispatch("step") end   -- ~1.25s
local lost = hp0 - mon(s, 200).hp
check(lost >= 500, "Lava Slide causa dano por segundo (DoT) — perdeu " .. lost .. " em ~1.25s")

-- 5) MATK editável via updateEntity reflete no dano
dispatch("setTree", useSkillTree(8013, 1, "enemy"))
dispatch("load", scenario(4, 100, 100))
dispatch("updateEntity", { id = 100, matk = 400 })
for _ = 1, 3 do s = dispatch("step") end
check(mon(s, 200).hp == 9000 - 400, "updateEntity MATK=400 → Caprice Lv1 (400*100% = 400)")

-- 6) catálogo expõe o efeito por nível para o editor
local cat = BRAI.skillCatalog(51, 0)  -- Dieter
local lava
for _, sk in ipairs(cat) do if sk.id == 8041 then lava = sk end end
check(lava and lava.effect and lava.effect.kind == "physical", "skillCatalog expõe effect.kind do Lava Slide")
check(lava and lava.effect and lava.effect.dot ~= nil, "skillCatalog expõe effect.dot (dano por segundo)")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
