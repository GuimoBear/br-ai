-- composites.lua — Selector / Sequence / Parallel.
-- Implementação REATIVA e sem estado: a cada tick reavaliamos da esquerda p/ direita.
-- O estado "RUNNING" vive nas folhas de ação (que recomputam do blackboard),
-- então composites não precisam de memória — isso dá reatividade de prioridade,
-- que é o que queremos no RO (sobrevivência preempta combate todo tick).
-- Filhos DESATIVADOS (child.disabled) são PULADOS (como se não existissem) — assim o
-- comportamento bate com o "Gerar Lua", que remove os nós desativados do arquivo final.
BRAI = BRAI or {}
BRAI.bt = BRAI.bt or {}

local S = BRAI.status
local bt = BRAI.bt

-- Selector (OR de prioridade): primeiro SUCCESS/RUNNING vence; falha se todos falham.
function bt.selector(children, label)
	local n = bt.node("selector", label or "selector", function(self, bb)
		for _, child in ipairs(self.children) do
			if not child.disabled then
				local s = child:tick(bb)
				if s == S.SUCCESS then return S.SUCCESS end
				if s == S.RUNNING then return S.RUNNING end
			end
		end
		return S.FAILURE
	end)
	n.children = children or {}
	return n
end

-- Sequence (AND): para no primeiro FAILURE/RUNNING; sucesso se todos passam.
function bt.sequence(children, label)
	local n = bt.node("sequence", label or "sequence", function(self, bb)
		for _, child in ipairs(self.children) do
			if not child.disabled then
				local s = child:tick(bb)
				if s == S.FAILURE then return S.FAILURE end
				if s == S.RUNNING then return S.RUNNING end
			end
		end
		return S.SUCCESS
	end)
	n.children = children or {}
	return n
end

-- Parallel: tica todos. policy = "all" (sucesso só se todos) ou "any" (sucesso se um).
-- RUNNING se ninguém decidiu ainda conforme a política.
function bt.parallel(children, policy, label)
	policy = policy or "all"
	local n = bt.node("parallel", label or ("parallel:" .. policy), function(self, bb)
		local anySuccess, anyFailure, anyRunning = false, false, false
		for _, child in ipairs(self.children) do
			if not child.disabled then
				local s = child:tick(bb)
				if s == S.SUCCESS then anySuccess = true
				elseif s == S.FAILURE then anyFailure = true
				else anyRunning = true end
			end
		end
		if policy == "any" then
			if anySuccess then return S.SUCCESS end
			if anyRunning then return S.RUNNING end
			return S.FAILURE
		else -- "all"
			if anyFailure then return S.FAILURE end
			if anyRunning then return S.RUNNING end
			return S.SUCCESS
		end
	end)
	n.children = children or {}
	return n
end

return bt
