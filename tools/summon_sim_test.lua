-- summon_sim_test.lua — Fase 3: atores invocados no simulador (spawn + IA + TTL + revide).
-- Cobre SM1..SM8 (PLANO-INVOCACOES-SERA.md §4 e §11). Uso: texlua tools/summon_sim_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function ent(id) return BRAI.sim.world.entities[id] end
local function summons()
  local n, list = 0, {}
  for _, e in pairs(BRAI.sim.world.entities) do if e.summon then n = n + 1; list[#list + 1] = e end end
  return n, list
end

local function scen(o)
  o = o or {}
  local ents = {
    { id = 1, kind = "owner", x = 2, y = 20, hp = 100000, maxhp = 100000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = o.hp or 100000, maxhp = o.hp or 100000, sp = 9000, maxsp = 9000, homunType = C.SERA },
  }
  if o.mon ~= false then
    local m = o.mon or {}
    ents[#ents + 1] = { id = 200, kind = "monster", x = m.x or 25, y = 20, hp = m.hp or 100000, maxhp = m.hp or 100000,
      atk = m.atk or 0, aggro = m.aggro or 12, aggressive = m.aggressive or false, atkInterval = m.atkInterval or 500, etype = 1042 }
  end
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
    config = { BaseHomunType = 0, FleeHP = 0 }, homunType = C.SERA, baseType = 0, entities = ents }
end
local function legionTree(level)
  return { type = "sequence", children = {
    { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
    { type = "action", name = "UseSeraLegion", params = level and { level = level } or nil } } }
end

print("== SM1: spawn — quantidade e tipo por nível ==")
disp("load", scen({ mon = { x = 25 } })); disp("setTree", legionTree(5)); disp("step")
check(summons() == 5, "SM1a: nível 5 invoca 5 insetos")
disp("load", scen({ mon = { x = 25 } })); disp("setTree", legionTree(1)); disp("step")
local n, list = summons()
check(n == 3, "SM1b: nível 1 invoca 3 insetos")
check(list[1] and list[1].homunType == 2158, "SM1c: nível 1 -> Hornet (mob 2158)")

print("== SM8: cast de summon NÃO dá dano direto no alvo (A6) ==")
disp("load", scen({ mon = { x = 27, hp = 5000 } })); disp("setTree", legionTree(5))
local s = disp("step")
check(s.intent and s.intent.skill == SID.MH_SUMMON_LEGION, "SM8a: summon castado")
check(ent(200) and ent(200).hp == 5000, "SM8b: alvo do cast não perde HP no cast (A6)")

print("== SM2: insetos causam dano ao alvo ao longo dos ticks ==")
disp("load", scen({ mon = { x = 24, hp = 100000 } })); disp("setTree", legionTree(5))
for _ = 1, 20 do disp("step") end
check(ent(200) and ent(200).hp < 100000, "SM2: HP do alvo cai (swarm atacando)")

print("== SM3: insetos copiam o alvo da mestra ==")
disp("load", scen({ mon = { x = 24 } })); disp("setTree", legionTree(5)); disp("step"); disp("step")
local _, l3 = summons(); local targeting = false
for _, e in ipairs(l3) do if e.target == 200 then targeting = true end end
check(targeting, "SM3: insetos miram o alvo da mestra (#200)")

print("== SM4: sem alvo do mestre -> insetos batem na Sera (dano real) ==")
disp("load", scen({ mon = { x = 24 }, hp = 100000 })); disp("setTree", legionTree(5)); disp("step")
disp("removeMonster", { id = 200 })   -- remove o alvo (zera bb.target tbm)
for _ = 1, 15 do disp("step") end
check(ent(100) and ent(100).hp < 100000, "SM4: Sera leva dano real dos próprios insetos sem alvo")

print("== SM5: expiração por TTL remove os insetos ==")
disp("load", scen({ mon = { x = 24 } })); disp("setTree", legionTree(5)); disp("step")
check(summons() == 5, "SM5a: 5 insetos vivos")
for _, e in pairs(BRAI.sim.world.entities) do if e.summon then e.bornAt = -1000000 end end
disp("step")
check(summons() == 0, "SM5b: insetos expiram por TTL e somem")

print("== SM6: morrem com a mestra ==")
disp("load", scen({ mon = { x = 24 } })); disp("setTree", legionTree(5)); disp("step")
check(summons() == 5, "SM6a: 5 insetos vivos")
local h = ent(100); h.hp = 0; h.motion = C.MOTION_DEAD
disp("step")
check(summons() == 0, "SM6b: insetos morrem com a Sera")

print("== SM7: monstros revidam nos insetos (HP do inseto cai / baixa) ==")
disp("load", scen({ mon = { x = 22, hp = 100000, atk = 500, aggressive = true, aggro = 12, atkInterval = 50 } }))
disp("setTree", legionTree(5))
for _ = 1, 15 do disp("step") end
local nn, l7 = summons(); local hurt = false
for _, e in ipairs(l7) do if e.hp < e.maxhp then hurt = true end end
check(hurt or nn < 5, "SM7: insetos sofrem dano dos monstros (HP cai ou houve baixa)")

print("== SM9: snapshot expõe o bloco 'sera' p/ a visualização ==")
disp("load", scen({ mon = { x = 24 } })); disp("setTree", legionTree(5))
local snp = disp("step")
check(snp.sera ~= nil, "SM9a: snapshot.sera presente p/ a Sera")
check(snp.sera and snp.sera.count == 5 and snp.sera.max == 5, "SM9b: count/max = 5/5 após invocar")
check(snp.sera and snp.sera.tier == "Luciola Vespa", "SM9c: tier do nível 5 = Luciola Vespa")
check(snp.sera and #snp.sera.members == 5, "SM9d: 5 membros (posição/HP/ttl)")
local snf = disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, homunType = C.FILIR, baseType = 0, config = {},
  entities = { { id = 1, kind = "owner", x = 2, y = 20, hp = 1000, maxhp = 1000 }, { id = 100, kind = "homun", x = 20, y = 20, hp = 1000, maxhp = 1000, sp = 100, maxsp = 100, homunType = C.FILIR } } })
check(snf.sera == nil, "SM9e: snapshot.sera ausente p/ não-Sera (Filir)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
