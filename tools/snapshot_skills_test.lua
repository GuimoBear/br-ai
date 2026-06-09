-- snapshot_skills_test.lua — filhos sintéticos de skill no snapshot (PLANO-SKILLS-NO-NO S1).
-- tree.snapshot(node, bb) anexa entradas kind="skillRef" após cada ação automática de skill,
-- marca skillState no nó-ação, herda `off`, destaca a ativa (activeId) e é RETROCOMPATÍVEL
-- (sem bb => nenhum skillRef). Uso: texlua tools/snapshot_skills_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local C, S = BRAI.const, BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function bbFor(homun, base, intentSkill)
  return { self = { homunType = homun }, config = { BaseHomunType = base or 0 },
    intent = intentSkill and { kind = "skill", skill = intentSkill } or nil }
end
-- índice do 1º nó-ação com aquele name; lista os skillRef logo após (depth = ação.depth+1)
local function actionAt(snap, name)
  for i, e in ipairs(snap) do if e.kind == "action" and e.name == name then return i, e end end
end
local function refsAfter(snap, i)
  local out = {}; local d = snap[i].depth
  for j = i + 1, #snap do
    local e = snap[j]
    if e.kind == "skillRef" and e.depth == d + 1 then out[#out + 1] = e
    elseif e.depth <= d then break end
  end
  return out
end

local spec = { type = "selector", children = {
  { type = "action", name = "UseAoESkill" },
  { type = "action", name = "UseMainSkill" },
  { type = "action", name = "UseHealOwner" },
} }
local tree = BRAI.tree.build(spec)

BRAI.setSkillChoice({ choices = {} })

-- ===== (1) Dieter: AoE com 2 filhos, mainAtk/heal missing =====
print("== Dieter: filhos sintéticos ==")
local snap = BRAI.tree.snapshot(tree, bbFor(C.DIETER))
local ai, ae = actionAt(snap, "UseAoESkill")
check(ae and ae.skillState == "ok", "UseAoESkill: skillState ok no nó-ação")
local refs = refsAfter(snap, ai)
check(#refs == 2, "UseAoESkill: 2 filhos skillRef (Lava Slide + Blast Forge)")
check(refs[1].label:find("Lava Slide") and refs[1].skillId == S.MH_LAVA_SLIDE, "filho 1 = Lava Slide (com skillId)")
check(refs[2].label:find("Blast Forge"), "filho 2 = Blast Forge")
local mi, me = actionAt(snap, "UseMainSkill")
check(me.skillState == "missing", "UseMainSkill (Dieter): skillState missing")
local mr = refsAfter(snap, mi)
check(#mr == 1 and mr[1].skillState == "missing" and mr[1].label:find("não tem"), "missing: 1 filho com aviso 'não tem'")
local hi = actionAt(snap, "UseHealOwner")
check(refsAfter(snap, hi)[1].skillState == "missing", "Dieter cura do dono: missing (sem base)")

-- ===== (2) estado none (papel esvaziado) =====
print("== none (papel esvaziado) ==")
BRAI.setSkillChoice({ choices = { [tostring(C.DIETER)] = { aoeAtk = {} } } })
snap = BRAI.tree.snapshot(tree, bbFor(C.DIETER))
local _, ae2 = actionAt(snap, "UseAoESkill")
check(ae2.skillState == "none", "UseAoESkill esvaziada: skillState none")
local nr = refsAfter(snap, (actionAt(snap, "UseAoESkill")))
check(#nr == 1 and nr[1].skillState == "none" and nr[1].label:find("nenhuma skill"), "none: 1 filho 'nenhuma skill selecionada'")
BRAI.setSkillChoice({ choices = {} })

-- ===== (3) destaque ao vivo (activeId) =====
print("== activeId acende ==")
snap = BRAI.tree.snapshot(tree, bbFor(C.DIETER, 0, S.MH_BLAST_FORGE))
refs = refsAfter(snap, (actionAt(snap, "UseAoESkill")))
check(refs[1].active == false and refs[2].active == true, "só o Blast Forge (intent) acende (active=true)")

-- ===== (4) cura do dono OK (Lif) =====
print("== Lif cura do dono ok ==")
snap = BRAI.tree.snapshot(tree, bbFor(C.LIF))
local lh = actionAt(snap, "UseHealOwner")
check(snap[lh].skillState == "ok" and #refsAfter(snap, lh) == 1, "Lif cura do dono: ok, 1 filho skill")

-- ===== (5) herda off de nó-ação desativado =====
print("== off herdado ==")
local spec2 = { type = "selector", children = { { type = "action", name = "UseAoESkill", disabled = true } } }
local t2 = BRAI.tree.snapshot(BRAI.tree.build(spec2), bbFor(C.DIETER))
local di = actionAt(t2, "UseAoESkill")
check(t2[di].off == true, "ação desativada: off=true")
local dr = refsAfter(t2, di)
check(#dr == 2 and dr[1].off == true and dr[2].off == true, "filhos skillRef herdam off=true")

-- ===== (6) retrocompat: sem bb => nenhum skillRef =====
print("== retrocompat (sem bb) ==")
local plain = BRAI.tree.snapshot(tree)
local cnt = 0; for _, e in ipairs(plain) do if e.kind == "skillRef" then cnt = cnt + 1 end end
check(cnt == 0, "snapshot(tree) sem bb: 0 skillRef (comportamento atual)")
check(#plain == 4, "snapshot(tree) sem bb: 4 nós (selector + 3 ações)")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
