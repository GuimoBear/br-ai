-- summon_decision_test.lua — Fase 2: nó UseSeraLegion (decisão de (re)invocar) + políticas.
-- Cobre D1..D9 (PLANO-INVOCACOES-SERA.md §3 e §11). Uso: texlua tools/summon_decision_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local ST, sera, sys = BRAI.status, BRAI.sera, BRAI.skillsys

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

-- m = opções do monstro: { x, homunType, boss, hp }
local function scen(o)
  o = o or {}
  local ents = {
    { id = 1, kind = "owner", x = 5, y = 20, hp = 100000, maxhp = 100000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000, sp = o.sp or 9000, maxsp = 9000, homunType = C.SERA },
  }
  local nid = 200
  for _, m in ipairs(o.mobs or { { x = 24 } }) do
    ents[#ents + 1] = { id = nid, kind = "monster", x = m.x or 24, y = 20,
      hp = m.hp or 100000, maxhp = m.hp or 100000, atk = 0, aggro = 12, aggressive = false,
      atkInterval = 100000, etype = m.etype or 1042, boss = m.boss, homunType = m.homunType }
    nid = nid + 1
  end
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
    config = { BaseHomunType = 0, FleeHP = 0, UseSummon = (o.useSummon ~= false) },
    homunType = C.SERA, baseType = 0, entities = ents }
end

-- prepara bb da Sera com alvo fixo (200) e legião controlada
local function prep(o)
  o = o or {}
  disp("load", scen(o))
  local bb = BRAI.sim.bb
  if o.target ~= false then
    bb.target = 200
    for _, m in ipairs(bb.monsters) do if m.id == 200 then bb.targetInfo = m end end
  end
  bb.self.legion = { count = o.count or 0, raw = o.count or 0, alive = (o.alive == true),
    expiresAt = (o.alive == true) and (bb:now() + 100000) or 0, level = 5, ids = {} }
  return bb
end
local function decide(bb, p) bb:clearIntent(); local r = sera.decide(bb, p); return r, bb.intent end

print("== D1: invoca com alvo e sem legião ativa (integração via árvore) ==")
disp("load", scen({})); disp("setTree", { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
  { type = "action", name = "UseSeraLegion" } } })
local s = disp("step")
check(s.intent and s.intent.skill == SID.MH_SUMMON_LEGION, "D1a: UseSeraLegion invoca Summon Legion")
local s2 = disp("step")
check(not (s2.intent and s2.intent.kind == "skill"), "D1b: não re-invoca no tick seguinte (legião viva, onExpire)")

print("== D2: política onExpire (padrão) ==")
local r = decide(prep({ alive = true }), {})
check(r == ST.FAILURE, "D2a: legião viva -> não invoca")
r = decide(prep({ alive = false }), {})
check(r == ST.SUCCESS, "D2b: legião expirada/zerada -> invoca")

print("== D3: política keepFull ==")
r = decide(prep({ alive = true, count = 5 }), { resummon = "keepFull" })
check(r == ST.FAILURE, "D3a: legião cheia (5/5) -> não invoca")
r = decide(prep({ alive = true, count = 3 }), { resummon = "keepFull" })
check(r == ST.SUCCESS, "D3b: legião parcial (3/5) viva -> reforça (keepFull)")

print("== D4: política minCount ==")
r = decide(prep({ alive = true, count = 3 }), { resummon = "minCount", minCount = 4 })
check(r == ST.SUCCESS, "D4a: 3 < minCount 4 -> invoca")
r = decide(prep({ alive = true, count = 4 }), { resummon = "minCount", minCount = 4 })
check(r == ST.FAILURE, "D4b: 4 >= minCount 4 -> não invoca")

print("== D5: nível (clamp; bug A1) ==")
local _, it = decide(prep({ alive = false }), { level = 2 })
check(it and it.level == 2, "D5a: level=2 respeitado")
_, it = decide(prep({ alive = false }), { level = 99 })
check(it and it.level == 5, "D5b: level inválido -> clampa p/ conhecido (5), não desliga")

print("== D6: vsBossOnly ==")
r = decide(prep({ alive = false, mobs = { { x = 24 } } }), { vsBossOnly = true })
check(r == ST.FAILURE, "D6a: alvo não-boss + vsBossOnly -> não invoca")
r = decide(prep({ alive = false, mobs = { { x = 24, boss = true } } }), { vsBossOnly = true })
check(r == ST.SUCCESS, "D6b: alvo boss + vsBossOnly -> invoca")

print("== D7: minMobCount ==")
r = decide(prep({ alive = false, mobs = { { x = 24 } } }), { minMobCount = 2 })
check(r == ST.FAILURE, "D7a: 1 inimigo < minMobCount 2 -> não invoca")
r = decide(prep({ alive = false, mobs = { { x = 23 }, { x = 25 } } }), { minMobCount = 2 })
check(r == ST.SUCCESS, "D7b: 2 inimigos no alcance -> invoca")

print("== D8: SP / desabilitado / sem alvo ==")
r = decide(prep({ alive = false, sp = 10 }), {})
check(r == ST.FAILURE, "D8a: SP < custo -> não invoca")
r = decide(prep({ alive = false, useSummon = false }), {})
check(r == ST.FAILURE, "D8b: config.UseSummon=false -> não invoca")
r = decide(prep({ alive = false, target = false }), {})
check(r == ST.FAILURE, "D8c: sem alvo -> não invoca")

print("== D9: AcquireTarget ignora a própria legião (exclusão da percepção) ==")
disp("load", scen({ mobs = { { x = 24, homunType = 2158 }, { x = 25, homunType = 2159 } } }))
disp("setTree", { type = "succeeder", child = { type = "action", name = "AcquireTarget" } })
disp("step")
check(BRAI.sim.bb.target == nil, "D9: só insetos invocados em vista -> sem alvo (não mira a legião)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
