-- profile_resolve.lua — perfil EFETIVO do homunculo (S + tipo base mesclados).
-- Equivale ao OldHomunType do AzzyAI: o cliente informa a forma S (Dieter), mas a
-- forma base (Vanilmirth/Amistr/...) precisa ser escolhida; o S pode reusar as skills da base.
-- O uso da base e OPT-IN: so mescla quando bb.config.UseBaseSkills e verdadeiro (a base
-- nunca e usada se a flag estiver desligada, mesmo com BaseHomunType setado).
-- Regra: o S e PRIORITARIO; a base entra so onde o S nao tem (fallback). offBuff/defBuff
-- NAO somam — fallback estrito (a base so entra se o S nao tiver nenhum buff do tipo).
-- Normaliza tambem a cura em healOwnerSkill/healSelfSkill.
BRAI = BRAI or {}

local function copyList(a)
	local out = {}
	if a then for _, v in ipairs(a) do out[#out + 1] = v end end
	return out
end

-- fallback ESTRITO p/ listas (off/def): usa a lista do S se tiver algo; senao a da base.
local function listFallback(a, b)
	if a and #a > 0 then return copyList(a) end
	if b and #b > 0 then return copyList(b) end
	return {}
end

local function healOf(p)
	local ho, hs
	if p.heal then
		if p.healOwner then ho = p.heal end
		if p.healSelf then hs = p.heal end
	end
	return ho, hs
end

-- Perfil EFETIVO (S + base) conforme a politica de uso da base.
-- sType/baseType: tipos numericos. useBase: liga o uso das skills da base (opt-in).
function BRAI.effectiveProfile(sType, baseType, useBase)
	local sp = BRAI.getProfile(sType)
	local bp = nil
	if useBase and baseType and baseType ~= 0 and baseType ~= sType then bp = BRAI.getProfile(baseType) end

	local m = {}
	m.mainAtk     = sp.mainAtk     or (bp and bp.mainAtk)
	m.aoeAtk      = sp.aoeAtk      or (bp and bp.aoeAtk)
	m.offBuff     = listFallback(sp.offBuff, bp and bp.offBuff)   -- fallback estrito (nao soma)
	m.defBuff     = listFallback(sp.defBuff, bp and bp.defBuff)   -- fallback estrito (nao soma)
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

	m.baseType = baseType
	m.useBase  = (useBase and true) or false
	return m
end

-- Perfil efetivo conforme bb.self.homunType + bb.config (BaseHomunType + UseBaseSkills).
function BRAI.profileFor(bb)
	local sType = bb.self.homunType
	local useBase = (bb.config.UseBaseSkills and true) or false
	local m = BRAI.effectiveProfile(sType, bb.config.BaseHomunType, useBase)
	if BRAI.applySkillChoice then BRAI.applySkillChoice(sType, m) end
	return m
end

-- Tipos que sao Homunculus S (precisam de BaseHomunType para skills da base).
function BRAI.isHomunS(t)
	local C = BRAI.const
	return t == C.EIRA or t == C.BAYERI or t == C.SERA or t == C.DIETER or t == C.ELEANOR
end

return true
