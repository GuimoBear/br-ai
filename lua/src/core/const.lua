-- const.lua — constantes da API do cliente do RO (espelham AzzyAI / Const_.lua)
-- No cliente real estas globais já existem; aqui definimos as que a BT usa,
-- com os mesmos valores, para o código novo e o simulador serem autossuficientes.
BRAI = BRAI or {}

local const = {}

-- Índices de GetV
const.V_OWNER                            = 0
const.V_POSITION                         = 1
const.V_TYPE                             = 2
const.V_MOTION                           = 3
const.V_ATTACKRANGE                      = 4
const.V_TARGET                           = 5
const.V_SKILLATTACKRANGE                 = 6
const.V_HOMUNTYPE                        = 7
const.V_HP                               = 8
const.V_SP                               = 9
const.V_MAXHP                            = 10
const.V_MAXSP                            = 11
const.V_MERTYPE                          = 12
const.V_POSITION_APPLY_SKILLATTACKRANGE  = 13
const.V_SKILLATTACKRANGE_LEVEL           = 14

-- Motions (retorno de V_MOTION)
const.MOTION_STAND   = 0
const.MOTION_MOVE    = 1
const.MOTION_ATTACK  = 2
const.MOTION_DEAD    = 3
const.MOTION_DAMAGE  = 4
const.MOTION_BENDDOWN= 5
const.MOTION_SIT     = 6
const.MOTION_SKILL   = 7
const.MOTION_CASTING = 8
const.MOTION_ATTACK2 = 9

-- Comandos (1º elemento de GetMsg/GetResMsg)
const.NONE_CMD          = 0
const.MOVE_CMD          = 1
const.STOP_CMD          = 2
const.ATTACK_OBJECT_CMD = 3
const.ATTACK_AREA_CMD   = 4
const.PATROL_CMD        = 5
const.HOLD_CMD          = 6
const.SKILL_OBJECT_CMD  = 7
const.SKILL_AREA_CMD    = 8
const.FOLLOW_CMD        = 9

-- Tipos de homúnculo (V_HOMUNTYPE) — subconjunto
const.LIF        = 1
const.AMISTR     = 2
const.FILIR      = 3
const.VANILMIRTH = 4
-- Homunculus S (valores reais de V_HOMUNTYPE, do Const_.lua do AzzyAI)
const.EIRA       = 48
const.BAYERI     = 49
const.SERA       = 50
const.DIETER     = 51
const.ELEANOR    = 52

BRAI.const = const
return const
