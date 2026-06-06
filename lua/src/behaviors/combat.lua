-- combat.lua — ações de aquisição, perseguição e ataque.
-- Ações são PURAS: escrevem bb:setIntent(...) e devolvem status. Nada de efeito direto.
BRAI = BRAI or {}

local reg = BRAI.registry
local S = BRAI.status
local util = BRAI.util

-- Pontuação de um candidato a alvo conforme a prioridade 'by' (maior = melhor).
local function candidateScore(bb, m, by)
	if by == "lowestHp" then return -(m.hpPct or 100) end
	if by == "ownerAttacker" then
		local atkOwner = (bb.owner.exists and m.target == bb.owner.id) and 1000 or 0
		return atkOwner - m.dist
	end
	return -m.dist   -- "nearest" (padrão): mais próximo
end

-- Melhor candidato dentro de AggroDist, respeitando KS e inalcançáveis.
local function bestCandidate(bb, by)
	local ks = bb.config.KSMode or "polite"
	local best, bestScore = nil, nil
	for _, m in ipairs(bb.monsters) do
		local blockedByKs = (ks ~= "always") and m.claimed
		if not blockedByKs and not bb:isUnreachable(m.id) and m.dist <= bb.config.AggroDist then
			local sc = candidateScore(bb, m, by)
			if not bestScore or sc > bestScore then best, bestScore = m, sc end
		end
	end
	return best, bestScore
end

-- Seleciona o alvo por prioridade (by: nearest | lowestHp | ownerAttacker). Respeita KSMode.
reg.action("AcquireTarget", function(bb, p)
	local by = (p and p.by) or "nearest"
	local best = bestCandidate(bb, by)
	if best then
		bb.target = best.id
		bb.targetInfo = best
		return S.SUCCESS
	end
	return S.FAILURE
end, { desc = "Seleciona o alvo por prioridade (nearest|lowestHp|ownerAttacker), respeita KSMode.", params = { by = "string" } })

-- Oportunista: mantém o alvo atual, trocando por um melhor se surgir.
reg.action("ReacquireIfBetter", function(bb, p)
	if not bb.targetInfo then return S.FAILURE end   -- sem alvo: deixa o AcquireTarget agir
	local by = (p and p.by) or "nearest"
	local best, bestScore = bestCandidate(bb, by)
	if best and best.id ~= bb.target then
		if bestScore > candidateScore(bb, bb.targetInfo, by) then   -- só troca se for estritamente melhor
			bb.target = best.id
			bb.targetInfo = best
		end
	end
	return S.SUCCESS
end, { desc = "Mantém o alvo atual; troca por um melhor se aparecer (oportunista). by: nearest|lowestHp|ownerAttacker.", params = { by = "string" } })

-- Resgate do dono: mira no monstro que está atacando o dono (ignora KS, é nosso dono).
reg.action("AcquireOwnerAttacker", function(bb)
	if not bb.owner.exists then return S.FAILURE end
	local best, bestDist = nil, nil
	for _, m in ipairs(bb.monsters) do
		if m.target == bb.owner.id and not bb:isUnreachable(m.id) then
			if not bestDist or m.dist < bestDist then best, bestDist = m, m.dist end
		end
	end
	if best then
		bb.target = best.id
		bb.targetInfo = best
		return S.SUCCESS
	end
	return S.FAILURE
end, { desc = "Mira no monstro que está atacando o dono (resgate)." })

-- Persegue o alvo até o alcance de ataque. RUNNING enquanto se aproxima.
-- 'giveUp' (ticks sem progresso) > 0: desiste e marca o alvo como inalcançável.
reg.action("ChaseTarget", function(bb, p)
	local t = bb.targetInfo
	if not t then return S.FAILURE end
	p = p or {}
	-- aceita só números; qualquer outra coisa (vazio/NaN/nil) vira "não informado"
	local function num(v) return (type(v) == "number") and v or nil end
	local reach = num(p.dist) or BRAI.effectiveRange(bb)
	if reach < 1 then reach = 1 end
	if t.dist <= reach then
		bb.persist.chase = nil
		return S.SUCCESS
	end
	-- desistência por falta de progresso (OPCIONAL): só age se giveUp for número > 0;
	-- vazio = nunca desiste, apenas se aproxima até 'dist'.
	local giveUp = num(p.giveUp) or 0
	if giveUp > 0 then
		local cs = bb.persist.chase
		if cs and cs.id == t.id then
			if t.dist < cs.lastDist then cs.lastDist = t.dist; cs.stuck = 0
			else cs.stuck = cs.stuck + 1 end
			if cs.stuck >= giveUp then
				bb:markUnreachable(t.id)
				bb.target = nil; bb.targetInfo = nil; bb.persist.chase = nil
				return S.FAILURE
			end
		else
			bb.persist.chase = { id = t.id, lastDist = t.dist, stuck = 0 }
		end
	end
	local cx, cy
	if reach <= 1 then
		cx, cy = util.cellNextTo(bb.self.x, bb.self.y, t.x, t.y)
	else
		cx, cy = util.stepToward(bb.self.x, bb.self.y, t.x, t.y)
	end
	bb:setIntent("move", { x = cx, y = cy, reason = "chase", target = t.id })
	return S.RUNNING
end, { desc = "Persegue até a distância 'dist' (vazio = alcance do perfil). 'giveUp' é opcional: vazio = nunca desiste; número > 0 = desiste após N ticks sem progresso (marca inalcançável).", params = { dist = "number", giveUp = "number" }, optional = { "dist", "giveUp" } })

-- Dance attack: ataca o alvo enquanto reposiciona (alterna golpe e passo lateral).
reg.action("DanceAttack", function(bb, p)
	local t = bb.targetInfo
	if not t then return S.FAILURE end
	if t.dist > bb.config.AttackRange then return S.FAILURE end   -- fora do alcance: deixa perseguir
	bb.persist.dance = not bb.persist.dance
	if bb.persist.dance then
		bb:setIntent("attack", { target = t.id })
	else
		local ox, oy
		if bb.owner.exists then ox, oy = bb.owner.x, bb.owner.y end
		local cx, cy = util.sidestep(bb.self.x, bb.self.y, t.x, t.y, ox, oy)
		bb:setIntent("move", { x = cx, y = cy, reason = "dance", target = t.id })
	end
	return S.RUNNING
end, { desc = "Ataca o alvo enquanto reposiciona (dança): alterna golpe e passo lateral perto do alvo." })

-- Kiting: afasta-se do alvo para manter distância, sem ultrapassar o limite do dono.
reg.action("Kite", function(bb, p)
	local t = bb.targetInfo
	if not t then return S.FAILURE end
	local keep = (p and p.dist) or 5
	if t.dist >= keep then return S.FAILURE end           -- já está longe o bastante
	local step = (p and p.step) or 2
	local bounds = (p and p.bounds) or bb.config.MoveBounds
	local cx, cy = util.awayFrom(bb.self.x, bb.self.y, t.x, t.y, step)
	if bb.owner.exists and util.chebyshev(cx, cy, bb.owner.x, bb.owner.y) > bounds then
		return S.FAILURE                                   -- não foge além do limite do dono
	end
	bb:setIntent("move", { x = cx, y = cy, reason = "kite", target = t.id })
	return S.RUNNING
end, { desc = "Afasta-se do alvo p/ manter a distância 'dist' (kiting), respeitando 'bounds' do dono.", params = { dist = "number", step = "number", bounds = "number" } })

-- Ataca o alvo atual. RUNNING enquanto o alvo existir.
reg.action("AttackTarget", function(bb)
	local t = bb.targetInfo
	if not t then return S.FAILURE end
	if t.dist > bb.config.AttackRange then return S.FAILURE end
	bb:setIntent("attack", { target = t.id })
	return S.RUNNING
end, { desc = "Ataque normal no alvo atual." })

return true
