-- dist_runtime_test.lua — HARNESS DE DIST: carrega os artefatos como o AI.lua
-- (defaults -> config.lua -> skill_choice.lua -> monsters.lua -> tree_homun.lua) via
-- SIM_DISPATCH('loadDist') e roda cenarios, conferindo o intent. Fecha a lacuna de
-- cobertura: os outros testes injetam estado AO VIVO (setConfig/setSkillChoice); aqui
-- validamos o CAMINHO do PACOTE gerado, na ordem do AI.lua. (PLANO-GERACAO-LUA G0/G1/G4)
-- Uso: texlua tools/dist_runtime_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, S = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

-- arvores minimas por papel (succeeder p/ travar o alvo antes do ataque)
local ACTION = { mainAtk = "UseMainSkill", aoeAtk = "UseAoESkill", offBuff = "UseOffensiveBuff", defBuff = "UseDefensiveBuff" }
local function treeFor(role)
  local act = { type = "action", name = ACTION[role] }
  if role == "mainAtk" or role == "aoeAtk" then
    return { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, act } }
  end
  return act
end

-- cenario base: dono + homun (homunType) + monstros conforme o layout
local function scen(homun, layout, baseType)
  local ents = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = homun },
  }
  if layout == "single" then
    ents[#ents+1] = { id = 200, kind = "monster", x = 21, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
  elseif layout == "cluster" then  -- aglomerado COLADO (dist 1) p/ AoEs de alcance curto valerem
    ents[#ents+1] = { id = 200, kind = "monster", x = 21, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
    ents[#ents+1] = { id = 201, kind = "monster", x = 21, y = 21, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
    ents[#ents+1] = { id = 202, kind = "monster", x = 20, y = 21, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
  end
  local cfg = { homunId = 100, ownerId = 1, grid = { w = 40, h = 40 }, dt = 50, entities = ents }
  return cfg
end

-- roda o pacote (loadDist) e devolve { conjunto de skills conjuradas, ultima intent }
local function runDist(opts, steps)
  disp("loadDist", opts)
  local seen, last = {}, nil
  for _ = 1, (steps or 16) do
    local s = disp("step")
    if s.intent then last = s.intent; if s.intent.skill then seen[s.intent.skill] = true end end
  end
  return seen, last
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

print("== Harness de dist (loadDist replica o AI.lua) ==")

-- 1) caminho basico: Vanilmirth conjura Caprice (mainAtk) pelo dist
do
  local seen = runDist({ scenario = scen(C.VANILMIRTH, "single"), spec = treeFor("mainAtk") })
  check(seen[S.HVAN_CAPRICE], "Vanilmirth/mainAtk: Caprice conjura pelo pacote (dist)")
end

-- 2) config.lua mesclado: UseAttackSkill=false desliga a skill ofensiva
do
  local seen = runDist({ scenario = scen(C.VANILMIRTH, "single"), spec = treeFor("mainAtk"), config = { UseAttackSkill = false } })
  check(count(seen) == 0, "config (UseAttackSkill=false via config.lua): NAO conjura")
end

-- 3) skill_choice.lua aplicado: override Dieter aoeAtk=[Blast Forge] vence o padrao (Lava Slide)
do
  local choices = { choices = { [tostring(C.DIETER)] = { aoeAtk = { S.MH_BLAST_FORGE } } } }
  local seen = runDist({ scenario = scen(C.DIETER, "cluster"), spec = treeFor("aoeAtk"),
    config = { AutoMobCount = 2 }, choices = choices })
  check(seen[S.MH_BLAST_FORGE] and not seen[S.MH_LAVA_SLIDE],
    "skill_choice (Dieter aoeAtk=[Blast Forge] via skill_choice.lua): Blast Forge, nao Lava Slide")
end

-- 4) AoE padrao em cluster: Dieter conjura Lava Slide (prioridade) com AutoMobCount=2
do
  local seen = runDist({ scenario = scen(C.DIETER, "cluster"), spec = treeFor("aoeAtk"), config = { AutoMobCount = 2 } })
  check(seen[S.MH_LAVA_SLIDE], "Dieter/aoeAtk cluster: Lava Slide conjura (AutoMobCount=2)")
end

-- ===== G1: #1 AoE como ataque principal sem mainAtk =====
-- 5) FIX: Dieter (sem mainAtk) — AoE e a ofensiva principal: dispara em ALVO UNICO
do
  local seen = runDist({ scenario = scen(C.DIETER, "single"), spec = treeFor("aoeAtk"), config = { AutoMobCount = 2 } })
  check(seen[S.MH_LAVA_SLIDE], "#1 Dieter/aoeAtk 1 ALVO (AutoMobCount=2): Lava Slide dispara (AoE como principal)")
end

-- 6) GUARDA: Bayeri (com mainAtk) — AoE NAO dispara em alvo unico (preserva AutoMobCount)
do
  local seen = runDist({ scenario = scen(C.BAYERI, "single"), spec = treeFor("aoeAtk"), config = { AutoMobCount = 2 } })
  check(not seen[S.MH_HEILIGE_STANGE], "#1 Bayeri/aoeAtk 1 ALVO (AutoMobCount=2): AoE NAO dispara (tem mainAtk)")
end

-- 7) Bayeri mainAtk em alvo unico: Stahl Horn dispara (sanidade do single-target)
do
  local seen = runDist({ scenario = scen(C.BAYERI, "single"), spec = treeFor("mainAtk") })
  check(seen[S.MH_STAHL_HORN], "Bayeri/mainAtk 1 alvo: Stahl Horn dispara")
end

-- 8) Bayeri (com mainAtk) — AoE AINDA dispara no AGLOMERADO (>= AutoMobCount)
do
  local seen = runDist({ scenario = scen(C.BAYERI, "cluster"), spec = treeFor("aoeAtk"), config = { AutoMobCount = 2 } })
  check(seen[S.MH_HEILIGE_STANGE], "#1 Bayeri/aoeAtk cluster (>=AutoMobCount): Heilige Stange dispara")
end

-- ===== G2: monsters.lua (catalogo) carregado na sequencia do dist =====
do
  local catalog = { monsters = { { id = 1038, desc = "Osiris" }, { id = 1002, desc = "Poring" } }, groups = { { id = 1, name = "Chefes", members = { 1038 } } } }
  local mtree = { type = "sequence", children = {
    { type = "action", name = "AcquireTarget" },
    { type = "monsterCheck", group = 1, child = { type = "action", name = "AttackTarget" } } } }
  local function scenEt(etype)
    return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
      { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
      { id = 100, kind = "homun", x = 20, y = 20, hp = 100, maxhp = 100, sp = 100, maxsp = 100, homunType = C.VANILMIRTH },
      { id = 200, kind = "monster", x = 21, y = 20, hp = 200, maxhp = 200, atk = 1, aggro = 2, aggressive = false, etype = etype } } }
  end
  local function lastKind(scn) disp("loadDist", { scenario = scn, spec = mtree, catalog = catalog })
    local k = nil; for _ = 1, 6 do local s = disp("step"); k = s.intent and s.intent.kind end; return k end
  check(lastKind(scenEt(1038)) == "attack", "G2 monsters.lua via dist: alvo no grupo (Osiris) -> ataca")
  check(lastKind(scenEt(1002)) ~= "attack", "G2 monsters.lua via dist: alvo fora do grupo (Poring) -> nao ataca")
  -- sem catalogo (omitido): o grupo 1 fica vazio -> nem o Osiris casa
  disp("loadDist", { scenario = scenEt(1038), spec = mtree })
  local k = nil; for _ = 1, 6 do local s = disp("step"); k = s.intent and s.intent.kind end
  check(k ~= "attack", "G2 sem monsters.lua: grupo vazio -> nao ataca (omissao coerente)")
end

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
