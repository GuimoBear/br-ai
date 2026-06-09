-- snapshot_label_test.lua — tree.snapshot emite rótulos LEGÍVEIS p/ o simulador:
-- título do registry p/ folhas/check; nome PT do tipo p/ compostos/decoradores (mesmo
-- quando o motor põe um default tipo "parallel:all"/"cooldown:1000"/"alvo?"); rótulo do
-- usuário tem precedência; o código vai no campo `name`. [UX nomes legíveis]
-- Uso: texlua tools/snapshot_label_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end

local spec = { type = "selector", children = {
  { type = "sequence", children = {
    { type = "condition", name = "HpBelow", params = { pct = 40 } },
    { type = "action", name = "UseAoESkill" },
  } },
  { type = "parallel", policy = "all", children = { { type = "action", name = "Idle" } } },
  { type = "cooldown", ms = 1000, child = { type = "action", name = "Flee" } },
  { type = "limiter", max = 3, child = { type = "action", name = "Idle" } },
  { type = "inverter", child = { type = "action", name = "Idle" } },
  { type = "succeeder", child = { type = "action", name = "Idle" } },
  { type = "check", name = "HasValidTarget", child = { type = "action", name = "AttackTarget" } },
  { type = "monsterCheck", group = 1, child = { type = "action", name = "AttackTarget" } },
  { type = "selector", label = "MEU RAMO", children = { { type = "action", name = "Idle" } } },
} }

local tree = BRAI.tree.build(spec)
local snap = BRAI.tree.snapshot(tree)
local labels, byName = {}, {}
for _, n in ipairs(snap) do labels[n.label] = (labels[n.label] or 0) + 1; if n.name then byName[n.name] = n.label end end
local function has(l) return labels[l] and labels[l] > 0 end

print("== rótulos legíveis no snapshot ==")
-- compostos/decoradores -> nome PT (NÃO o default cru do motor)
check(has("Seletor"),   "selector -> Seletor")
check(has("Sequência"), "sequence -> Sequência")
check(has("Paralelo"),  "parallel (sem rótulo) -> Paralelo (não 'parallel:all')")
check(has("Recarga"),   "cooldown (sem rótulo) -> Recarga (não 'cooldown:1000')")
check(has("Limitador"), "limiter (sem rótulo) -> Limitador (não 'limiter:3')")
check(has("Inverter"),  "inverter -> Inverter")
check(has("Sucesso"),   "succeeder -> Sucesso")
check(has("Monstro"),   "monsterCheck (sem rótulo) -> Monstro (não 'alvo?')")
check(has("MEU RAMO"),  "rótulo do usuário tem precedência (MEU RAMO)")
-- folhas/check -> título do registry
check(byName.HpBelow == "HP do homúnculo (abaixo)", "folha HpBelow -> título legível")
check(byName.UseAoESkill == "Skill em área (AoE)", "folha UseAoESkill -> título legível")
check(byName.HasValidTarget == "Tem alvo válido", "check HasValidTarget -> título da condição")
-- NENHUM rótulo cru/default vaza
local leaked = {}
for l in pairs(labels) do
  if l:sub(1,1) == "?" or l:sub(1,1) == "!" or l:find(":") or l == "alvo?"
     or l == "parallel" or l == "cooldown" or l == "limiter" then leaked[#leaked+1] = l end
end
check(#leaked == 0, "nenhum rótulo cru/default vaza [" .. table.concat(leaked, ", ") .. "]")
-- o código (name) é exposto p/ a dica
check(byName.UseAoESkill ~= nil and byName.HpBelow ~= nil, "snapshot expõe `name` (código) das folhas")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
