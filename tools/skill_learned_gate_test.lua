-- skill_learned_gate_test.lua — F1: percepção "possui a skill" via lvl no SIMULADOR.
-- O stub do GetV (runtime) decide pelo lvl do homún vs reqLevel (lua/src/sim, fora do dist).
-- sys.learned é só uma chamada nativa (fail-open). Uso: texlua tools/skill_learned_gate_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local sys = BRAI.skillsys
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function scn(lvl)
  local h = { id = 100, kind = "homun", x = 20, y = 20, hp = 100, maxhp = 100, sp = 1000, maxsp = 1000, homunType = C.DIETER }
  if lvl then h.lvl = lvl end
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
    entities = { { id = 1, kind = "owner", x = 10, y = 10, hp = 1000, maxhp = 1000 }, h } }
end
local function bb() return { self = { id = 100 }, persist = {}, now = function() return 0 end } end

print("== stub GetV(V_SKILLATTACKRANGE) por nível ==")
disp("load", scn(100))
check(BRAI.ro.getv(C.V_SKILLATTACKRANGE, 100, SID.MH_BLAST_FORGE) < 0, "lvl100: Blast Forge (req215) NÃO aprendida")
check(BRAI.ro.getv(C.V_SKILLATTACKRANGE, 100, SID.MH_SONIC_CLAW) >= 0, "lvl100: Sonic Claw (req100) aprendida")

print("== sys.learned (fail-open) ==")
check(sys.learned(bb(), SID.MH_BLAST_FORGE) == false, "lvl100: learned(Blast Forge)=false")
check(sys.learned(bb(), SID.MH_LAVA_SLIDE) == false, "lvl100: learned(Lava Slide req109)=false")
disp("load", scn(215))
check(sys.learned(bb(), SID.MH_BLAST_FORGE) == true, "lvl215: learned(Blast Forge)=true")
check(sys.learned(bb(), SID.MH_LAVA_SLIDE) == true, "lvl215: learned(Lava Slide)=true")
check(sys.learned(bb(), SID.HAMI_CASTLE) == true, "sem reqLevel (Castling base) => sempre 'possui'")
check(sys.learned(bb(), nil) == false, "skill nil => false")
disp("load", scn(nil))
check(sys.learned(bb(), SID.MH_BLAST_FORGE) == true, "lvl ausente (default 999) => Blast Forge aprendida")

print("== gate por skill (end-to-end via UseAoESkill) ==")
local SPEC = { type = "selector", children = {
  { type = "check", name = "HasValidTarget", child = { type = "action", name = "UseAoESkill" } },
  { type = "action", name = "AcquireTarget" },
  { type = "action", name = "Idle" },
} }
disp("setTree", SPEC)
local function combat(lvl)
  local ents = { { id = 1, kind = "owner", x = 10, y = 10, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 100, maxhp = 100, sp = 4000, maxsp = 4000, homunType = C.DIETER, lvl = lvl } }
  for i, pt in ipairs({ {21,20},{20,21},{21,21} }) do
    ents[#ents+1] = { id = 200+i, kind = "monster", x = pt[1], y = pt[2], hp = 600, maxhp = 600, atk = 3, aggro = 12, etype = 1042 }
  end
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = ents }
end
local function firstSkill()
  for i = 1, 15 do local st = disp("step"); if st.intent and st.intent.kind == "skill" then return st.intent.skill end end
  return nil
end

-- (A) prioridade [Blast Forge, Lava Slide]; Blast Forge "só se TIVER Blast Forge"
disp("setSkillChoice", { choices = { ["51"] = {
  aoeAtk = { SID.MH_BLAST_FORGE, SID.MH_LAVA_SLIDE },
  skillGate = { [tostring(SID.MH_BLAST_FORGE)] = { skill = SID.MH_BLAST_FORGE, negate = false } },
} } })
disp("load", combat(100)); check(firstSkill() == SID.MH_LAVA_SLIDE, "lvl100 sem Blast Forge -> Lava Slide (gate pula Blast Forge)")
disp("load", combat(215)); check(firstSkill() == SID.MH_BLAST_FORGE, "lvl215 com Blast Forge -> Blast Forge")

-- (B) negate: Lava Slide "só se NÃO TIVER Blast Forge" (lista só Lava Slide)
disp("setSkillChoice", { choices = { ["51"] = {
  aoeAtk = { SID.MH_LAVA_SLIDE },
  skillGate = { [tostring(SID.MH_LAVA_SLIDE)] = { skill = SID.MH_BLAST_FORGE, negate = true } },
} } })
disp("load", combat(100)); check(firstSkill() == SID.MH_LAVA_SLIDE, "negate lvl100 (sem Blast Forge) -> usa Lava Slide")
disp("load", combat(215)); check(firstSkill() == nil, "negate lvl215 (com Blast Forge) -> Lava Slide pulada (sem skill)")

disp("setSkillChoice", { choices = {} })   -- limpa override

print("== roleConfig expoe o gate por skill (p/ a UI) ==")
disp("setSkillChoice", { choices = { ["51"] = { aoeAtk = { SID.MH_BLAST_FORGE, SID.MH_LAVA_SLIDE },
  skillGate = { [tostring(SID.MH_BLAST_FORGE)] = { skill = SID.MH_BLAST_FORGE, negate = false } } } } })
local rc = disp("roleConfig", { homunType = 51, baseType = 0 })
local aoe; for _, r in ipairs(rc) do if r.key == "aoeAtk" then aoe = r end end
local bf; for _, e in ipairs(aoe and aoe.effective or {}) do if e.id == SID.MH_BLAST_FORGE then bf = e end end
check(bf and bf.gate and bf.gate.skill == SID.MH_BLAST_FORGE and bf.gate.negate == false, "roleConfig: Blast Forge expõe gate {skill,negate}")
local ls; for _, e in ipairs(aoe and aoe.effective or {}) do if e.id == SID.MH_LAVA_SLIDE then ls = e end end
check(ls and ls.gate == nil, "roleConfig: Lava Slide sem gate")
disp("setSkillChoice", { choices = {} })

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
