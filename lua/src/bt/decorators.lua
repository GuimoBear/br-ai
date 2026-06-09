-- decorators.lua — Inverter / Succeeder / Cooldown / Limiter / Condition-guard.
-- Cooldown e Limiter guardam estado no próprio nó (1 árvore = 1 agente, então é seguro).
BRAI = BRAI or {}
BRAI.bt = BRAI.bt or {}

local S = BRAI.status
local bt = BRAI.bt

-- Inverter: SUCCESS<->FAILURE; RUNNING passa.
function bt.inverter(child, label)
	local n = bt.node("inverter", label or "inverter", function(self, bb)
		local s = self.child:tick(bb)
		if s == S.SUCCESS then return S.FAILURE end
		if s == S.FAILURE then return S.SUCCESS end
		return S.RUNNING
	end)
	n.child = child
	n.children = { child }
	return n
end

-- Succeeder: vira SUCCESS (exceto RUNNING). Útil p/ tornar um ramo opcional.
function bt.succeeder(child, label)
	local n = bt.node("succeeder", label or "succeeder", function(self, bb)
		local s = self.child:tick(bb)
		if s == S.RUNNING then return S.RUNNING end
		return S.SUCCESS
	end)
	n.child = child
	n.children = { child }
	return n
end

-- Cooldown: bloqueia (FAILURE) enquanto dentro da janela de `ms`.
-- Inicia a janela quando o filho retorna SUCCESS. Espelha AutoSkillDelay/Cooldown.
function bt.cooldown(ms, child, label)
	local n = bt.node("cooldown", label or ("cooldown:" .. tostring(ms)), function(self, bb)
		local now = bb:now()
		if self.readyAt and now < self.readyAt then
			return S.FAILURE
		end
		local s = self.child:tick(bb)
		if s == S.SUCCESS then
			self.readyAt = now + self.ms
		end
		return s
	end)
	n.ms = ms
	n.child = child
	n.children = { child }
	n.readyAt = nil
	return n
end

-- Limiter: permite no máximo `max` SUCCESS do filho; depois falha. Reset por bb:resetCounters().
-- Mapeia TACT_SKILL (n usos) / AutoSkillLimit. `key` permite contadores nomeados no bb.
function bt.limiter(max, child, key, label)
	local n = bt.node("limiter", label or ("limiter:" .. tostring(max)), function(self, bb)
		local used = bb:counter(self.key)
		if used >= self.max then return S.FAILURE end
		local s = self.child:tick(bb)
		if s == S.SUCCESS then bb:incCounter(self.key) end
		return s
	end)
	n.max = max
	n.child = child
	n.children = { child }
	n.key = key or ("limiter@" .. tostring(n))
	return n
end

-- Check: nó condicional com UM filho. Se a condição é verdadeira, executa o filho
-- e devolve o status dele; se falsa, devolve FAILURE. (Sem filho, age como condição.)
-- Substitui o padrão verboso Sequence[condição, ação] por um nó só.
function bt.check(name, params, child, label)
	local n = bt.node("check", label or ("?" .. tostring(name)), function(self, bb)
		local fn = BRAI.registry.conditions[self.name]
		if not fn then
			BRAI.ro.trace("BT: condição desconhecida '" .. tostring(self.name) .. "'")
			return S.FAILURE
		end
		if not fn(bb, self.params) then return S.FAILURE end
		if not self.child or self.child.disabled then return S.SUCCESS end
		return self.child:tick(bb)
	end)
	n.name = name
	n.params = params or {}
	n.child = child
	n.children = child and { child } or {}
	return n
end

-- MonsterCheck: nó condicional por ALVO. Executa o filho só se o monstro alvo
-- (classe = bb.targetInfo.type) for o monstro `monster` OU pertencer ao grupo `group`.
-- `negate` inverte (executa quando NÃO é e NÃO está no grupo).
-- Sem alvo atual → FAILURE sempre (mesmo negado): não há monstro a testar.
-- Consulta o catálogo BRAI.monsterGroups (cadastro de monstros/grupos do usuário).
function bt.monsterCheck(monster, group, negate, child, label)
	local n = bt.node("monsterCheck", label or "alvo?", function(self, bb)
		local ti = bb.targetInfo
		if not ti then return S.FAILURE end          -- sem alvo: nada a testar
		local etype = ti.type
		local matched = BRAI.monsterGroups.matches(self.monster, self.group, etype)
		if self.negate then matched = not matched end
		if not matched then return S.FAILURE end
		if not self.child or self.child.disabled then return S.SUCCESS end
		return self.child:tick(bb)
	end)
	n.monster = monster or 0
	n.group = group or 0
	n.negate = negate and true or false
	n.child = child
	n.children = child and { child } or {}
	return n
end

return bt
