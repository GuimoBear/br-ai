-- summon_scenarios_test.lua — Fase 6: regressão dos 6 cenários de demonstração da Sera.
-- Carrega a árvore real (trees/Sera - Vanilmirth) + cada cenário (scenarios/Sera - *)
-- e afirma o comportamento da Legião. Uso: texlua tools/summon_scenarios_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, SID = BRAI.json, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function readFile(path) local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s end

local SUM = SID.MH_SUMMON_LEGION
-- carrega a ÁRVORE real (a do vídeo) uma vez
disp("setTree", json.decode(readFile("trees/Sera - Vanilmirth/tree.json")).spec)
local function loadScen(path) json.decode(SIM_DISPATCH("load", readFile(path))) end

local function entById(s, id) for _, e in ipairs(s.entities or {}) do if e.id == id then return e end end end
local function countSummons(s) local n = 0; for _, e in ipairs(s.entities or {}) do if e.kind == "summon" then n = n + 1 end end; return n end

local function run(n)
  local r = { sumCasts = 0, poison = false, needle = false, maxSum = 0, targetDead = false, targetHp = nil, seraHp = nil, seraMax = nil }
  for _ = 1, n do
    local s = disp("step")
    local it = s.intent
    if it and it.kind == "skill" then
      if it.skill == SUM then r.sumCasts = r.sumCasts + 1 end
      if it.skill == SID.MH_POISON_MIST then r.poison = true end
      if it.skill == SID.MH_NEEDLE_OF_PARALYZE then r.needle = true end
    end
    local ns = countSummons(s); if ns > r.maxSum then r.maxSum = ns end
    local t = entById(s, 201)
    if (not t) or (t.hp <= 0) then r.targetDead = true else r.targetHp = t.hp end
    local h = entById(s, 100); if h then r.seraHp = h.hp; r.seraMax = h.maxhp end
  end
  return r
end
local function clearLegion()  -- remove os insetos atuais (simula perda de visão / morte)
  for _, e in ipairs(disp("snapshot").entities) do if e.kind == "summon" then disp("removeMonster", { id = e.id }) end end
end

print("== D1: Enxame no alvo isolado ==")
loadScen("scenarios/Sera - 1 Enxame no alvo isolado.json")
local r = run(20)
check(r.sumCasts >= 1, "D1a: Sera invoca a Legião (Summon Legion)")
check(r.maxSum == 5, "D1b: nível 5 -> enxame de 5 insetos")
check(r.targetHp and r.targetHp < 150000, "D1c: a swarm causa dano ao alvo")

print("== D2: Caçada em MVP (boss) ==")
loadScen("scenarios/Sera - 2 Cacada em MVP (boss).json")
r = run(20)
check(r.sumCasts >= 1 and r.maxSum == 5, "D2a: invoca a Legião no MVP (5 insetos)")
check(r.needle, "D2b: também castela Needle of Paralysis no chefe")
check(not r.targetDead, "D2c: o MVP segue vivo (dano sustentado, sem one-shot)")

print("== D3: Expiração e re-summon ==")
loadScen("scenarios/Sera - 3 Expiracao e re-summon.json")
r = run(8)
check(r.sumCasts == 1 and r.maxSum == 5, "D3a: invoca UMA vez (não re-summona enquanto viva)")
clearLegion(); BRAI.sim.bb.persist.legion.expiresAt = BRAI.sim.bb:now(); BRAI.sim.bb.persist.skillReadyAt[SUM] = 0   -- expira a legião + passa o delay de cast (2s no jogo)
local r2 = run(4)
check(r2.sumCasts >= 1 and r2.maxSum == 5, "D3b: legião expirada -> re-summona (nova leva de 5)")

print("== D4: Perda de visão não re-summona (A3) ==")
loadScen("scenarios/Sera - 4 Perda de visao.json")
r = run(6)
check(r.sumCasts == 1 and r.maxSum == 5, "D4a: invoca uma vez (5 insetos)")
clearLegion()                                  -- some da visão por 1 tick (timer intacto)
local s = disp("step")
local lg = BRAI.sim.bb.self.legion
check(lg and lg.alive == true and lg.raw == 0, "D4b: alive permanece por timer apesar de raw 0 (A3)")
check(not (s.intent and s.intent.skill == SUM), "D4c: NÃO re-summona nesse tick (sem desperdício de SP)")

print("== D5: Alvo morre -> insetos batem na Sera (dano real) ==")
loadScen("scenarios/Sera - 5 Alvo morre, insetos batem na Sera.json")
r = run(45)
check(r.targetDead, "D5a: o alvo (baixo HP) é abatido pela swarm")
check(r.seraHp and r.seraMax and r.seraHp < r.seraMax, "D5b: sem alvo, os insetos batem na própria Sera (dano real)")

print("== D6: Swarm + Poison Mist (multidão) ==")
loadScen("scenarios/Sera - 6 Swarm + Poison Mist.json")
r = run(16)
check(r.sumCasts >= 1 and r.maxSum == 5, "D6a: invoca a Legião (5 insetos)")
check(r.poison, "D6b: também solta Poison Mist (AoE, 2+ mobs)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
