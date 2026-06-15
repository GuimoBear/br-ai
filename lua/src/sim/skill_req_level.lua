-- skill_req_level.lua — SÓ DO SIMULADOR. Nivel BASE minimo do homunculo p/ APRENDER cada skill
-- (Renewal, ratemyserver.net). Vive em lua/src/sim/ (EXCLUIDO do pacote/dist): a IA real nunca
-- usa nivel — o jogo controla "possui a skill" via GetV. Aqui o stub do GetV (runtime.lua) usa
-- isto + o lvl da entidade homun p/ MOCKAR esse comportamento no simulador.
-- Ausente = sem requisito (skills dos homunculos BASE; e 2 S sem o campo no RMS: 8032, 8034).
BRAI = BRAI or {}
local id = BRAI.skills.id

BRAI.skills.reqLevel = {
	[id.MH_SUMMON_LEGION]        = 132, [id.MH_NEEDLE_OF_PARALYZE]    = 105,
	[id.MH_POISON_MIST]          = 116, [id.MH_PAIN_KILLER]           = 123,
	[id.MH_LIGHT_OF_REGENE]      = 128, [id.MH_OVERED_BOOST]          = 114,
	[id.MH_ERASER_CUTTER]        = 106, [id.MH_XENO_SLASHER]          = 121,
	[id.MH_SILENT_BREEZE]        = 137, [id.MH_STYLE_CHANGE]          = 100,
	[id.MH_SONIC_CLAW]           = 100, [id.MH_SILVERVEIN_RUSH]       = 114,
	[id.MH_MIDNIGHT_FRENZY]      = 128, [id.MH_STAHL_HORN]            = 105,
	[id.MH_STEINWAND]            = 121, [id.MH_ANGRIFFS_MODUS]        = 130,
	[id.MH_TINDER_BREAKER]       = 100, [id.MH_CBC]                   = 112,
	[id.MH_EQC]                  = 133, [id.MH_MAGMA_FLOW]            = 122,
	[id.MH_GRANITIC_ARMOR]       = 116, [id.MH_LAVA_SLIDE]            = 109,
	[id.MH_PYROCLASTIC]          = 131, [id.MH_VOLCANIC_ASH]          = 102,
	[id.MH_BLAST_FORGE]          = 215, [id.MH_TEMPERING]             = 230,
	[id.MH_TWISTER_CUTTER]       = 215, [id.MH_ABSOLUTE_ZEPHYR]       = 230,
	[id.MH_BLAZING_AND_FURIOUS]  = 215, [id.MH_THE_ONE_FIGHTER_RISES] = 230,
	[id.MH_TOXIN_OF_MANDARA]     = 215, [id.MH_NEEDLE_STINGER]        = 230,
	[id.MH_GLANZEN_SPIES]        = 215, [id.MH_HEILIGE_PFERD]         = 230,
	[id.MH_GOLDENE_TONE]         = 230,
}
return BRAI.skills.reqLevel
