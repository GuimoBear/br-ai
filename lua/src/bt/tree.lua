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
	local n
	if t == "selector" then
		n = bt.selector(buildChildren(spec.children), spec.label)
	elseif t == "sequence" then
		n = bt.sequence(buildChildren(spec.children), spec.label)
	elseif t == "parallel" then
		n = bt.parallel(buildChildren(spec.children), spec.policy, spec.label)
	elseif t == "inverter" then
		n = bt.inverter(build(spec.child), spec.label)
	elseif t == "succeeder" then
		n = bt.succeeder(build(spec.child), spec.label)
	elseif t == "cooldown" then
		n = bt.cooldown(spec.ms, build(spec.child), spec.label)
	elseif t == "limiter" then
		n = bt.limiter(spec.max, build(spec.child), spec.key, spec.label)
	elseif t == "check" then
		n = bt.check(spec.name, spec.params, spec.child and build(spec.child) or nil, spec.label)
	elseif t == "monsterCheck" then
		n = bt.monsterCheck(spec.monster, spec.group, spec.negate, spec.child and build(spec.child) or nil, spec.label)
	elseif t == "condition" then
		n = bt.conditionNode(spec.name, spec.params)
	elseif t == "action" then
		n = bt.actionNode(spec.name, spec.params)
	else
		error("tree: tipo de nó desconhecido '" .. tostring(t) .. "'")
	end
	-- "desativado": o nó (e, por consequência, seus filhos) não é executado.
	if spec.disabled then n.disabled = true end
	return n
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

-- Rótulo LEGÍVEL p/ exibição (editor + simulador): título PT do registry p/ folhas
-- (ação/condição/check) e nome PT do tipo p/ compostos/decoradores. O rótulo do usuário
-- (≠ default) tem precedência. O CÓDIGO original vai à parte (campo `name`) p/ a dica.
local KIND_PT = {
	selector = "Seletor", sequence = "Sequência", parallel = "Paralelo",
	inverter = "Inverter", succeeder = "Sucesso", cooldown = "Recarga",
	limiter = "Limitador", monsterCheck = "Monstro",
}
local function displayLabel(n)
	if n.name then   -- folha/check: respeita rótulo do usuário, senão usa o título legível
		if n.label and n.label ~= ("?" .. n.name) and n.label ~= ("!" .. n.name) then return n.label end
		local m = BRAI.registry and BRAI.registry.meta and BRAI.registry.meta[n.name]
		if m and m.title and m.title ~= "" then return m.title end
		return n.name
	end
	-- composto/decorador: usa o rótulo do usuário se houver; senão o nome PT do tipo.
	-- Os DEFAULTS do motor ("selector", "parallel:all", "cooldown:1000", "limiter:3", "alvo?")
	-- NÃO contam como rótulo do usuário — caem no nome PT do tipo.
	local lbl = n.label
	if lbl and lbl ~= n.kind and lbl:sub(1, #n.kind + 1) ~= (n.kind .. ":") and lbl ~= "alvo?" then
		return lbl
	end
	return KIND_PT[n.kind] or lbl or n.kind
end

-- Rótulo "<skill> Lv<n>" de uma skill efetiva (n>0 usa o nível; senão o máximo).
local function skillRefLabel(s)
	local lv = (s.level and s.level > 0) and s.level or s.maxLevel or "?"
	return (s.name or ("#" .. tostring(s.id))) .. " Lv" .. tostring(lv)
end

-- Snapshot do último status de cada nó (para o painel ao vivo do simulador).
-- `disabled` = flag própria do nó; `off` = desativado EFETIVO (próprio ou herdado
-- de um ancestral desativado), usado para pintar o nó e toda a subárvore.
-- Com `bb` (opcional), anexa FILHOS SINTÉTICOS de skill (kind="skillRef") logo após cada
-- ação automática de skill — só display; não afetam a BT nem o pacote (que vêm do JSON).
-- O nó-ação recebe `skillState` (ok|none|missing) p/ o destaque sutil no simulador.
function tree.snapshot(node, bb)
	local out = {}
	local offFromDepth = nil
	-- roleConfig do homún do contexto, computado UMA vez (reuso por nó-ação); só com bb.
	local rc = nil
	if bb and bb.self and BRAI.roleConfig then rc = BRAI.roleConfig(bb.self.homunType) end
	tree.walk(node, function(n, depth)
		if offFromDepth ~= nil and depth <= offFromDepth then offFromDepth = nil end
		local off = (offFromDepth ~= nil)
		if n.disabled then
			off = true
			if offFromDepth == nil then offFromDepth = depth end
		end
		local entry = {
			label = displayLabel(n), name = n.name, kind = n.kind, status = n.lastStatus, depth = depth,
			disabled = n.disabled and true or false, off = off,
		}
		BRAI.compat.push(out, entry)
		-- filhos sintéticos de skill p/ as ações automáticas (UseAoESkill/UseHealOwner/...)
		if bb and n.kind == "action" and n.name and BRAI.actionRole and BRAI.actionRole[n.name] and BRAI.actionSkills then
			local as = BRAI.actionSkills(bb, n.name, rc)
			if as then
				entry.skillState = as.state
				if as.state == "ok" then
					for _, sk in ipairs(as.skills) do
						BRAI.compat.push(out, {
							label = skillRefLabel(sk), kind = "skillRef", depth = depth + 1, off = off,
							skillId = sk.id, active = (as.activeId == sk.id) and true or false,
						})
					end
				else
					local msg = (as.state == "none") and "— nenhuma skill selecionada"
						or "— este tipo não tem esta skill"
					BRAI.compat.push(out, {
						label = msg, kind = "skillRef", depth = depth + 1, off = off, skillState = as.state,
					})
				end
			end
		end
	end)
	return out
end

BRAI.tree = tree
return tree
