-- profiles.lua — papeis de skill por tipo de homunculo (a "estrategia" do AzzyAI).
-- A arvore e adaptativa: refere papeis (mainAtk/aoeAtk/...) e o perfil resolve o skill id
-- conforme o V_HOMUNTYPE. Papeis:
--   mainAtk   : skill ofensiva single-target
--   aoeAtk    : skill ofensiva em area (usa contagem de mobs)
--   offBuff[] : auto-buffs ofensivos (atacam melhor)
--   defBuff[] : auto-buffs defensivos
--   heal      : skill de cura ; healOwner/healSelf : a quem se aplica
--   ownerBuff : buff aplicado no dono (ex.: Painkiller)
--   summon    : invocar minions (Summon Legion)
--   combo[]   : cadeia de combo (Eleanor)
--   styleChange : alternar modo (Eleanor)
--   debuffAoE : debuff em area (Volcanic Ash)
--   castling  : reposicionar dono/self (Amistr)
BRAI = BRAI or {}
local C = BRAI.const
local S = BRAI.skills.id

local profiles = {}

profiles[C.LIF] = {
	heal = S.HLIF_HEAL, healOwner = true,
	offBuff = { S.HLIF_CHANGE },          -- Mental Charge
	defBuff = { S.HLIF_AVOID },           -- Urgent Escape
}
profiles[C.AMISTR] = {
	offBuff = { S.HAMI_BLOODLUST },
	defBuff = { S.HAMI_DEFENCE },         -- Amistr Bulwark
	castling = S.HAMI_CASTLE,             -- tira monstros do dono / reposiciona
}
profiles[C.FILIR] = {
	mainAtk = S.HFLI_MOON,                -- Moonlight (melee, single)
	offBuff = { S.HFLI_FLEET },           -- Flitting
	defBuff = { S.HFLI_SPEED },           -- Accelerated Flight
	-- SBR44 omitido por padrao (nuke suicida; equivale a AllowSBR44=0 no AzzyAI)
}
profiles[C.VANILMIRTH] = {
	mainAtk = S.HVAN_CAPRICE,             -- Caprice (bolt, alcance 9)
	heal = S.HVAN_CHAOTIC, healOwner = true, healSelf = true, -- Chaotic Blessing
}
profiles[C.SERA] = {
	mainAtk = S.MH_NEEDLE_OF_PARALYZE,
	aoeAtk = S.MH_POISON_MIST,
	ownerBuff = S.MH_PAIN_KILLER,
	summon = S.MH_SUMMON_LEGION,
}
profiles[C.EIRA] = {
	mainAtk = S.MH_ERASER_CUTTER,
	aoeAtk = S.MH_XENO_SLASHER,
	heal = S.MH_SILENT_BREEZE, healOwner = true,
	offBuff = { S.MH_OVERED_BOOST },
}
profiles[C.ELEANOR] = {
	mainAtk = S.MH_SONIC_CLAW,
	combo = { S.MH_SONIC_CLAW, S.MH_SILVERVEIN_RUSH, S.MH_MIDNIGHT_FRENZY },
	styleChange = S.MH_STYLE_CHANGE,
}
profiles[C.BAYERI] = {
	mainAtk = S.MH_STAHL_HORN,
	aoeAtk = S.MH_HEILIGE_STANGE,
	offBuff = { S.MH_GOLDENE_FERSE, S.MH_ANGRIFFS_MODUS },
	defBuff = { S.MH_STEINWAND },
	ownerBuff = S.MH_GOLDENE_TONE,        -- Goldene Tone (self-cast; o buff vale p/ o dono)
}
profiles[C.DIETER] = {
	aoeAtk = { S.MH_LAVA_SLIDE, S.MH_BLAST_FORGE },  -- Dieter: 2 AoE padrão (prioridade: Lava Slide → Blast Forge)
	offBuff = { S.MH_PYROCLASTIC },
	defBuff = { S.MH_GRANITIC_ARMOR },
	debuffAoE = S.MH_VOLCANIC_ASH,
}

local EMPTY = {}
function BRAI.getProfile(homunType)
	return profiles[homunType] or EMPTY
end

BRAI.profiles = profiles
return profiles
