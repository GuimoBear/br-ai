-- skill_params.lua — parâmetros GLOBAIS das ações de skill (knobs como AutoMobCount, AoEFixedLevel,
-- HealSelfHP, ...) por PAPEL (ação). Os valores valem para TODOS os homúnculos que têm o papel.
-- É a ÚNICA fonte da verdade da UI: não há mais dimensão por homúnculo nem opção "herdar".
-- Camada única entre o override por nó (#4) e o config.lua global:
--   param do nó > skillParams[role][knob] (este modal) > bb.config[knob] > default do motor.
-- Persistido em homun_skill_params.json -> skill_params.lua no pacote.
BRAI = BRAI or {}

-- contrato dos knobs por papel (fonte da verdade p/ motor, validação e UI). Ordem = ordem na UI.
BRAI.skillParamKnobs = {
  aoeAtk    = { { key = "UseAttackSkill", type = "boolean" }, { key = "AutoMobMode", type = "number" }, { key = "AutoMobCount", type = "number" }, { key = "AttackSkillReserveSP", type = "number" }, { key = "AoEFixedLevel", type = "number" }, { key = "AoEMaximizeTargets", type = "boolean" } },
  mainAtk   = { { key = "UseAttackSkill", type = "boolean" }, { key = "AttackSkillReserveSP", type = "number" }, { key = "AttackRange", type = "number" }, { key = "UseHomunSSkillAttack", type = "boolean" }, { key = "UseHomunSSkillChase", type = "boolean" } },
  offBuff   = { { key = "UseOffensiveBuff", type = "boolean" } },
  defBuff   = { { key = "UseDefensiveBuff", type = "boolean" } },
  healSelf  = { { key = "UseAutoHeal", type = "boolean" }, { key = "HealSelfHP", type = "number" } },
  healOwner = { { key = "UseAutoHeal", type = "boolean" }, { key = "HealOwnerHP", type = "number" } },
  ownerBuff = { { key = "UseOwnerBuff", type = "boolean" } },
  castling  = { { key = "UseCastling", type = "boolean" }, { key = "CastleDefendThreshold", type = "number" } },
}

-- ordem e rótulos dos papéis (p/ a UI)
BRAI.skillParamRoles = { "aoeAtk", "mainAtk", "offBuff", "defBuff", "healSelf", "healOwner", "ownerBuff", "castling" }
BRAI.skillParamRoleLabel = {
  aoeAtk = "Skill em área (AoE)", mainAtk = "Skill principal (alvo único)",
  offBuff = "Buff ofensivo", defBuff = "Buff defensivo",
  healSelf = "Cura própria", healOwner = "Cura do dono",
  ownerBuff = "Buff no dono", castling = "Castling",
}
-- descrição curta da AÇÃO (o modal é global por ação; não mostra mais a skill específica de um homún)
BRAI.skillParamRoleDesc = {
  aoeAtk    = "Skill ofensiva de área, usada quando há aglomerado de alvos.",
  mainAtk   = "Skill ofensiva de alvo único, usada no alvo principal.",
  offBuff   = "Buffs ofensivos aplicados em si mesmo no combate.",
  defBuff   = "Buffs defensivos aplicados em si mesmo.",
  healSelf  = "Cura aplicada no próprio homúnculo quando o HP cai.",
  healOwner = "Cura aplicada no dono quando o HP dele cai.",
  ownerBuff = "Buff aplicado no dono (ex.: Painkiller).",
  castling  = "Reposiciona o dono/si para tirar o dono do aperto.",
}

BRAI.skillParams = BRAI.skillParams or {}

-- lookup rápido knob->tipo por papel (derivado de skillParamKnobs)
local KNOB_TYPE = {}
for role, list in pairs(BRAI.skillParamKnobs) do
  KNOB_TYPE[role] = {}
  for _, k in ipairs(list) do KNOB_TYPE[role][k.key] = k.type end
end

-- aplica/valida o JSON GLOBAL. Aceita { params = { aoeAtk = { AutoMobCount = 1 } } } ou o mapa direto.
-- papel/knob fora do contrato é DESCARTADO; number via tonumber; boolean só aceita boolean.
-- O formato antigo por-homúnculo ({ ["51"] = { aoeAtk = {...} } }) tem chaves numéricas que não
-- casam KNOB_TYPE e são descartadas (retrocompat: vira "sem parâmetros").
function BRAI.setSkillParams(tbl)
  local out = {}
  if type(tbl) == "table" then
    local src = tbl.params or tbl
    if type(src) == "table" then
      for role, knobs in pairs(src) do
        if KNOB_TYPE[role] and type(knobs) == "table" then
          local rr = {}
          for key, v in pairs(knobs) do
            local ty = KNOB_TYPE[role][key]
            if ty == "number" then local n = tonumber(v); if n then rr[key] = n end
            elseif ty == "boolean" then if type(v) == "boolean" then rr[key] = v end end
          end
          if next(rr) then out[role] = rr end
        end
      end
    end
  end
  BRAI.skillParams = out
  return out
end

-- valor GLOBAL de um knob de papel (ou nil se não configurado). Usado por effRole no motor.
function BRAI.skillParamFor(role, key)
  local r = BRAI.skillParams[role]
  if r then return r[key] end
  return nil
end

-- paramConfig(): dados p/ o modal GLOBAL de parâmetros. Por papel: rótulo, descrição da ação e
-- knobs {key, type, default (config global), value (skillParams global ou nil)}. NÃO recebe homún.
function BRAI.paramConfig()
  local def = (BRAI.defaultConfig and BRAI.defaultConfig()) or {}
  local sp = BRAI.skillParams or {}
  local out = {}
  for _, role in ipairs(BRAI.skillParamRoles) do
    local knobs = {}
    for _, k in ipairs(BRAI.skillParamKnobs[role]) do
      knobs[#knobs + 1] = { key = k.key, type = k.type, default = def[k.key], value = (sp[role] and sp[role][k.key]) }
    end
    out[#out + 1] = { role = role, label = BRAI.skillParamRoleLabel[role], desc = BRAI.skillParamRoleDesc[role], knobs = knobs }
  end
  return out
end

return true
