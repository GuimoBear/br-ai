-- leaf_meta.lua — nomes LEGÍVEIS (PT) e GRUPOS das folhas (condições/ações) p/ a UI
-- (editor + simulador). O CÓDIGO (name) é mantido como identificador; isto só muda o
-- TEXTO exibido e organiza a paleta em grupos. Aplicado em registry.meta (export p/ o
-- editor; usado pelo snapshot p/ o simulador). Carregado no bootstrap após os behaviors.
BRAI = BRAI or {}
local reg = BRAI.registry

-- ordem dos grupos na paleta (o editor segue esta ordem)
BRAI.leafGroupOrder = {
  "Vida (HP/SP)", "Ameaça", "Alvo", "Ataque", "Movimento",
  "Skills ofensivas", "Buffs, cura & defesa", "Skills (manual)", "Dono", "Eleanor & Sera",
}

-- [name] = { title = <PT curto>, group = <grupo> }
BRAI.leafMeta = {
  -- ===== Condições =====
  -- Vida (HP/SP)
  HpBelow          = { title = "HP do homúnculo (abaixo)", group = "Vida (HP/SP)" },
  HpAbove          = { title = "HP do homúnculo (acima)",  group = "Vida (HP/SP)" },
  SpAbove          = { title = "SP do homúnculo (acima)",  group = "Vida (HP/SP)" },
  OwnerHpBelow     = { title = "HP do dono (abaixo)",      group = "Vida (HP/SP)" },
  OwnerHpAbove     = { title = "HP do dono (acima)",       group = "Vida (HP/SP)" },
  -- Ameaça
  BeingAttacked    = { title = "Homúnculo é alvo de monstro",  group = "Ameaça" },
  SelfUnderAttack  = { title = "Homúnculo sob ataque (≥N)",    group = "Ameaça" },
  OwnerUnderAttack = { title = "Dono sob ataque (≥N)",         group = "Ameaça" },
  Mobbed           = { title = "Cercado / berserk (≥N)",       group = "Ameaça" },
  ShouldFlee       = { title = "Deve fugir (HP baixo + ataque)", group = "Ameaça" },
  -- Alvo
  HasValidTarget   = { title = "Tem alvo válido",           group = "Alvo" },
  InAttackRange    = { title = "Alvo no alcance de ataque", group = "Alvo" },
  CanEngage        = { title = "Pode engajar",              group = "Alvo" },
  TargetIsBoss     = { title = "Alvo é Boss/MVP",           group = "Alvo" },
  -- Dono
  HasOwnerCommand  = { title = "Há comando do dono",     group = "Dono" },
  TooFarFromOwner  = { title = "Longe demais do dono",   group = "Dono" },
  -- Eleanor & Sera
  StyleIs          = { title = "Estilo atual (Eleanor)",        group = "Eleanor & Sera" },
  SafeToGrapple    = { title = "Seguro p/ Agarrão (Eleanor)",   group = "Eleanor & Sera" },
  LegionActive     = { title = "Legião ativa (Sera)",          group = "Eleanor & Sera" },
  LegionBelow      = { title = "Legião abaixo de N insetos",   group = "Eleanor & Sera" },
  LegionExpiring   = { title = "Legião expirando (Sera)",      group = "Eleanor & Sera" },

  -- ===== Ações =====
  -- Alvo
  AcquireTarget        = { title = "Escolher alvo",            group = "Alvo" },
  AcquireOwnerAttacker = { title = "Mirar quem ataca o dono",  group = "Alvo" },
  ReacquireIfBetter    = { title = "Trocar p/ alvo melhor",    group = "Alvo" },
  -- Ataque
  AttackTarget     = { title = "Atacar (ataque normal)", group = "Ataque" },
  ChaseTarget      = { title = "Perseguir o alvo",       group = "Ataque" },
  DanceAttack      = { title = "Atacar dançando",        group = "Ataque" },
  -- Movimento
  MoveToOwner      = { title = "Seguir o dono",           group = "Movimento" },
  Flee             = { title = "Fugir",                   group = "Movimento" },
  Kite             = { title = "Kite (manter distância)", group = "Movimento" },
  Idle             = { title = "Ficar parado",            group = "Movimento" },
  IdleWalk         = { title = "Perambular ocioso",       group = "Movimento" },
  -- Skills ofensivas
  UseMainSkill     = { title = "Skill principal (alvo único)", group = "Skills ofensivas" },
  UseAoESkill      = { title = "Skill em área (AoE)",         group = "Skills ofensivas" },
  -- Buffs, cura & defesa
  UseOffensiveBuff = { title = "Buff ofensivo",              group = "Buffs, cura & defesa" },
  UseDefensiveBuff = { title = "Buff defensivo",             group = "Buffs, cura & defesa" },
  UseHealSelf      = { title = "Curar a si",                 group = "Buffs, cura & defesa" },
  UseHealOwner     = { title = "Curar o dono",               group = "Buffs, cura & defesa" },
  UseOwnerBuff     = { title = "Buff no dono (Painkiller)",   group = "Buffs, cura & defesa" },
  UseCastling      = { title = "Castling (trocar c/ o dono)", group = "Buffs, cura & defesa" },
  -- Skills (manual)
  UseSkill         = { title = "Usar skill específica", group = "Skills (manual)" },
  UseSkillBuff     = { title = "Usar buff específico",  group = "Skills (manual)" },
  -- Dono
  HandleOwnerCommand = { title = "Executar comando do dono", group = "Dono" },
  RescueOwner        = { title = "Resgatar o dono",          group = "Dono" },
  -- Eleanor & Sera
  SetStyle          = { title = "Trocar estilo (Eleanor)",       group = "Eleanor & Sera" },
  UseCombo          = { title = "Combo (sequência)",            group = "Eleanor & Sera" },
  UseEleanorOffense = { title = "Ofensiva da Eleanor",          group = "Eleanor & Sera" },
  UseSummon         = { title = "Invocar Legião",               group = "Eleanor & Sera" },
  UseSeraLegion     = { title = "Invocar/manter Legião (Sera)", group = "Eleanor & Sera" },
}

-- aplica em registry.meta (preserva desc/params/optional; só ADICIONA title/group)
if reg and reg.meta then
  for name, m in pairs(BRAI.leafMeta) do
    if reg.meta[name] then reg.meta[name].title = m.title; reg.meta[name].group = m.group end
  end
end

return BRAI.leafMeta
