-- monsters.lua — catálogo de monstros e grupos (cadastro do usuário).
-- O nó "monsterCheck" da árvore consulta este módulo para decidir se o monstro
-- alvo (classe = V_TYPE) é um monstro específico ou pertence a um grupo.
--
-- Fonte da verdade = monsters.json (raiz do projeto), editado no editor visual.
--   • No simulador: carregado via SIM_DISPATCH("setMonsters", catalog).
--   • No cliente do RO: gerado como monsters.lua (tools/build_tree.js) e dado dofile por AI.lua.
--
-- Formato do catálogo (mesma forma do JSON):
--   { monsters = { {id=1002, desc="Poring"}, ... },
--     groups   = { {id=1, name="Chefes", members={1038, 1039}}, ... } }
BRAI = BRAI or {}

local MG = {}
MG._groups = {}     -- groupId -> { [etype]=true }  (conjunto p/ busca O(1))
MG._catalog = { monsters = {}, groups = {} }

-- Substitui o catálogo inteiro e reindexa os grupos como conjuntos.
function MG.load(catalog)
	catalog = catalog or {}
	MG._catalog = catalog
	MG._groups = {}
	local groups = catalog.groups or {}
	for _, g in ipairs(groups) do
		if g and g.id ~= nil then
			local set = {}
			for _, etype in ipairs(g.members or {}) do
				set[etype] = true
			end
			MG._groups[g.id] = set
		end
	end
end

function MG.reset()
	MG.load({ monsters = {}, groups = {} })
end

-- O monstro de classe `etype` pertence ao grupo `groupId`?
function MG.contains(groupId, etype)
	if groupId == nil or groupId == 0 or etype == nil then return false end
	local set = MG._groups[groupId]
	return set ~= nil and set[etype] == true
end

-- Casa o alvo (classe `etype`) contra um monstro específico OU um grupo.
-- match = (monster ~= 0 e etype == monster) OU (etype está no grupo).
function MG.matches(monster, groupId, etype)
	if etype == nil then return false end
	if monster ~= nil and monster ~= 0 and etype == monster then return true end
	return MG.contains(groupId, etype)
end

MG.reset()
BRAI.monsterGroups = MG
return MG
