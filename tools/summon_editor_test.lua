-- summon_editor_test.lua — Fase 5: contrato do sub-painel de invocação (summonInfo)
-- + validação de setSummonChoice + fluxo da config global p/ a decisão. texlua tools/summon_editor_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local ST, sera = BRAI.status, BRAI.sera

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

print("== F1: summonInfo (dados do sub-painel da tela Skills) ==")
local si = disp("summonInfo", { homunType = C.SERA })
check(si.hasSummon == true and si.skill == SID.MH_SUMMON_LEGION, "F1a: Sera tem invocação (Summon Legion)")
check(si.name == "Summon Legion", "F1b: nome iRO")
check(#si.perLevel == 5, "F1c: catálogo com 5 níveis")
check(si.perLevel[1].count == 3 and si.perLevel[1].name == "Hornet" and si.perLevel[1].duration == 20000, "F1d: nv1 = 3 Hornet, 20s")
check(si.perLevel[5].count == 5 and si.perLevel[5].name == "Luciola Vespa" and si.perLevel[5].duration == 60000, "F1e: nv5 = 5 Luciola, 60s")
local byKey = {}; for _, f in ipairs(si.fields) do byKey[f.key] = f end
check(#si.fields == 5 and byKey.level and byKey.resummon and byKey.minCount and byKey.minMobCount and byKey.vsBossOnly, "F1f: 5 campos (level/resummon/minCount/minMobCount/vsBossOnly)")
check(byKey.resummon.type == "enum" and #byKey.resummon.options == 3, "F1g: resummon = enum com 3 políticas")
check(type(byKey.level.help) == "string" and #byKey.level.help > 10, "F1h: cada campo traz texto de ajuda (documentação §3.1)")

print("== F2: não-Sera não tem invocação ==")
check(disp("summonInfo", { homunType = C.FILIR }).hasSummon == false, "F2: Filir sem invocação (painel não aparece)")

print("== F3: setSummonChoice valida e persiste ==")
disp("setSummonChoice", { choices = { ["50"] = { level = 3, resummon = "keepFull", minCount = 2, minMobCount = 2, vsBossOnly = true, lixo = 99 } } })
local cfg = BRAI.summonChoiceFor(C.SERA)
check(cfg.level == 3 and cfg.resummon == "keepFull" and cfg.minCount == 2 and cfg.minMobCount == 2 and cfg.vsBossOnly == true, "F3a: campos válidos persistidos")
check(cfg.lixo == nil, "F3b: campo desconhecido ignorado")
disp("setSummonChoice", { choices = { ["50"] = { level = 99, resummon = "xpto" } } })
local cfg2 = BRAI.summonChoiceFor(C.SERA)
check(cfg2.level == nil and cfg2.resummon == nil, "F3c: valores inválidos rejeitados (level 99 / resummon xpto)")

print("== F4: config global flui p/ a decisão (UseSeraLegion sem params do nó) ==")
local function prepSera(alive, cnt)
  disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, homunType = C.SERA, baseType = 0, config = { UseSummon = true },
    entities = { { id = 1, kind = "owner", x = 2, y = 20, hp = 1000, maxhp = 1000 },
      { id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000, sp = 9000, maxsp = 9000, homunType = C.SERA },
      { id = 200, kind = "monster", x = 24, y = 20, hp = 100000, maxhp = 100000, atk = 0, aggro = 12, etype = 1042 } } })
  local bb = BRAI.sim.bb; bb.target = 200
  for _, m in ipairs(bb.monsters) do if m.id == 200 then bb.targetInfo = m end end
  bb.self.legion = { count = cnt, raw = cnt, alive = alive, expiresAt = alive and (bb:now() + 100000) or 0, level = 5, ids = {} }
  bb:clearIntent(); return bb
end
disp("setSummonChoice", { choices = {} })
check(sera.decide(prepSera(true, 3), nil) == ST.FAILURE, "F4a: sem config -> default onExpire não reforça legião viva")
disp("setSummonChoice", { choices = { ["50"] = { resummon = "keepFull" } } })
check(sera.decide(prepSera(true, 3), nil) == ST.SUCCESS, "F4b: config global keepFull -> reforça (UseSummon/nó sem params)")
check(sera.decide(prepSera(true, 3), { resummon = "onExpire" }) == ST.FAILURE, "F4c: params do nó têm precedência sobre a config global")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
