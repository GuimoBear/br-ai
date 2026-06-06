-- sim_test.lua — testa o runtime do simulador (o MESMO codigo que o Electron roda).
-- Uso: texlua tools/sim_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json = BRAI.json

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end

local function dispatch(method, obj)
	local s = SIM_DISPATCH(method, obj and json.encode(obj) or "")
	return json.decode(s)
end

local function findEnt(snap, id)
	for _, e in ipairs(snap.entities) do if e.id == id then return e end end
end

-- Cenario: dono parado, homun longe, um monstro perto do homun.
local scenario = {
	grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
	entities = {
		{ id = 1,   kind = "owner",   x = 10, y = 10, hp = 1000, maxhp = 1000 },
		{ id = 100, kind = "homun",   x = 20, y = 20, hp = 100,  maxhp = 100, sp = 100, maxsp = 100 },
		{ id = 200, kind = "monster", x = 23, y = 23, hp = 40,   maxhp = 40, atk = 5, aggro = 8, etype = 1042 },
	},
}

print("== runtime do simulador ==")
local snap = dispatch("load", scenario)
check(snap.tick == 0, "load: tick inicial 0")
check(findEnt(snap, 100) ~= nil, "load: homunculo presente no snapshot")
check(snap.tree and #snap.tree > 0, "load: snapshot da arvore tem nos")
check(snap.bb and snap.bb.self and snap.bb.self.hpPct == 100, "load: bloco bb populado (hpPct 100)")
check(snap.bb.owner and snap.bb.owner.dist ~= nil, "load: bb tem distancia do dono")

-- Passo 1: deve adquirir o monstro (esta a dist 3 <= AggroDist)
snap = dispatch("step")
check(snap.target == 200, "step1: alvo adquirido (200)")

-- Roda varios passos: homun deve perseguir, atacar e matar o monstro
local killedAt = nil
for i = 2, 60 do
	snap = dispatch("step")
	local mob = findEnt(snap, 200)
	if mob and mob.hp <= 0 and not killedAt then killedAt = i end
end
check(killedAt ~= nil, "monstro foi morto pela IA (em <=60 ticks)")

-- Algum no da arvore deve ter status (depuracao viva)
local hasStatus = false
for _, n in ipairs(snap.tree) do if n.status ~= nil then hasStatus = true end end
check(hasStatus, "snapshot da arvore traz status dos nos")

-- Comando do dono: mover homun para uma posicao
snap = dispatch("load", scenario)
snap = dispatch("command", { cmd = BRAI.const.MOVE_CMD, a = 25, b = 25 })
local hx0 = findEnt(snap, 100).x
snap = dispatch("step")
local hbb = findEnt(snap, 100)
check(snap.intent ~= nil and snap.intent.kind == "move", "comando: intencao de mover")

-- Snapshot puro nao avanca o tick
local t1 = dispatch("snapshot").tick
local t2 = dispatch("snapshot").tick
check(t1 == t2, "snapshot nao avanca o tick")

-- registry exportado para o editor
local meta = dispatch("registry")
check(meta["HpBelow"] and meta["HpBelow"].kind == "condition", "registry: HpBelow e condicao")
check(meta["AcquireTarget"] and meta["AcquireTarget"].kind == "action", "registry: AcquireTarget e acao")

-- treeSpec exportado
local spec = dispatch("treeSpec")
check(spec and spec.type == "selector", "treeSpec: raiz e selector")

-- setTree injeta arvore custom (so Idle) no simulador
dispatch("load", scenario)
dispatch("setTree", { type = "action", name = "Idle" })
snap = dispatch("step")
check(snap.intent and snap.intent.kind == "idle", "setTree: arvore custom (Idle) aplicada")
dispatch("clearTree")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
