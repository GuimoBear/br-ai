-- rescue_ks_test.lua — A3 (resgate do dono) e A1 (anti-Kill-Steal).
-- Uso: texlua tools/rescue_ks_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C = BRAI.json, BRAI.const

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

-- helper: roda 1 passo com Idle (deixa os monstros mirarem) e então troca a árvore
local function settle(tree)
	disp("setTree", { type = "action", name = "Idle" })
	disp("step")
	disp("setTree", tree)
	return disp("step")
end

print("== A3: resgate do dono ==")
-- monstro ao lado do dono (longe do homún) -> agride o dono
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 10, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 200, kind = "monster", x = 11, y = 20, hp = 500, maxhp = 500, atk = 5, aggro = 12, atkInterval = 1000 },
} })
local s = settle({ type = "action", name = "AcquireOwnerAttacker" })
check(s.target == 200, "AcquireOwnerAttacker: mira no monstro que ataca o dono (alvo=200)")

-- sem ninguém atacando o dono -> falha (sem alvo)
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 10, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
} })
s = settle({ type = "action", name = "AcquireOwnerAttacker" })
check(not s.target or s.target == 0, "AcquireOwnerAttacker: sem atacante do dono -> sem alvo")

print("== A1: anti-Kill-Steal ==")
-- cenário: aliado em (30,20) com um monstro do lado dele (29,20) -> monstro mira o ALIADO (reivindicado)
local function scenKS(ksmode)
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = { KSMode = ksmode }, entities = {
		{ id = 1, kind = "owner", x = 20, y = 18, hp = 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
		{ id = 300, kind = "ally", x = 30, y = 20, hp = 1000, maxhp = 1000 },
		{ id = 200, kind = "monster", x = 29, y = 20, hp = 500, maxhp = 500, atk = 5, aggro = 12, atkInterval = 1000 },
	} }
end

-- polite (padrão): ignora o monstro reivindicado pelo aliado
disp("load", scenKS("polite"))
s = settle({ type = "action", name = "AcquireTarget" })
check(not s.target or s.target == 0, "KSMode=polite: ignora monstro reivindicado pelo aliado")

-- always: mira mesmo assim (free-for-all)
disp("load", scenKS("always"))
s = settle({ type = "action", name = "AcquireTarget" })
check(s.target == 200, "KSMode=always: mira o monstro mesmo reivindicado")

-- controle: monstro livre (mirando o homún) é alvo válido mesmo em polite
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = { KSMode = "polite" }, entities = {
	{ id = 1, kind = "owner", x = 20, y = 18, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 200, kind = "monster", x = 22, y = 20, hp = 500, maxhp = 500, atk = 5, aggro = 12, atkInterval = 1000 },
} })
s = settle({ type = "action", name = "AcquireTarget" })
check(s.target == 200, "polite: monstro livre (mira no homún) continua sendo alvo válido")

print("== A3b: OwnerUnderAttack com 'count' mínimo ==")
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 10, y = 20, hp = 100000, maxhp = 100000 },
	{ id = 100, kind = "homun", x = 24, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 201, kind = "monster", x = 9,  y = 20, hp = 5000, maxhp = 5000, atk = 5, aggro = 12, atkInterval = 1000 },
	{ id = 202, kind = "monster", x = 11, y = 20, hp = 5000, maxhp = 5000, atk = 5, aggro = 12, atkInterval = 1000 },
	{ id = 203, kind = "monster", x = 10, y = 21, hp = 5000, maxhp = 5000, atk = 5, aggro = 12, atkInterval = 1000 },
} })
settle({ type = "action", name = "Idle" })
local OUA = BRAI.registry.conditions.OwnerUnderAttack
local bb = BRAI.sim.bb
check(BRAI.perception.aggroCount(bb, bb.owner.id) == 3, "3 monstros mirando o dono")
check(OUA(bb) == true, "OwnerUnderAttack() sem count -> true (>=1, compat)")
check(OUA(bb, { count = 1 }) == true, "count=1 -> true")
check(OUA(bb, { count = 3 }) == true, "count=3 -> true (exatamente 3 atacantes)")
check(OUA(bb, { count = 4 }) == false, "count=4 -> false (só 3 atacantes)")
-- sem dono atacado: count>=1 falso
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 10, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
} })
settle({ type = "action", name = "Idle" })
check(OUA(BRAI.sim.bb, { count = 1 }) == false, "sem atacantes -> count=1 false")

print("== A3c: SelfUnderAttack com 'count' (padrão 1, sem berserk) ==")
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 38, y = 20, hp = 100000, maxhp = 100000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 201, kind = "monster", x = 18, y = 20, hp = 5000, maxhp = 5000, atk = 5, aggro = 12, atkInterval = 1000 },
	{ id = 202, kind = "monster", x = 22, y = 20, hp = 5000, maxhp = 5000, atk = 5, aggro = 12, atkInterval = 1000 },
	{ id = 203, kind = "monster", x = 20, y = 21, hp = 5000, maxhp = 5000, atk = 5, aggro = 12, atkInterval = 1000 },
} })
settle({ type = "action", name = "Idle" })
local SUA = BRAI.registry.conditions.SelfUnderAttack
local bbS = BRAI.sim.bb
check(BRAI.perception.aggroCount(bbS, bbS.self.id) == 3, "3 monstros mirando o homúnculo")
check(SUA(bbS) == true, "SelfUnderAttack() sem count -> true (padrão 1)")
check(SUA(bbS, { count = 1 }) == true, "count=1 -> true")
check(SUA(bbS, { count = 3 }) == true, "count=3 -> true (exatamente 3 atacantes)")
check(SUA(bbS, { count = 4 }) == false, "count=4 -> false (só 3 atacantes)")
check(bbS.flags.berserk == false, "SelfUnderAttack NÃO liga a flag berserk (≠ Mobbed)")
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 10, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
} })
settle({ type = "action", name = "Idle" })
check(SUA(BRAI.sim.bb, { count = 1 }) == false, "sem atacantes -> count=1 false")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
