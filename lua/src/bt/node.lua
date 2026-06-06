-- node.lua — base de nós da árvore + folhas (condição/ação) via registry.
-- Estilo portável (5.0+): nós são tabelas com método :tick(bb).
-- Cada nó grava self.lastStatus para o painel de depuração do simulador.
BRAI = BRAI or {}
BRAI.bt = BRAI.bt or {}

local S = BRAI.status
local bt = BRAI.bt

-- Cria um nó base. `tickfn(self, bb)` deve devolver um status.
function bt.node(kind, label, tickfn)
	local n = {
		kind = kind,
		label = label or kind,
		children = {},
		lastStatus = nil,
	}
	n.tick = function(self, bb)
		local st = tickfn(self, bb)
		self.lastStatus = st
		return st
	end
	return n
end

-- Folha de CONDIÇÃO: resolve registry.conditions[name](bb, params) -> bool.
function bt.conditionNode(name, params)
	local n = bt.node("condition", "?" .. name, function(self, bb)
		local fn = BRAI.registry.conditions[name]
		if not fn then
			BRAI.ro.trace("BT: condição desconhecida '" .. tostring(name) .. "'")
			return S.FAILURE
		end
		if fn(bb, self.params) then return S.SUCCESS end
		return S.FAILURE
	end)
	n.name = name
	n.params = params or {}
	return n
end

-- Folha de AÇÃO: resolve registry.actions[name](bb, params) -> status.
function bt.actionNode(name, params)
	local n = bt.node("action", "!" .. name, function(self, bb)
		local fn = BRAI.registry.actions[name]
		if not fn then
			BRAI.ro.trace("BT: ação desconhecida '" .. tostring(name) .. "'")
			return S.FAILURE
		end
		return fn(bb, self.params)
	end)
	n.name = name
	n.params = params or {}
	return n
end

return bt
