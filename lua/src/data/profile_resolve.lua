-- profile_resolve.lua — perfil EFETIVO do homunculo (S + tipo base mesclados).
-- Equivale ao OldHomunType do AzzyAI: o cliente informa a forma S (Dieter), mas a
-- forma base (Vanilmirth/Amistr/...) precisa ser escolhida; o S mantem as skills da base.
-- Normaliza tambem a cura em healOwnerSkill/healSelfSkill.
BRAI = BRAI or {}

local function concat(a, b)
	local out = {}
	if a then for _, v in ipairs(a) do out[#out + 1] = v end end
	if b then for _, v in ipairs(b) do out[#out + 1] = v end end
	return out
end

local function healOf(p)
	local ho, hs
	if p.heal then
		if p.healOwner then ho = p.heal end
		if p.healSelf then hs = p.heal end
	end
	return ho, hs
end

-- Perfil efetivo conforme bb.self.homunType + bb.config.BaseHomunType.
function BRAI.profileFor(bb)
	local sType = bb.self.homunType
	local sp = BRAI.getProfile(sType)
	local base = bb.config.BaseHomunType
	local bp = nil
	if base and base ~= 0 and base ~= sType then bp = BRAI.getProfile(base) end

	local m = {}
	m.mainAtk     = sp.mainAtk     or (bp and bp.mainAtk)
	m.aoeAtk      = sp.aoeAtk      or (bp and bp.aoeAtk)
	m.offBuff     = concat(sp.offBuff, bp and bp.offBuff)
	m.defBuff     = concat(sp.defBuff, bp and bp.defBuff)
	m.ownerBuff   = sp.ownerBuff   or (bp and bp.ownerBuff)
	m.summon      = sp.summon      or (bp and bp.summon)
	m.combo       = sp.combo       or (bp and bp.combo)
	m.styleChange = sp.styleChange or (bp and bp.styleChange)
	m.debuffAoE   = sp.debuffAoE   or (bp and bp.debuffAoE)
	m.castling    = sp.castling    or (bp and bp.castling)

	local sho, shs = healOf(sp)
	local bho, bhs
	if bp then bho, bhs = healOf(bp) end
	m.healOwnerSkill = sho or bho
	m.healSelfSkill  = shs or bhs

	m.baseType = base
	if BRAI.applySkillChoice then BRAI.applySkillChoice(sType, m) end
	return m
end

-- Tipos que sao Homunculus S (precisam de BaseHomunType para skills da base).
function BRAI.isHomunS(t)
	local C = BRAI.const
	return t == C.EIRA or t == C.BAYERI or t == C.SERA or t == C.DIETER or t == C.ELEANOR
end

return true
