-- combos.lua — dados dos combos da Eleanor.
-- Fase 1: custo de esfera por elo. (Fase 2/3 acrescentam cadeias, janelas e proibições.)
-- Custos conferidos contra a wiki/AzzyAI; CORRIGE o bug do EQC (na AzzyAI o
-- MarkSkillUsed não deduzia esfera no EQC — "--No sphere use?", bug R2).
-- A presença da skill nesta tabela também marca "gera esfera" (é ataque físico):
-- Sonic Claw tem custo 0 mas ainda assim gera uma tentativa de esfera ao acertar.
BRAI = BRAI or {}
local S = BRAI.skills.id

BRAI.sphereCost = {
	[S.MH_SONIC_CLAW]      = 0,
	[S.MH_SILVERVEIN_RUSH] = 1,
	[S.MH_MIDNIGHT_FRENZY] = 2,
	[S.MH_TINDER_BREAKER]  = 1,
	[S.MH_CBC]             = 1,
	[S.MH_EQC]             = 2,   -- corrigido (AzzyAI não deduzia)
}

-- Operações especiais de esfera (Eleanor): além do custo fixo dos combos.
-- Blazing and Furious CONSOME todas as esferas; The One Fighter Rises ENCHE ao máximo.
BRAI.sphereOps = {
	[S.MH_BLAZING_AND_FURIOUS]   = "consumeAll",
	[S.MH_THE_ONE_FIGHTER_RISES] = "fillMax",
}

return BRAI.sphereCost
