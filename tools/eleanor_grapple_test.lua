-- eleanor_grapple_test.lua — Fase 3: segurança do Agarrão (threat assessment + boss guard).
-- Cobre G1..G5 (PLANO §9.5). Guards de regressão: R7 (multidão/Flee=0), R8 (EQC em boss).
-- Uso: texlua tools/eleanor_grapple_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local sys = BRAI.skillsys

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

-- cenário Eleanor + monstros. mons = lista de {x,y,hp,atk,aggressive,boss}
local function scen(mons)
	local ents = {
		{ id = 1, kind = "owner", x = 5, y = 20, hp = 100000, maxhp = 100000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000,
		  sp = 9000, maxsp = 9000, atk = 900, homunType = C.ELEANOR },
	}
	for i, m in ipairs(mons or {}) do
		ents[#ents + 1] = { id = 200 + i, kind = "monster", x = m.x, y = m.y,
			hp = m.hp or 1000000, maxhp = m.hp or 1000000, atk = m.atk or 10,
			aggro = 12, aggressive = (m.aggressive ~= false), atkInterval = 1000,
			boss = m.boss or false, etype = m.etype or 1042 }
	end
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
		config = { BaseHomunType = 0, FleeHP = 0, AggroDist = 14 }, homunType = C.ELEANOR, entities = ents }
end

local function offenseTree(style, barragem)
	return { type = "sequence", children = {
		{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
		{ type = "selector", children = {
			{ type = "action", name = "UseEleanorOffense", params = { style = style, comboSpheres = barragem, window = 2000 } },
			{ type = "check", name = "InAttackRange", child = { type = "action", name = "AttackTarget" } },
			{ type = "action", name = "ChaseTarget", params = { dist = 1 } },
		} },
	} }
end

-- coleta quais skills apareceram em N passos
local function skillsSeen(n)
	local seen = {}
	for _ = 1, n do
		local s = disp("step")
		if s.intent and s.intent.skill then seen[s.intent.skill] = true end
	end
	return seen
end

print("== G1: multidão BLOQUEIA o Agarrão (R7) ==")
disp("load", scen({ { x = 19, y = 20 }, { x = 21, y = 20 }, { x = 20, y = 21 } }))
disp("setTree", offenseTree("grapple", 3))
sys.addSpheres(BRAI.sim.bb, 10)
check(BRAI.perception.threatCount(BRAI.sim.bb, 3) >= 3, "G1a: threatCount conta a multidão (>limite)")
local seen = skillsSeen(8)
check(not seen[SID.MH_TINDER_BREAKER] and not seen[SID.MH_STYLE_CHANGE],
	"G1b: multidão -> sem Tinder/Style Change (fica no power)")
check(seen[SID.MH_SONIC_CLAW], "G1c: usa o combo power na multidão")

print("== G2: alvo isolado LIBERA o Agarrão ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } }))
disp("setTree", offenseTree("grapple", 3))
sys.addSpheres(BRAI.sim.bb, 10)
check(BRAI.perception.threatCount(BRAI.sim.bb, 3) <= 1, "G2a: threatCount <= limite (isolado)")
seen = skillsSeen(8)
check(seen[SID.MH_TINDER_BREAKER], "G2b: isolado -> Tinder dispara (entra no Agarrão)")

print("== G3: boss guard — EQC NUNCA dispara em Boss/MVP (R8) ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9, boss = true } }))
disp("setTree", offenseTree("grapple", 3))
sys.addSpheres(BRAI.sim.bb, 10)
local sawT, sawC, sawE = false, false, false
for _ = 1, 14 do
	local s = disp("step"); local k = s.intent and s.intent.skill
	if k == SID.MH_TINDER_BREAKER then sawT = true
	elseif k == SID.MH_CBC then sawC = true
	elseif k == SID.MH_EQC then sawE = true end
end
check(sawT and sawC, "G3a: Tinder e C.B.C. disparam no boss")
check(not sawE, "G3b: E.Q.C. NUNCA dispara no boss (R8)")

print("== G4: style=auto + inseguro -> fallback p/ power ==")
disp("load", scen({ { x = 19, y = 20 }, { x = 21, y = 20 }, { x = 20, y = 19 } }))
disp("setTree", offenseTree("auto", 3))
sys.addSpheres(BRAI.sim.bb, 10)
seen = skillsSeen(8)
check(not seen[SID.MH_TINDER_BREAKER], "G4a: auto inseguro -> sem Tinder")
check(seen[SID.MH_SONIC_CLAW], "G4b: auto inseguro -> usa power (Sonic)")

print("== G5: liberação do Flee — rooted durante Tinder/CBC, livre após EQC ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } }))
disp("setTree", offenseTree("grapple", 3))
sys.addSpheres(BRAI.sim.bb, 10)
local rootedDuring, releasedAfterEQC = false, nil
for _ = 1, 14 do
	local s = disp("step"); local k = s.intent and s.intent.skill
	if k == SID.MH_TINDER_BREAKER or k == SID.MH_CBC then
		if BRAI.sim.bb.persist.grappleRooted == true then rootedDuring = true end
	elseif k == SID.MH_EQC then
		releasedAfterEQC = (BRAI.sim.bb.persist.grappleRooted == false)
	end
end
check(rootedDuring, "G5a: enraizado (rooted=true) durante Tinder/C.B.C.")
check(releasedAfterEQC == true, "G5b: Flee liberado (rooted=false) ao concluir E.Q.C.")

print("== G6: condição TargetIsBoss (flag de percepção e catálogo BossGroup) ==")
disp("setTree", { type = "action", name = "AcquireTarget" })
disp("load", scen({ { x = 21, y = 20, hp = 1e9, boss = true } })); disp("step")
check(BRAI.perception.targetIsBoss(BRAI.sim.bb) == true, "G6a: alvo com flag boss -> targetIsBoss true")
check(BRAI.registry.conditions.TargetIsBoss(BRAI.sim.bb) == true, "G6b: condição registrada retorna true no boss")
disp("load", scen({ { x = 21, y = 20, hp = 1e9, boss = false } })); disp("step")
check(BRAI.registry.conditions.TargetIsBoss(BRAI.sim.bb) == false, "G6c: alvo sem flag -> false")
-- caminho in-game: sem flag, mas o etype do alvo está num grupo de boss do catálogo
disp("setMonsters", { monsters = {}, groups = { { id = 9, name = "Chefes", members = { 1389 } } } })
local scB = { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
	config = { BaseHomunType = 0, FleeHP = 0, AggroDist = 14, BossGroup = 9 }, homunType = C.ELEANOR, entities = {
		{ id = 1, kind = "owner", x = 5, y = 20, hp = 100000, maxhp = 100000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000, sp = 9000, maxsp = 9000, atk = 900, homunType = C.ELEANOR },
		{ id = 201, kind = "monster", x = 21, y = 20, hp = 1e9, maxhp = 1e9, atk = 10, aggro = 12, aggressive = true, atkInterval = 1000, boss = false, etype = 1389 },
	} }
json.decode(SIM_DISPATCH("load", json.encode(scB))); disp("step")
check(BRAI.registry.conditions.TargetIsBoss(BRAI.sim.bb) == true, "G6d: sem flag, mas etype no grupo BossGroup -> true (catálogo, in-game)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
