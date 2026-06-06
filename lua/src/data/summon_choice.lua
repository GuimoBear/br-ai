-- summon_choice.lua — config GLOBAL das invocações por homúnculo (nível, política
-- de re-invocação, gatilhos). Persistida em homun_summons.json (igual ao
-- homun_skills.json) e consumida como PADRÃO pelo nó UseSeraLegion — os params do
-- nó, se existirem, têm precedência. Edição na tela "Skills" do editor (sub-painel).
BRAI = BRAI or {}
BRAI.summonChoice = BRAI.summonChoice or {}

local RESUMMON = { onExpire = true, keepFull = true, minCount = true }

-- normaliza/valida e define o override global. Aceita { choices = { ["50"]={...} } } ou mapa direto.
function BRAI.setSummonChoice(tbl)
  local out = {}
  if type(tbl) == "table" then
    local src = tbl.choices or tbl
    if type(src) == "table" then
      for k, params in pairs(src) do
        local t = tonumber(k)
        if t and type(params) == "table" then
          local r = {}
          local lv = tonumber(params.level); if lv and lv >= 1 and lv <= 10 then r.level = math.floor(lv) end
          if type(params.resummon) == "string" and RESUMMON[params.resummon] then r.resummon = params.resummon end
          local mc = tonumber(params.minCount); if mc and mc >= 1 then r.minCount = math.floor(mc) end
          local mm = tonumber(params.minMobCount); if mm and mm >= 0 then r.minMobCount = math.floor(mm) end
          if type(params.vsBossOnly) == "boolean" then r.vsBossOnly = params.vsBossOnly end
          out[t] = r
        end
      end
    end
  end
  BRAI.summonChoice = out
  return out
end

function BRAI.summonChoiceFor(homunType)
  return BRAI.summonChoice[tonumber(homunType) or 0] or {}
end

-- summonInfo(homunType): dados p/ o sub-painel de invocação (1 dispatch).
-- skill da invocação (se houver), catálogo por nível (mob/qtd/duração) e o SCHEMA
-- dos campos com texto de ajuda (documentação, §3.1) + os valores salvos.
function BRAI.summonInfo(homunType)
  homunType = tonumber(homunType) or 0
  local prof = BRAI.getProfile(homunType) or {}
  local skill = prof.summon
  if not skill then return { hasSummon = false } end
  local def = BRAI.summons and BRAI.summons[skill]
  local info = BRAI.skills and BRAI.skills.info and BRAI.skills.info[skill]
  local meta = BRAI.skillMeta and BRAI.skillMeta[skill]
  local lst = BRAI.skills and BRAI.skills.list and BRAI.skills.list[homunType]
  local maxLvl = (lst and lst[skill]) or 5
  local perLevel = {}
  if def and def.perLevel then
    for i, pl in ipairs(def.perLevel) do
      perLevel[i] = {
        level = i, mob = pl.mob,
        name = (def.names and def.names[pl.mob]) or ("mob " .. tostring(pl.mob)),
        count = pl.count,
        duration = (info and info[8] and (info[8][i] or info[8][#info[8]])) or 0,
      }
    end
  end
  local iro = (meta and meta.iro) or BRAI.skillsys.name(skill)
  local fields = {
    { key = "level", label = "Nível", type = "int", min = 1, max = maxLvl, default = maxLvl,
      help = "Nível da " .. iro .. " — define o mob invocado, a quantidade e a duração. Nível inválido NÃO desliga a skill em silêncio." },
    { key = "resummon", label = "Re-invocação", type = "enum", options = { "onExpire", "keepFull", "minCount" }, default = "onExpire",
      help = "Quando re-invocar a legião: onExpire = só quando expira/zera (econômico, fiel à AzzyAI); keepFull = mantém a swarm no máximo (gasta mais SP); minCount = re-invoca quando os vivos caem abaixo do mínimo." },
    { key = "minCount", label = "Mínimo vivo (p/ minCount)", type = "int", min = 1, max = maxLvl, default = 3,
      help = "Só com Re-invocação = minCount: piso de insetos vivos antes de reforçar a legião." },
    { key = "minMobCount", label = "Mín. de inimigos", type = "int", min = 0, default = 1,
      help = "Nº mínimo de inimigos no alcance para valer a pena invocar (0 = sempre que houver alvo)." },
    { key = "vsBossOnly", label = "Só em Boss/MVP", type = "bool", default = false,
      help = "Só invoca contra Boss/MVP — a swarm rende muito em alvos de HP alto." },
  }
  return { hasSummon = true, skill = skill, name = iro, note = meta and meta.desc,
    perLevel = perLevel, fields = fields, saved = BRAI.summonChoice[homunType] or {} }
end

return true
