-- tree.lua — constrói a árvore executável a partir de uma SPEC (tabela = JSON).
-- Mesma spec que o editor gera e o simulador consome. No cliente, a spec é
-- gerada por tools/build_tree.js (JSON -> tabela Lua) e carregada via dofile.
BRAI = BRAI or {}

local bt = BRAI.bt

local build  -- forward decl

local function buildChildren(specs)
	local out = {}
	for i, c in ipairs(specs or {}) do out[i] = build(c) end
	return out
end

build = function(spec)
	local t = spec.type
	if t == "selector" then
		return bt.selector(buildChildren(spec.children), spec.label)
	elseif t == "sequence" then
		return bt.sequence(buildChildren(spec.children), spec.label)
	elseif t == "parallel" then
		return bt.parallel(buildChildren(spec.children), spec.policy, spec.label)
	elseif t == "inverter" then
		return bt.inverter(build(spec.child), spec.label)
	elseif t == "succeeder" then
		return bt.succeeder(build(spec.child), spec.label)
	elseif t == "cooldown" then
		return bt.cooldown(spec.ms, build(spec.child), spec.label)
	elseif t == "limiter" then
		return bt.limiter(spec.max, build(spec.child), spec.key, spec.label)
	elseif t == "check" then
		return bt.check(spec.name, spec.params, spec.child and build(spec.child) or nil, spec.label)
	elseif t == "monsterCheck" then
		return bt.monsterCheck(spec.monster, spec.group, spec.negate, spec.child and build(spec.child) or nil, spec.label)
	elseif t == "condition" then
		return bt.conditionNode(spec.name, spec.params)
	elseif t == "action" then
		return bt.actionNode(spec.name, spec.params)
	else
		error("tree: tipo de nó desconhecido '" .. tostring(t) .. "'")
	end
end

local tree = {}
tree.build = build

-- Visita a árvore aplicando fn(node, depth) — usado p/ snapshot de depuração.
function tree.walk(node, fn, depth)
	depth = depth or 0
	fn(node, depth)
	for _, ch in ipairs(node.children or {}) do
		tree.walk(ch, fn, depth + 1)
	end
end

-- Snapshot do último status de cada nó (para o painel ao vivo do simulador).
function tree.snapshot(node)
	local out = {}
	tree.walk(node, function(n, depth)
		BRAI.compat.push(out, { label = n.label, kind = n.kind, status = n.lastStatus, depth = depth })
	end)
	return out
end

BRAI.tree = tree
return tree
