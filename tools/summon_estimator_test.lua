-- summon_estimator_test.lua — Fase 1: estimador da legião da Sera (Summon Legion).
-- Cobre L1..L8 (PLANO-INVOCACOES-SERA.md §2 e §11). Espelha o padrão dos testes da Eleanor.
-- Uso: texlua tools/summon_estimator_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local sys = BRAI.skillsys

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function legion() return BRAI.sim.bb.self.legion end
local function nmon() return #BRAI.sim.bb.monsters end
local function nsum() return #BRAI.sim.bb.summons end

local SERA = C.SERA

-- monstro normal (etype mundano) ou "inseto invocado" (homunType in 2158..2160)
local function mob(id, x, opts)
  opts = opts or {}
  return { id = id, kind = "monster", x = x, y = 20, hp = opts.hp or 5000, maxhp = opts.hp or 5000,
    atk = 0, aggro = 12, aggressive = false, atkInterval = 100000,
    etype = opts.etype or 1042, homunType = opts.homunType }
end

local function scen(opts)
  opts = opts or {}
  local ents = {
    { id = 1, kind = "owner", x = 5, y = 20, hp = 100000, maxhp = 100000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000, sp = 9000, maxsp = 9000,
      homunType = opts.htype or SERA },
  }
  for _, e in ipairs(opts.mobs or {}) do ents[#ents + 1] = e end
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
    config = { BaseHomunType = opts.base or 0, FleeHP = 0 },
    homunType = opts.htype or SERA, baseType = opts.base or 0, entities = ents }
end

local idleTree = { type = "action", name = "Idle" }

print("== L1: legião contada por tipo de mob; excluída de bb.monsters ==")
disp("load", scen({ mobs = {
  mob(200, 24, { homunType = 2158 }), mob(201, 25, { homunType = 2159 }), mob(202, 26, { homunType = 2160 }),
  mob(300, 28), mob(301, 29),
} })); disp("setTree", idleTree)
disp("step")
check(legion() ~= nil and legion().count == 3, "L1a: legion.count == 3 (insetos por tipo)")
check(legion().raw == 3, "L1b: raw == 3")
check(nsum() == 3, "L1c: bb.summons tem os 3 insetos")
check(nmon() == 2, "L1d: bb.monsters só os 2 normais (legião excluída do alvo)")

print("== L2: não-Sera não cria legion; insetos viram inimigos comuns ==")
disp("load", scen({ htype = C.FILIR, mobs = {
  mob(200, 24, { homunType = 2158 }), mob(201, 25, { homunType = 2159 }), mob(300, 28),
} })); disp("setTree", idleTree)
disp("step")
check(legion() == nil, "L2a: Filir não tem legion (estimador desligado)")
check(nmon() == 3, "L2b: os 3 viram monstros normais (sem exclusão)")

print("== L3: alive por TIMER (markUsed) mesmo sem ver os bichos ==")
disp("load", scen({})); local bb = BRAI.sim.bb
sys.markUsed(bb, SID.MH_SUMMON_LEGION, 5)
disp("step")
check(legion().raw == 0, "L3a: raw == 0 (nenhum inseto visível)")
check(legion().alive == true, "L3b: alive por timer (now < expiresAt)")

print("== L4: expiração -> alive == false ==")
disp("load", scen({})); bb = BRAI.sim.bb
bb.persist.legion = { expiresAt = bb:now() + 10, level = 5, hist = {} }
disp("step"); disp("step")   -- avança além da janela (a percepção roda no início do tick)
check(legion().alive == false, "L4: legião expirada e sem insetos -> alive false")

print("== L5: timer registrado/atualizado ao (re)invocar ==")
disp("load", scen({})); bb = BRAI.sim.bb
sys.markUsed(bb, SID.MH_SUMMON_LEGION, 3)
check(bb.persist.legion.level == 3, "L5a: nível 3 registrado")
check(bb.persist.legion.expiresAt == bb:now() + sys.duration(SID.MH_SUMMON_LEGION, 3), "L5b: expiresAt = now + dur(lv3)=40s")
sys.markUsed(bb, SID.MH_SUMMON_LEGION, 5)
check(bb.persist.legion.level == 5, "L5c: re-summon atualiza p/ nível 5")
check(bb.persist.legion.expiresAt == bb:now() + sys.duration(SID.MH_SUMMON_LEGION, 5), "L5d: expiresAt = now + dur(lv5)=60s")

print("== L6: perda de visão de 1 tick NÃO derruba alive (bug A3 da AzzyAI) ==")
disp("load", scen({ mobs = {
  mob(200, 24, { homunType = 2158 }), mob(201, 25, { homunType = 2158 }), mob(202, 26, { homunType = 2158 }),
} })); disp("setTree", idleTree)
sys.markUsed(BRAI.sim.bb, SID.MH_SUMMON_LEGION, 5)
disp("step")
check(legion().raw == 3 and legion().alive == true, "L6a: 3 insetos vistos, alive")
disp("removeMonster", { id = 200 }); disp("removeMonster", { id = 201 }); disp("removeMonster", { id = 202 })
disp("step")
check(legion().raw == 0, "L6b: insetos saíram de vista (raw 0)")
check(legion().alive == true, "L6c: alive permanece por timer (não re-summona à toa) — A3")

print("== L7: re-load zera o estimador ==")
disp("load", scen({ mobs = { mob(200, 24, { homunType = 2158 }) } })); disp("setTree", idleTree)
sys.markUsed(BRAI.sim.bb, SID.MH_SUMMON_LEGION, 5); disp("step")
disp("load", scen({}))
check(legion() == nil or (legion().raw == 0 and legion().alive == false), "L7: nova bb sem legião ativa")

print("== L8: suavização segura a contagem por LegionSmoothTicks ==")
disp("load", scen({ mobs = {
  mob(200, 24, { homunType = 2158 }), mob(201, 25, { homunType = 2158 }),
} })); disp("setTree", idleTree)
disp("step")
check(legion().count == 2, "L8a: count 2")
disp("removeMonster", { id = 200 })
disp("step")
check(legion().raw == 1 and legion().count == 2, "L8b: count suavizado mantém 2 por 1 tick (raw 1)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
