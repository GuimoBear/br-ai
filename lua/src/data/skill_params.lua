-- skill_params.lua — parâmetros das ações de skill (knobs como AutoMobCount, AoEFixedLevel,
-- HealSelfHP, ...) por PAPEL (ação), em DUAS camadas:
--   * global   : a base, válida para TODOS os homúnculos (modal "Parâmetros das skills").
--   * byHomun  : override OPCIONAL por homúnculo (modal "Skills por homúnculo", via checkbox).
-- Precedência no motor: param do nó > byHomun[homun][role][knob] > global[role][knob] > config.lua > default.
-- Persistido em homun_skill_params.json ({ params = global, overrides = byHomun }) -> skill_params.lua no pacote.
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
-- descrição curta da AÇÃO (o modal de Parâmetros é global por ação)
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

BRAI.skillParams = BRAI.skillParams or { global = {}, byHomun = {} }

-- lookup rápido knob->tipo por papel (derivado de skillParamKnobs)
local KNOB_TYPE = {}
for role, list in pairs(BRAI.skillParamKnobs) do
  KNOB_TYPE[role] = {}
  for _, k in ipairs(list) do KNOB_TYPE[role][k.key] = k.type end
end

-- valida um mapa knob=valor de UM papel (number via tonumber; boolean só boolean; fora do contrato descarta)
local function parseKnobs(role, knobs)
  local rr = {}
  for key, v in pairs(knobs) do
    local ty = KNOB_TYPE[role][key]
    if ty == "number" then local n = tonumber(v); if n then rr[key] = n end
    elseif ty == "boolean" then if type(v) == "boolean" then rr[key] = v end end
  end
  return rr
end

-- aplica/valida o JSON. Aceita { params|global = { aoeAtk = {...} }, overrides|byHomun = { ["51"] = { aoeAtk = {...} } } }.
-- Retrocompat: JSON só com `params` (global) carrega como global, sem overrides.
function BRAI.setSkillParams(tbl)
  local out = { global = {}, byHomun = {} }
  if type(tbl) == "table" then
    local g = tbl.params or tbl.global
    if type(g) == "table" then
      for role, knobs in pairs(g) do
        if KNOB_TYPE[role] and type(knobs) == "table" then
          local rr = parseKnobs(role, knobs)
          if next(rr) then out.global[role] = rr end
        end
      end
    end
    local bh = tbl.overrides or tbl.byHomun
    if type(bh) == "table" then
      for hk, roles in pairs(bh) do
        local h = tonumber(hk)
        if h and h == h and h > 0 and type(roles) == "table" then   -- h==h descarta NaN (tonumber("nan") no Lua 5.1)
          local hr = {}
          for role, knobs in pairs(roles) do
            if KNOB_TYPE[role] and type(knobs) == "table" then
              local rr = parseKnobs(role, knobs)
              if next(rr) then hr[role] = rr end
            end
          end
          if next(hr) then out.byHomun[h] = hr end
        end
      end
    end
  end
  BRAI.skillParams = out
  return out
end

-- valor efetivo de um knob: override do homúnculo (se houver) senão o global; nil se nenhum. Usado por effRole.
function BRAI.skillParamFor(homunType, role, key)
  local sp = BRAI.skillParams or {}
  homunType = tonumber(homunType)
  local bh = homunType and sp.byHomun and sp.byHomun[homunType]
  if bh and bh[role] and bh[role][key] ~= nil then return bh[role][key] end
  local g = sp.global and sp.global[role]
  if g and g[key] ~= nil then return g[key] end
  return nil
end

-- paramConfig(): dados p/ o modal GLOBAL de Parâmetros. Por papel: rótulo, descrição e
-- knobs {key, type, default (config global), value (global ou nil)}. NÃO recebe homún.
function BRAI.paramConfig()
  local def = (BRAI.defaultConfig and BRAI.defaultConfig()) or {}
  local g = (BRAI.skillParams and BRAI.skillParams.global) or {}
  local out = {}
  for _, role in ipairs(BRAI.skillParamRoles) do
    local knobs = {}
    for _, k in ipairs(BRAI.skillParamKnobs[role]) do
      knobs[#knobs + 1] = { key = k.key, type = k.type, default = def[k.key], value = (g[role] and g[role][k.key]) }
    end
    out[#out + 1] = { role = role, label = BRAI.skillParamRoleLabel[role], desc = BRAI.skillParamRoleDesc[role], knobs = knobs }
  end
  return out
end

-- overrideConfig(homunType): dados p/ a SOBREPOSIÇÃO no modal de Skills. Por papel: rótulo,
-- hasOverride (existe byHomun p/ este papel?) e knobs {key, type, globalValue (o que o Global
-- resolveria: global ?? config default), value (override atual ou nil)}.
function BRAI.overrideConfig(homunType)
  homunType = tonumber(homunType) or 0
  local def = (BRAI.defaultConfig and BRAI.defaultConfig()) or {}
  local g = (BRAI.skillParams and BRAI.skillParams.global) or {}
  local bh = (BRAI.skillParams and BRAI.skillParams.byHomun and BRAI.skillParams.byHomun[homunType]) or {}
  local out = {}
  for _, role in ipairs(BRAI.skillParamRoles) do
    local ov = bh[role]
    local knobs = {}
    for _, k in ipairs(BRAI.skillParamKnobs[role]) do
      local gv = def[k.key]
      if g[role] and g[role][k.key] ~= nil then gv = g[role][k.key] end
      knobs[#knobs + 1] = { key = k.key, type = k.type, globalValue = gv, value = (ov and ov[k.key]) }
    end
    out[#out + 1] = { role = role, label = BRAI.skillParamRoleLabel[role], hasOverride = (ov ~= nil), knobs = knobs }
  end
  return out
end

return true
