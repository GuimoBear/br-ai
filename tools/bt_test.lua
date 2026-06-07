-- bt_test.lua — harness offline (roda em lua/texlua, sem UI).
-- Uso (na raiz do repo):  texlua tools/bt_test.lua   (ou: lua tools/bt_test.lua)
-- Testa o motor de BT e cenários de decisão contra um cliente RO falso.

local load = dofile("lua/bootstrap.lua")
local BRAI = load("lua")

local C   = BRAI.const
local S   = BRAI.status
local bt  = BRAI.bt

----------------------------------------------------------------------
-- mini-framework de asserts
----------------------------------------------------------------------
local pass, fail = 0, 0
local function check(cond, name)
	if cond then
		pass = pass + 1
		print("  ok  - " .. name)
	else
		fail = fail + 1
		print("  FAIL- " .. name)
	end
end
local function eq(a, b, name)
	check(a == b, name .. "  (esperado=" .. tostring(b) .. ", obtido=" .. tostring(a) .. ")")
end

----------------------------------------------------------------------
-- mundo falso + backend (implementa a API da §2 do DESIGN)
----------------------------------------------------------------------
local world = { tick = 0, actors = {}, ent = {}, msg = { C.NONE_CMD }, calls = {} }

local function setEnt(id, t) world.ent[id] = t end

local backend = {
	GetV = function(v, id, a, b)
		local e = world.ent[id]
		if not e then return -1 end
		if v == C.V_POSITION then return e.x, e.y end
		if v == C.V_HP then return e.hp end
		if v == C.V_SP then return e.sp end
		if v == C.V_MAXHP then return e.maxhp end
		if v == C.V_MAXSP then return e.maxsp end
		if v == C.V_MOTION then return e.motion or C.MOTION_STAND end
		if v == C.V_HOMUNTYPE then return e.homunType or 0 end
		if v == C.V_OWNER then return e.owner or 0 end
		if v == C.V_TARGET then return e.target or 0 end
		if v == C.V_TYPE then return e.etype or 0 end
		if v == C.V_ATTACKRANGE then return 1 end
		return -1
	end,
	GetActors = function()
		local out = {}
		for i, v in ipairs(world.actors) do out[i] = v end
		return out
	end,
	GetTick   = function() return world.tick end,
	GetMsg    = function() return world.msg end,
	IsMonster = function(id) return world.ent[id] and world.ent[id].isMonster and 1 or 0 end,
	Move      = function(id, x, y) world.calls[#world.calls + 1] = { "move", id, x, y } end,
	Attack    = function(id, t) world.calls[#world.calls + 1] = { "attack", id, t } end,
	SkillObject = function() end,
	SkillGround = function() end,
	TraceAI   = function() end,
}
BRAI.ro.bind(backend)

----------------------------------------------------------------------
-- 1) Testes unitários do motor
----------------------------------------------------------------------
print("== motor de BT ==")
local bb = BRAI.Blackboard.new()

local function leaf(st) return bt.node("leaf", "leaf", function() return st end) end

eq(bt.selector({ leaf(S.FAILURE), leaf(S.SUCCESS) }):tick(bb), S.SUCCESS, "selector: primeiro sucesso vence")
eq(bt.selector({ leaf(S.FAILURE), leaf(S.FAILURE) }):tick(bb), S.FAILURE, "selector: todos falham -> FAILURE")
eq(bt.selector({ leaf(S.RUNNING), leaf(S.SUCCESS) }):tick(bb), S.RUNNING, "selector: RUNNING curto-circuita")
eq(bt.sequence({ leaf(S.SUCCESS), leaf(S.FAILURE) }):tick(bb), S.FAILURE, "sequence: para no primeiro FAILURE")
eq(bt.sequence({ leaf(S.SUCCESS), leaf(S.SUCCESS) }):tick(bb), S.SUCCESS, "sequence: todos passam -> SUCCESS")
eq(bt.inverter(leaf(S.SUCCESS)):tick(bb), S.FAILURE, "inverter: SUCCESS->FAILURE")
eq(bt.inverter(leaf(S.FAILURE)):tick(bb), S.SUCCESS, "inverter: FAILURE->SUCCESS")
eq(bt.succeeder(leaf(S.FAILURE)):tick(bb), S.SUCCESS, "succeeder: força SUCCESS")
eq(bt.parallel({ leaf(S.SUCCESS), leaf(S.FAILURE) }, "any"):tick(bb), S.SUCCESS, "parallel any: um sucesso basta")
eq(bt.parallel({ leaf(S.SUCCESS), leaf(S.FAILURE) }, "all"):tick(bb), S.FAILURE, "parallel all: um falho reprova")

-- cooldown
world.tick = 1000
local cd = bt.cooldown(500, leaf(S.SUCCESS))
eq(cd:tick(bb), S.SUCCESS, "cooldown: 1ª passa")
eq(cd:tick(bb), S.FAILURE, "cooldown: dentro da janela bloqueia")
world.tick = 1600
eq(cd:tick(bb), S.SUCCESS, "cooldown: após a janela libera")

-- limiter
local lim = bt.limiter(2, leaf(S.SUCCESS), "k")
eq(lim:tick(bb), S.SUCCESS, "limiter: uso 1")
eq(lim:tick(bb), S.SUCCESS, "limiter: uso 2")
eq(lim:tick(bb), S.FAILURE, "limiter: estourou o limite")
bb:resetCounters()
eq(lim:tick(bb), S.SUCCESS, "limiter: reset de contadores libera")

----------------------------------------------------------------------
-- 2) Cenários de decisão (árvore real do homúnculo)
----------------------------------------------------------------------
print("== cenarios de decisao ==")
local HOMUN, OWNER, MOB = 100, 1, 200

local function resetWorld()
	world.tick = 5000
	world.msg = { C.NONE_CMD }
	world.calls = {}
	world.ent = {}
	world.actors = { OWNER, HOMUN }
	setEnt(HOMUN, { x = 20, y = 20, hp = 100, sp = 100, maxhp = 100, maxsp = 100,
	                motion = C.MOTION_STAND, homunType = C.LIF, owner = OWNER })
	setEnt(OWNER, { x = 10, y = 10, hp = 100, maxhp = 100, motion = C.MOTION_STAND })
end

local function newRuntime()
	local b = BRAI.Blackboard.new()
	local tr = BRAI.tree.build(BRAI.treeSpec)
	return b, tr
end

local function step(b, tr)
	-- replica o laço de AI.lua (sem aplicar efeitos)
	local msg = world.msg
	if msg and msg[1] ~= C.NONE_CMD then
		b.command = { kind = msg[1], x = msg[2], y = msg[3], target = msg[2] }
	else
		b.command = nil
	end
	BRAI.perception.update(b, HOMUN)
	tr:tick(b)
end

-- A) seguir o dono quando longe e sem monstros
resetWorld()
do
	local b, tr = newRuntime()
	step(b, tr)
	eq(b.intent and b.intent.kind, "move", "A: intenção é mover")
	eq(b.intent and b.intent.reason, "follow", "A: motivo é seguir o dono")
	check(b.intent.x == 19 and b.intent.y == 19, "A: passo na direção do dono (19,19)")
end

-- B) adquirir e perseguir monstro a 2 células
resetWorld()
setEnt(MOB, { x = 22, y = 22, hp = 50, maxhp = 50, motion = C.MOTION_STAND, isMonster = true, etype = 1042 })
world.actors = { OWNER, HOMUN, MOB }
do
	local b, tr = newRuntime()
	step(b, tr)                                    -- tick 1: adquire
	eq(b.target, MOB, "B: alvo adquirido no tick 1")
	step(b, tr)                                    -- tick 2: persegue
	eq(b.intent and b.intent.kind, "move", "B: intenção é mover (perseguir)")
	eq(b.intent and b.intent.reason, "chase", "B: motivo é perseguir")
end

-- C) atacar monstro adjacente
resetWorld()
setEnt(MOB, { x = 21, y = 20, hp = 50, maxhp = 50, motion = C.MOTION_STAND, isMonster = true, etype = 1042 })
world.actors = { OWNER, HOMUN, MOB }
do
	local b, tr = newRuntime()
	step(b, tr)                                    -- adquire (dist 1)
	step(b, tr)                                    -- ataca
	eq(b.intent and b.intent.kind, "attack", "C: intenção é atacar")
	eq(b.intent and b.intent.target, MOB, "C: alvo do ataque é o monstro")
end

-- D) monstro morto é ignorado (alvo limpo)
resetWorld()
setEnt(MOB, { x = 21, y = 20, hp = 0, maxhp = 50, motion = C.MOTION_DEAD, isMonster = true, etype = 1042 })
world.actors = { OWNER, HOMUN, MOB }
do
	local b, tr = newRuntime()
	step(b, tr)
	eq(b.target, nil, "D: não mira monstro morto")
end

-- E) não engaja com HP abaixo de AggroHP
resetWorld()
setEnt(MOB, { x = 21, y = 20, hp = 50, maxhp = 50, motion = C.MOTION_STAND, isMonster = true, etype = 1042 })
world.actors = { OWNER, HOMUN, MOB }
world.ent[HOMUN].hp = 40   -- 40% < AggroHP(60)
do
	local b, tr = newRuntime()
	step(b, tr)
	eq(b.target, nil, "E: não adquire alvo com HP baixo (AggroHP)")
end

-- F) fuga quando FleeHP ativo, HP baixo e sob ataque
resetWorld()
setEnt(MOB, { x = 21, y = 20, hp = 50, maxhp = 50, motion = C.MOTION_STAND, isMonster = true, etype = 1042, target = HOMUN })
world.actors = { OWNER, HOMUN, MOB }
world.ent[HOMUN].hp = 20
do
	local b, tr = newRuntime()
	b.config.FleeHP = 50
	step(b, tr)
	eq(b.intent and b.intent.reason, "flee", "F: foge sob ataque com HP baixo")
end

-- G) comando do dono: atacar alvo específico
resetWorld()
setEnt(MOB, { x = 30, y = 30, hp = 50, maxhp = 50, motion = C.MOTION_STAND, isMonster = true, etype = 1042 })
world.actors = { OWNER, HOMUN, MOB }
world.msg = { C.ATTACK_OBJECT_CMD, MOB }
do
	local b, tr = newRuntime()
	step(b, tr)
	eq(b.intent and b.intent.kind, "attack", "G: comando de ataque vira intenção de atacar")
	eq(b.target, MOB, "G: alvo do comando aplicado")
end

----------------------------------------------------------------------
print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
