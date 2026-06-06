-- chase_test.lua — ChaseTarget deve aproximar até a distância correta da skill usada.
-- Bug: com skill melee (Blast Forge, alcance 1) e effectiveRange do perfil (7), o homún
-- parava a 7 e nunca chegava. Com o parâmetro 'dist', ele fecha até a distância pedida.
-- Uso: texlua tools/chase_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function ent(s, id) for _, e in ipairs(s.entities) do if e.id == id then return e end end end
local function cheb(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

-- árvore Dieter/Amistr com Blast Forge (alcance 1); chaseParams permite setar o 'dist'
local function tree(chaseParams)
	return { type = "selector", children = {
		{ type = "check", name = "HasValidTarget", child = { type = "selector", children = {
			{ type = "action", name = "UseSkill", params = { skill = SID.MH_BLAST_FORGE, level = 10, on = "enemy" } },
			{ type = "check", name = "InAttackRange", child = { type = "action", name = "AttackTarget" } },
			{ type = "action", name = "ChaseTarget", params = chaseParams },
		} } },
		{ type = "check", name = "CanEngage", child = { type = "action", name = "AcquireTarget" } },
		{ type = "action", name = "Idle" },
	} }
end
local function scen()
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = { BaseHomunType = C.AMISTR }, entities = {
		{ id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.DIETER },
		{ id = 200, kind = "monster", x = 30, y = 20, hp = 100000, maxhp = 100000, atk = 0, aggro = 1, atkInterval = 100000 },  -- passivo, dist 10
	} }
end
local function run(chaseParams, steps)
	disp("setTree", tree(chaseParams))
	disp("load", scen())
	local minDist, casted = 999, false
	for _ = 1, (steps or 60) do
		local s = disp("step")
		local h, m = ent(s, 100), ent(s, 200)
		if h and m then minDist = math.min(minDist, cheb(h, m)) end
		if s.intent and s.intent.skill == SID.MH_BLAST_FORGE then casted = true end
	end
	return minDist, casted
end

print("== ChaseTarget: distância de parada ==")

-- sem 'dist': usa effectiveRange do perfil Dieter (Lava Slide ~7) -> trava longe, nao casta
local d0 = run(nil)
check(d0 > 1, "sem 'dist': para no alcance do perfil (>1), nao chega no melee (parou a " .. d0 .. ")")

-- com dist=1: fecha até ficar adjacente e a Blast Forge sai
local d1, cast1 = run({ dist = 1 })
check(d1 == 1, "dist=1: aproxima até ficar adjacente (chegou a " .. d1 .. ")")
check(cast1, "dist=1: a Blast Forge passa a ser lançada")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
