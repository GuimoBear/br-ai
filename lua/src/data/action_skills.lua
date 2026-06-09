-- action_skills.lua — fonte ÚNICA das skills efetivas por AÇÃO automática de skill, para a UI
-- (rótulo do nó no editor e filhos do nó no simulador). Reusa BRAI.roleConfig (os 4 papéis de
-- ataque/buff, que expõem `candidates` p/ separar "nada selecionado" de "o tipo não tem o papel")
-- e a resolução de perfil/base p/ cura/buff do dono/castling. É SÓ LEITURA — não chama a API
-- nativa nem decide nada; espelha exatamente o que o motor (effRole/profileFor) usaria.
-- [PLANO-SKILLS-NO-NO S0]
BRAI = BRAI or {}

-- Ação automática de skill -> papel (espelha ACTION_ROLE + PARAM_EXTRA do editor.js).
BRAI.actionRole = {
  UseAoESkill = "aoeAtk", UseMainSkill = "mainAtk",
  UseOffensiveBuff = "offBuff", UseDefensiveBuff = "defBuff",
  UseHealSelf = "healSelf", UseHealOwner = "healOwner",
  UseOwnerBuff = "ownerBuff", UseCastling = "castling",
}

-- Papéis resolvidos pelo roleConfig (têm candidatos + lista efetiva; aceitam override do usuário).
local RC_ROLES = { aoeAtk = true, mainAtk = true, offBuff = true, defBuff = true }

-- Skill única de cura/ownerBuff/castling de um perfil (MESMA regra do paramConfig em skill_params).
local function roleSkillOf(pr, role)
  if role == "healSelf" then if pr.healSelf and pr.heal then return pr.heal end
  elseif role == "healOwner" then if pr.healOwner and pr.heal then return pr.heal end
  elseif role == "ownerBuff" then return pr.ownerBuff
  elseif role == "castling" then return pr.castling end
  return nil
end

-- Entrada do roleConfig para um papel (cache opcional via `rc` p/ não recomputar 1x por nó).
local function rcEntry(homunType, role, rc)
  rc = rc or (BRAI.roleConfig and BRAI.roleConfig(homunType)) or {}
  for _, r in ipairs(rc) do if r.key == role then return r end end
  return nil
end

-- BRAI.roleSkillsFor(homunType, baseType, role[, rc]) -> { {id,name,maxLevel,level}, ... }
-- Lista EFETIVA de skills do papel (qualquer um dos 8). Os 4 papéis de ataque/buff vêm do
-- roleConfig (espelha a tela "Skills"); os 4 de perfil resolvem a skill própria ou herdada do
-- tipo base (Homunculus S). `rc` (roleConfig já pronto) é opcional para reuso.
function BRAI.roleSkillsFor(homunType, baseType, role, rc)
  homunType = tonumber(homunType) or 0
  baseType = tonumber(baseType) or 0
  if RC_ROLES[role] then
    local r = rcEntry(homunType, role, rc)
    local o = {}
    if r then for _, e in ipairs(r.effective or {}) do
      o[#o + 1] = { id = e.id, name = e.name, maxLevel = e.maxLevel, level = e.level }
    end end
    return o
  end
  local prof = (BRAI.getProfile and BRAI.getProfile(homunType)) or {}
  local base = (baseType ~= 0 and baseType ~= homunType and BRAI.getProfile and BRAI.getProfile(baseType)) or nil
  local id = roleSkillOf(prof, role) or (base and roleSkillOf(base, role))
  if not id then return {} end
  local name, maxLevel = ("#" .. id), 1
  local cat = (BRAI.skillCatalog and BRAI.skillCatalog(homunType, baseType)) or {}
  for _, s in ipairs(cat) do if s.id == id then name = s.iro; maxLevel = s.maxLevel or 1; break end end
  return { { id = id, name = name, maxLevel = maxLevel, level = 0 } }
end

-- BRAI.actionSkills(bb, actionName[, rc]) -> nil se a ação NÃO é de skill, senão:
--   { role, state = "ok"|"none"|"missing", skills = { {id,name,maxLevel,level}, ... }, activeId }
--     ok      : há skill(s) efetiva(s) p/ usar
--     none    : o tipo TEM skills do papel, mas nenhuma selecionada (só papéis do roleConfig)
--     missing : o tipo NÃO tem skill do papel (ex.: Dieter ataque principal; homún sem cura)
--   activeId  : id da skill disparada NESTE tick (casa bb.intent), p/ destaque ao vivo (ou nil)
-- `rc` = roleConfig do homún já computado; passe p/ resolver 1x por snapshot (não 1x por nó).
function BRAI.actionSkills(bb, actionName, rc)
  local role = BRAI.actionRole[actionName]
  if not role then return nil end
  local homunType = (bb and bb.self and bb.self.homunType) or 0
  local baseType = (bb and bb.config and bb.config.BaseHomunType) or 0
  if RC_ROLES[role] then rc = rc or (BRAI.roleConfig and BRAI.roleConfig(homunType)) or {} end
  local skills = BRAI.roleSkillsFor(homunType, baseType, role, rc)
  local state = "ok"
  if #skills == 0 then
    if RC_ROLES[role] then
      local r = rcEntry(homunType, role, rc)
      local cands = (r and r.candidates) and #r.candidates or 0
      state = (cands > 0) and "none" or "missing"
    else
      state = "missing"
    end
  end
  local activeId = nil
  if bb and bb.intent and bb.intent.kind == "skill" and bb.intent.skill then
    for _, s in ipairs(skills) do if s.id == bb.intent.skill then activeId = s.id; break end end
  end
  return { role = role, state = state, skills = skills, activeId = activeId }
end

return true
