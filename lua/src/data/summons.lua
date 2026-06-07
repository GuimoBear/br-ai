-- summons.lua — dados das skills de INVOCAÇÃO (criação de atores com IA própria).
-- Genérico (chaveado por skill); por ora só a Sera (Summon Legion) está populada.
-- Números: AzzyAI 1.56 (H_SkillList) + divine-pride/rAthena (Renewal).
-- A DURAÇÃO da legião (timer do estimador) vem do SkillInfo (skills.lua, índice 8);
-- aqui ficam mob/quantidade/atributos por nível p/ o simulador (Fase 3) e o editor.
BRAI = BRAI or {}
local S = BRAI.skills.id

BRAI.summons = {
  [S.MH_SUMMON_LEGION] = {
    role  = "summon",
    types = { 2158, 2159, 2160 },  -- Hornet / Giant Hornet / Luciola Vespa (V_HOMUNTYPE do ator)
    names = { [2158] = "Hornet", [2159] = "Giant Hornet", [2160] = "Luciola Vespa" },
    -- por nível (1..5): mob invocado, quantidade e atributos do inseto no simulador
    perLevel = {
      { mob = 2158, count = 3, hp = 1000, atk = 150, aggro = 9, atkInterval = 800 },
      { mob = 2159, count = 3, hp = 1500, atk = 220, aggro = 9, atkInterval = 800 },
      { mob = 2159, count = 4, hp = 1800, atk = 260, aggro = 9, atkInterval = 750 },
      { mob = 2160, count = 4, hp = 2500, atk = 320, aggro = 9, atkInterval = 700 },
      { mob = 2160, count = 5, hp = 3000, atk = 380, aggro = 9, atkInterval = 700 },
    },
  },
}

-- Índices derivados (uso em runtime): mobClass -> skill, e set por skill.
BRAI.summonTypeSet = {}            -- [mobClass] = skillId  (qualquer invocação)
for skill, def in pairs(BRAI.summons) do
  def.typeSet = {}
  for _, t in ipairs(def.types) do
    def.typeSet[t] = true
    BRAI.summonTypeSet[t] = skill
  end
end

return BRAI.summons
