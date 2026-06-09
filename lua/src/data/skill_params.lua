-- skill_params.lua — parâmetros de skill POR HOMÚNCULO e POR PAPEL (knobs como AutoMobCount,
-- AoEFixedLevel, HealSelfHP, ...). Nova camada entre o override por nó (#4) e o config.lua global:
--   param do nó > skillParams[homunType][role][knob] > bb.config[knob] > default do motor.
-- Persistido em homun_skill_params.json -> skill_params.lua no pacote. [PLANO-CONFIG-SKILLS C0]
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

BRAI.skillParams = BRAI.skillParams or {}

-- lookup rápido knob->tipo por papel (derivado de skillParamKnobs)
local KNOB_TYPE = {}
for role, list in pairs(BRAI.skillParamKnobs) do
  KNOB_TYPE[role] = {}
  for _, k in ipairs(list) do KNOB_TYPE[role][k.key] = k.type end
end

-- aplica/valida o JSON. Aceita { params = { ["51"]={aoeAtk={AutoMobCount=1}} } } ou o mapa direto.
-- papel/knob fora do contrato é DESCARTADO; number via tonumber; boolean só aceita boolean.
function BRAI.setSkillParams(tbl)
  local out = {}
  if type(tbl) == "table" then
    local src = tbl.params or tbl
    if type(src) == "table" then
      for k, roles in pairs(src) do
        local t = tonumber(k)
        if t and type(roles) == "table" then
          local r = {}
          for role, knobs in pairs(roles) do
            if KNOB_TYPE[role] and type(knobs) == "table" then
              local rr = {}
              for key, v in pairs(knobs) do
                local ty = KNOB_TYPE[role][key]
                if ty == "number" then local n = tonumber(v); if n then rr[key] = n end
                elseif ty == "boolean" then if type(v) == "boolean" then rr[key] = v end end
              end
              if next(rr) then r[role] = rr end
            end
          end
          out[t] = r
        end
      end
    end
  end
  BRAI.skillParams = out
  return out
end

-- valor de um knob de papel p/ um homún (ou nil se não configurado). Usado por effRole no motor.
function BRAI.skillParamFor(homunType, role, key)
  local sp = BRAI.skillParams[homunType]
  if sp and sp[role] then return sp[role][key] end
  return nil
end

-- paramConfig(homunType): dados p/ o modal de parâmetros. Por papel: rótulo, skills efetivas
-- (id+nome+maxLevel) e knobs {key, type, default (config global), value (skillParams ou nil)}.
function BRAI.paramConfig(homunType, baseType)
  homunType = tonumber(homunType) or 0
  baseType = tonumber(baseType) or 0
  local def = (BRAI.defaultConfig and BRAI.defaultConfig()) or {}
  local sp = BRAI.skillParams[homunType] or {}
  local rc = (BRAI.roleConfig and BRAI.roleConfig(homunType)) or {}
  local rcByKey = {}; for _, r in ipairs(rc) do rcByKey[r.key] = r end
  local prof = (BRAI.getProfile and BRAI.getProfile(homunType)) or {}
  -- forma base (Homunculus S herda cura/ownerBuff/castling do tipo base, como em profileFor)
  local base = (baseType ~= 0 and baseType ~= homunType and BRAI.getProfile and BRAI.getProfile(baseType)) or nil
  local cat = (BRAI.skillCatalog and BRAI.skillCatalog(homunType, baseType)) or {}
  local catById = {}; for _, s in ipairs(cat) do catById[s.id] = s end
  local function skillEntry(id) local s = catById[id]; if s then return { id = id, name = s.iro, maxLevel = s.maxLevel or 1 } else return { id = id, name = "#" .. id, maxLevel = 1 } end end
  -- skill de cura/ownerBuff/castling de um perfil (própria); herança vem do base via `or` abaixo
  local function roleSkillOf(pr, role)
    if role == "healSelf" then if pr.healSelf and pr.heal then return pr.heal end
    elseif role == "healOwner" then if pr.healOwner and pr.heal then return pr.heal end
    elseif role == "ownerBuff" then return pr.ownerBuff
    elseif role == "castling" then return pr.castling end
    return nil
  end
  local function effSkills(role)
    if rcByKey[role] then  -- os 4 papéis: efetivo do roleConfig (espelha a tela Skills)
      local o = {}; for _, e in ipairs(rcByKey[role].effective or {}) do o[#o + 1] = { id = e.id, name = e.name, maxLevel = e.maxLevel } end; return o
    end
    local id = roleSkillOf(prof, role) or (base and roleSkillOf(base, role))   -- própria ou herdada do base
    if id then return { skillEntry(id) } end
    return {}
  end
  local out = {}
  for _, role in ipairs(BRAI.skillParamRoles) do
    local skills = effSkills(role)
    local knobs = {}
    for _, k in ipairs(BRAI.skillParamKnobs[role]) do
      knobs[#knobs + 1] = { key = k.key, type = k.type, default = def[k.key], value = (sp[role] and sp[role][k.key]) }
    end
    out[#out + 1] = { role = role, label = BRAI.skillParamRoleLabel[role], hasSkill = (#skills > 0), skills = skills, knobs = knobs }
  end
  return out
end

return true
