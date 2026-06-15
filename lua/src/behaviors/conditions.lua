-- conditions.lua — folhas de condição (predicados puros sobre o blackboard).
BRAI = BRAI or {}

local reg = BRAI.registry
local P = BRAI.perception

reg.condition("HasOwnerCommand", function(bb)
	return bb.command ~= nil and bb.command.kind ~= nil
end, { desc = "Há comando do dono pendente neste tick." })

reg.condition("HpBelow", function(bb, p)
	return bb.self.hpPct < (p.pct or 0)
end, { desc = "HP% do homúnculo abaixo de pct.", params = { pct = "number" } })

reg.condition("HpAbove", function(bb, p)
	return bb.self.hpPct >= (p.pct or 0)
end, { desc = "HP% do homúnculo >= pct.", params = { pct = "number" } })

reg.condition("SpAbove", function(bb, p)
	return bb.self.spPct >= (p.pct or 0)
end, { desc = "SP% do homúnculo >= pct.", params = { pct = "number" } })

reg.condition("BeingAttacked", function(bb)
	return P.selfUnderAttack(bb)
end, { desc = "Algum monstro mira no homúnculo." })

reg.condition("OwnerUnderAttack", function(bb, p)
	if not bb.owner.exists then return false end
	local need = (p and p.count) or 1
	return P.aggroCount(bb, bb.owner.id) >= need
end, { desc = "O dono está sendo atacado por PELO MENOS 'count' monstros (padrão 1 = qualquer um).", params = { count = "number" }, optional = { "count" } })

-- Contraparte da OwnerUnderAttack, mas para o HOMÚNCULO. Padrão 1. NÃO liga o modo
-- berserk (diferente de Mobbed) — é só a contagem pura de agressores no homúnculo.
reg.condition("SelfUnderAttack", function(bb, p)
	local need = (p and p.count) or 1
	return P.aggroCount(bb, bb.self.id) >= need
end, { desc = "O homúnculo está sendo atacado por PELO MENOS 'count' monstros (padrão 1). Não liga o berserk (≠ Mobbed).", params = { count = "number" }, optional = { "count" } })

reg.condition("HasValidTarget", function(bb)
	return bb.target ~= nil and bb.targetInfo ~= nil and not bb:isUnreachable(bb.target)
end, { desc = "Existe alvo válido (em vista, vivo, alcançável)." })

reg.condition("InAttackRange", function(bb)
	if not bb.targetInfo then return false end
	return bb.targetInfo.dist <= bb.config.AttackRange
end, { desc = "Alvo atual dentro do alcance de ataque normal." })

reg.condition("TooFarFromOwner", function(bb, p)
	if not bb.owner.exists then return false end
	return bb.owner.dist > (p.dist or bb.config.MoveBounds)
end, { desc = "Distância do dono acima do limite.", params = { dist = "number" } })

reg.condition("CanEngage", function(bb)
	if bb.config.SuperPassive then return false end
	if bb.flags.standby then return false end
	if bb.self.hpPct < bb.config.AggroHP then return false end
	if bb.self.spPct < bb.config.AggroSP then return false end
	return true
end, { desc = "Condições gerais p/ buscar alvo (HP/SP/superpassive/standby)." })

reg.condition("ShouldFlee", function(bb)
	if bb.config.FleeHP <= 0 then return false end
	if bb.self.hpPct >= bb.config.FleeHP then return false end
	return BRAI.perception.selfUnderAttack(bb)
end, { desc = "HP abaixo de FleeHP e sob ataque." })

-- HP% do DONO (a percepção já calcula bb.owner.hpPct = 100*HP/MaxHP, como na AzzyAI)
reg.condition("OwnerHpBelow", function(bb, p)
	if not bb.owner.exists or bb.owner.hpPct == nil then return false end
	return bb.owner.hpPct < (p.pct or 0)
end, { desc = "HP% do dono abaixo de pct (ex.: curar o dono).", params = { pct = "number" } })

reg.condition("OwnerHpAbove", function(bb, p)
	if not bb.owner.exists or bb.owner.hpPct == nil then return false end
	return bb.owner.hpPct >= (p.pct or 0)
end, { desc = "HP% do dono >= pct.", params = { pct = "number" } })

-- Berserk: muitos monstros atacando o homúnculo (gatilho p/ um ramo agressivo).
reg.condition("Mobbed", function(bb, p)
	local n = P.aggroCount(bb, bb.self.id)
	local mob = n >= (p.count or 3)
	if mob then bb.flags.berserk = true end   -- marca p/ exibir no simulador
	return mob
end, { desc = "Pelo menos 'count' monstros atacando o homúnculo (modo berserk).", params = { count = "number" } })

-- Estilo atual do Homunculus S (Eleanor): "power" (Combate) ou "grapple" (Agarrão).
reg.condition("StyleIs", function(bb, p)
	return (bb.persist.style or "power") == ((p and p.style) or "power")
end, { desc = "O estilo atual (Eleanor) é o pedido. style: power|grapple.", params = { style = "string" } })

-- Seguro p/ Agarrão (Eleanor): nº de monstros no raio <= limite. Tinder Breaker zera o
-- Flee — em multidão vira armadilha mortal; esta condição guarda a entrada no Agarrão.
reg.condition("SafeToGrapple", function(bb, p)
	local radius = (p and p.radius) or 3
	local limit  = (p and p.limit) or bb.config.GrappleThreatLimit or 1
	return BRAI.perception.threatCount(bb, radius) <= limit
end, { desc = "Seguro p/ Agarrão: monstros no raio <= limite (Flee=0 vira armadilha em multidão).", params = { radius = "number", limit = "number" } })

-- O alvo atual é Boss/MVP? (flag de percepção OU grupo de boss do catálogo, config.BossGroup)
-- Útil p/ evitar skills proibidas em boss (ex.: E.Q.C. da Eleanor) ou mudar de tática.
reg.condition("TargetIsBoss", function(bb)
	return BRAI.perception.targetIsBoss(bb)
end, { desc = "O monstro alvo é Boss/MVP (flag de percepção ou grupo BossGroup do catálogo)." })

-- ===== Legião invocada (Sera) — condições sobre o estimador (bb.self.legion) =====
reg.condition("LegionActive", function(bb)
	local lg = bb.self.legion
	return lg ~= nil and lg.alive == true
end, { desc = "A Legião invocada (Sera) está ativa (vista ou dentro da janela de duração)." })

reg.condition("LegionBelow", function(bb, p)
	local lg = bb.self.legion
	return ((lg and lg.count) or 0) < ((p and p.count) or 1)
end, { desc = "Menos de 'count' insetos vivos na Legião (gatilho de reforço).", params = { count = "number" } })

reg.condition("LegionExpiring", function(bb, p)
	local lg = bb.self.legion
	if not (lg and lg.alive) then return false end
	return (lg.expiresAt - bb:now()) < ((p and p.ms) or 3000)
end, { desc = "A janela da Legião expira em menos de 'ms' (re-summon antecipado).", params = { ms = "number" } })


-- "Possui a skill X": o homúnculo APRENDEU a skill (em jogo o cliente responde via GetV; no
-- simulador, o stub decide pelo lvl do homún). Use o `inverter` p/ "NÃO possui". Param: skill.
reg.condition("HasSkill", function(bb, p)
	return BRAI.skillsys.learned(bb, p and p.skill)
end, { desc = "O homúnculo já aprendeu a skill escolhida (negue com 'inverter' p/ 'NÃO possui').", params = { skill = "skill" } })


return true
