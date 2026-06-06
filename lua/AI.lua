-- AI.lua — ponto de entrada no cliente do RO (shell fino).
-- Carrega a BT, liga o backend nativo e define AI(myid).
-- No cliente, este arquivo é o que o RO carrega; ajuste BRAI_BASE se a pasta mudar.

BRAI_BASE = BRAI_BASE or "./AI/USER_AI/brai/lua"

local load = dofile(BRAI_BASE .. "/bootstrap.lua")
local BRAI = load(BRAI_BASE)

local C = BRAI.const
local ro = BRAI.ro

-- No jogo usamos o backend nativo (globais GetV/Move/...).
ro.bind(ro.nativeBackend)

local bb = BRAI.Blackboard.new()

-- Aplica a config do usuário gerada pelo editor (src/config.lua), se existir.
-- Define, por exemplo, BaseHomunType (a forma base do Homunculus S).
pcall(function()
	local uc = dofile(BRAI_BASE .. "/src/config.lua")
	if type(uc) == "table" then
		for k, v in pairs(uc) do bb.config[k] = v end
	end
end)

-- Carrega o catálogo de monstros/grupos gerado pelo editor (src/monsters.lua),
-- usado pelos nós "monsterCheck" da árvore. Opcional: sem ele, esses nós não casam.
pcall(function()
	dofile(BRAI_BASE .. "/src/monsters.lua")
end)

-- Carrega a escolha de skills por homúnculo gerada pelo editor (src/skill_choice.lua),
-- usada pelas ações automáticas (UseAoESkill, UseOffensiveBuff, ...). Opcional.
pcall(function()
	dofile(BRAI_BASE .. "/src/skill_choice.lua")
end)

-- Carrega a config de invocacoes por homunculo (src/summon_choice.lua). Opcional.
pcall(function()
	dofile(BRAI_BASE .. "/src/summon_choice.lua")
end)

local tree = BRAI.tree.build(BRAI.treeSpec)

-- Lê um comando do dono (se houver) para bb.command.
local function readCommand(myid)
	local msg = ro.getMsg(myid)
	if not msg or msg[1] == nil or msg[1] == C.NONE_CMD then
		bb.command = nil
		return
	end
	local k = msg[1]
	if k == C.MOVE_CMD then
		bb.command = { kind = k, x = msg[2], y = msg[3] }
	elseif k == C.ATTACK_OBJECT_CMD then
		bb.command = { kind = k, target = msg[2] }
	elseif k == C.SKILL_OBJECT_CMD then
		bb.command = { kind = k, skill = msg[2], level = msg[3], target = msg[4] }
	else
		bb.command = { kind = k }
	end
end

-- Aplica a intenção decidida pela árvore (única camada que causa efeitos).
local function applyIntent(myid)
	local it = bb.intent
	if not it then return end
	if it.kind == "move" then
		ro.move(myid, it.x, it.y)
	elseif it.kind == "attack" then
		ro.attack(myid, it.target)
		BRAI.skillsys.noteAttack(bb)
	elseif it.kind == "skill" then
		if it.mode == 2 and it.x then
			ro.skillGround(myid, it.level, it.skill, it.x, it.y)   -- skill no solo (AoE/posicional)
		else
			ro.skillObject(myid, it.level, it.skill, it.target)    -- alvo único / self / buff
		end
		BRAI.skillsys.markUsed(bb, it.skill, it.level or 1)        -- cooldown/buff só ao aplicar
	end
	-- "idle": nada
end

-- Chamada pelo cliente a cada ciclo de IA.
function AI(myid)
	readCommand(myid)
	BRAI.perception.update(bb, myid)
	tree:tick(bb)
	applyIntent(myid)
end

-- expõe p/ depuração externa
BRAI.runtime = { bb = bb, tree = tree }
return BRAI
