-- leaf_meta_test.lua — toda condição/ação registrada tem título PT + grupo (leaf_meta.lua),
-- registry.export() os expõe, títulos são únicos e grupos pertencem à ordem conhecida.
-- Uso: texlua tools/leaf_meta_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end

local meta = BRAI.registry.export()

-- 1) toda folha (condição/ação) tem title + group
local missing = {}
for name, m in pairs(meta) do
  if m.kind == "condition" or m.kind == "action" then
    if not (m.title and m.title ~= "") then missing[#missing+1] = name .. "(sem title)" end
    if not (m.group and m.group ~= "") then missing[#missing+1] = name .. "(sem group)" end
  end
end
check(#missing == 0, "toda folha tem title+group [" .. table.concat(missing, ", ") .. "]")

-- 2) grupos pertencem à ordem conhecida
local known = {}; for _, g in ipairs(BRAI.leafGroupOrder) do known[g] = true end
local badGroup = {}
for name, m in pairs(meta) do
  if (m.kind == "condition" or m.kind == "action") and m.group and not known[m.group] then badGroup[#badGroup+1] = name .. "=" .. tostring(m.group) end
end
check(#badGroup == 0, "grupos na ordem conhecida [" .. table.concat(badGroup, ", ") .. "]")

-- 3) títulos são ÚNICOS (sem ambiguidade na paleta)
local seen, dup = {}, {}
for name, m in pairs(meta) do
  if m.title then if seen[m.title] then dup[#dup+1] = m.title .. " (" .. name .. "/" .. seen[m.title] .. ")" else seen[m.title] = name end end
end
check(#dup == 0, "títulos únicos [" .. table.concat(dup, ", ") .. "]")

-- 4) spot-checks
check(meta.UseAoESkill and meta.UseAoESkill.title == "Skill em área (AoE)" and meta.UseAoESkill.group == "Skills ofensivas", "UseAoESkill título/grupo")
check(meta.OwnerHpBelow and meta.OwnerHpBelow.group == "Vida (HP/SP)", "OwnerHpBelow no grupo Vida (HP/SP)")
check(meta.AcquireTarget and meta.AcquireTarget.title == "Escolher alvo", "AcquireTarget título")
-- desc preservada (não sobrescrita)
check(meta.HpBelow and meta.HpBelow.desc and meta.HpBelow.desc ~= "", "desc preservada (HpBelow)")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
