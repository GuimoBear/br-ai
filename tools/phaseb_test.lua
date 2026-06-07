-- phaseb_test.lua — B2 (dance attack), B4 (desistência/inalcançável) + cobertura
-- das condições de HP do dono (OwnerHpBelow/Above), que faltavam.
-- Uso: texlua tools/phaseb_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C = BRAI.json, BRAI.const

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function ent(s, id) for _, e in ipairs(s.entities) do if e.id == id then return e end end end
local function cheb(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

print("== B2: dance attack ==")
disp("setTree", { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "action", name = "DanceAttack" },
} })
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 16, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 200, kind = "monster", x = 21, y = 20, hp = 100000, maxhp = 100000, atk = 0, aggro = 1, atkInterval = 100000, aggressive = false },
} })
local atks, moves, maxDist = 0, 0, 0
for _ = 1, 8 do
	local s = disp("step")
	local it = s.intent
	if it and it.kind == "attack" then atks = atks + 1 end
	if it and it.kind == "move" and it.reason == "dance" then moves = moves + 1 end
	local h, m = ent(s, 100), ent(s, 200)
	if h and m then maxDist = math.max(maxDist, cheb(h, m)) end
end
check(atks > 0, "dance: chega a atacar o alvo (" .. atks .. " ataques)")
check(moves > 0, "dance: também reposiciona (" .. moves .. " passos de dança)")
check(maxDist <= 1, "dance: mantém-se adjacente ao alvo enquanto dança")

print("== B4: desistência de perseguição / inalcançável ==")
-- alvo que sempre escapa: a cada passo eu o reposiciono mantendo a distância (sem progresso)
disp("setTree", { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "action", name = "ChaseTarget", params = { dist = 1, giveUp = 4 } },
} })
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 200, kind = "monster", x = 24, y = 20, hp = 5000, maxhp = 5000, atk = 0, aggro = 1, atkInterval = 100000, aggressive = false },
} })
local gaveUp = false
for _ = 1, 8 do
	local s = disp("step")
	local h = ent(s, 100)
	-- mantém o monstro 4 células à frente do homún (alvo inalcançável)
	disp("moveEntity", { id = 200, x = math.min(39, h.x + 4), y = 20 })
	if not s.target or s.target == 0 then gaveUp = true; break end
end
check(gaveUp, "ChaseTarget(giveUp=4): desiste do alvo que não consegue alcançar")

-- após desistir, AcquireTarget não repega o inalcançável (dentro do timeout)
local s = disp("step")
check(not s.target or s.target == 0, "alvo marcado inalcançável: AcquireTarget não o repega")

print("== cobertura: HP% do dono (OwnerHpBelow/Above) ==")
local function ownerScen(ownerHp)
	return { grid = { w = 20, h = 20 }, dt = 50, homunId = 100, ownerId = 1, entities = {
		{ id = 1, kind = "owner", x = 10, y = 10, hp = ownerHp, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 11, y = 11, hp = 100, maxhp = 100, sp = 100, maxsp = 100, homunType = C.LIF },
	} }
end
-- dono a 30% -> OwnerHpBelow(50) verdadeiro (executa o filho UseHealOwner... aqui Idle/Flee p/ observar)
disp("setTree", { type = "check", name = "OwnerHpBelow", params = { pct = 50 }, child = { type = "action", name = "Flee" } })
disp("load", ownerScen(300))
s = disp("step")
check(s.bb.owner.hpPct == 30, "snapshot expõe HP% do dono (30%)")
-- com dono a 80% -> OwnerHpBelow(50) falso; OwnerHpAbove(50) verdadeiro
disp("setTree", { type = "selector", children = {
	{ type = "check", name = "OwnerHpBelow", params = { pct = 50 }, child = { type = "action", name = "Flee" } },
	{ type = "check", name = "OwnerHpAbove", params = { pct = 50 }, child = { type = "action", name = "Idle" } },
} })
disp("load", ownerScen(800))
s = disp("step")
check((not s.intent) or s.intent.kind ~= "move", "OwnerHpAbove(50) com dono a 80%: não foge (cai no ramo Idle)")

print("== cobertura: timeout de inalcançável + OwnerUnderAttack ==")
-- cenário próprio: provoca o give-up e depois para o monstro; após ~5s o inalcançável expira
disp("setTree", { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "action", name = "ChaseTarget", params = { dist = 1, giveUp = 4 } },
} })
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 200, kind = "monster", x = 24, y = 20, hp = 5000, maxhp = 5000, atk = 0, aggro = 1, atkInterval = 100000, aggressive = false },
} })
for _ = 1, 8 do local s2 = disp("step"); local h = ent(s2, 100); disp("moveEntity", { id = 200, x = math.min(39, h.x + 4), y = 20 }) end
disp("moveEntity", { id = 200, x = 24, y = 20 })   -- agora parado e alcançável
local reacquired = false
for _ = 1, 130 do
	local s2 = disp("step")
	if s2.target == 200 then reacquired = true; break end
end
check(reacquired, "timeout: após ~5s o alvo inalcançável volta a poder ser mirado")

-- OwnerUnderAttack: gate dispara só quando há monstro atacando o dono
disp("setTree", { type = "action", name = "Idle" })
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 10, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 25, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 200, kind = "monster", x = 11, y = 20, hp = 500, maxhp = 500, atk = 5, aggro = 12, atkInterval = 1000 },
} })
disp("step")   -- monstro mira o dono
disp("setTree", { type = "check", name = "OwnerUnderAttack", child = { type = "action", name = "AcquireOwnerAttacker" } })
local s3 = disp("step")
check(s3.target == 200, "OwnerUnderAttack verdadeiro -> executa o filho (mira o atacante 200)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
