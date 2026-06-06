-- monstercheck_test.lua — testa o nó monsterCheck + catálogo de monstros/grupos,
-- ponta a ponta pelo SIM_DISPATCH (o MESMO caminho que o Electron usa).
-- Uso: texlua tools/monstercheck_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json = BRAI.json

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function dispatch(method, obj)
	return json.decode(SIM_DISPATCH(method, obj and json.encode(obj) or ""))
end

-- catálogo: Poring(1002), Osiris(1038), Baphomet(1039); grupo "Chefes" = {1038,1039}
local catalog = {
	monsters = { {id=1002,desc="Poring"}, {id=1038,desc="Osiris"}, {id=1039,desc="Baphomet"} },
	groups   = { {id=1,name="Chefes",members={1038,1039}} },
}

-- árvore de teste: se alvo está no grupo "Chefes" → ataca; senão idle.
-- (usamos AcquireTarget p/ travar no monstro presente)
local function treeWith(monster, group, negate)
	return { type="sequence", children={
		{ type="action", name="AcquireTarget", params={ by="nearest" } },
		{ type="monsterCheck", monster=monster, group=group, negate=negate,
		  child={ type="action", name="AttackTarget" } },
	} }
end

local function scenarioWith(etype)
	return {
		grid={w=40,h=40}, dt=50, homunId=100, ownerId=1,
		config={ AggroDist=20, AggroHP=0, AggroSP=0, AttackRange=1, FollowStayBack=3, MoveBounds=40 },
		entities={
			{ id=1,   kind="owner",   x=20, y=20, hp=1000, maxhp=1000 },
			{ id=100, kind="homun",   x=20, y=20, hp=100, maxhp=100, sp=100, maxsp=100, homunType=4 },
			{ id=200, kind="monster", x=21, y=20, hp=200, maxhp=200, atk=1, aggro=2, aggressive=false, etype=etype },
		},
	}
end

-- roda alguns ticks e devolve a última intenção do homúnculo
local function runIntent(monster, group, negate, etype)
	dispatch("setMonsters", catalog)
	dispatch("setTree", treeWith(monster, group, negate))
	dispatch("load", scenarioWith(etype))
	local snap
	for _=1,6 do snap = dispatch("step") end
	return snap.intent and snap.intent.kind or "idle"
end

print("== monsterCheck (ponta a ponta via SIM_DISPATCH) ==")

-- grupo "Chefes": alvo Osiris(1038) casa → ataca
check(runIntent(0, 1, false, 1038) == "attack", "grupo: alvo membro (Osiris) => ataca")
-- grupo "Chefes": alvo Poring(1002) não casa → não ataca
check(runIntent(0, 1, false, 1002) ~= "attack", "grupo: alvo nao-membro (Poring) => nao ataca")
-- monstro específico Poring(1002): casa → ataca
check(runIntent(1002, 0, false, 1002) == "attack", "monstro especifico (Poring) => ataca")
-- monstro específico Poring: alvo Osiris não casa
check(runIntent(1002, 0, false, 1038) ~= "attack", "monstro especifico: alvo diferente => nao ataca")
-- negado no grupo "Chefes": alvo Poring (não-membro) => ataca
check(runIntent(0, 1, true, 1002) == "attack", "negado: nao-membro (Poring) => ataca")
-- negado no grupo "Chefes": alvo Osiris (membro) => nao ataca
check(runIntent(0, 1, true, 1038) ~= "attack", "negado: membro (Osiris) => nao ataca")

-- etype aparece no snapshot da entidade
do
	dispatch("setMonsters", catalog)
	dispatch("load", scenarioWith(1039))
	local snap = dispatch("snapshot")
	local et
	for _, e in ipairs(snap.entities) do if e.id == 200 then et = e.etype end end
	check(et == 1039, "snapshot expoe etype do monstro (1039)")
end

-- updateMonster troca a classe (etype)
do
	dispatch("updateMonster", { id = 200, etype = 1002 })
	local snap = dispatch("snapshot")
	local et
	for _, e in ipairs(snap.entities) do if e.id == 200 then et = e.etype end end
	check(et == 1002, "updateMonster troca etype (1002)")
end

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
