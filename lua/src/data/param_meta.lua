-- param_meta.lua — rótulos LEGÍVEIS (PT) + ajuda curta dos PARÂMETROS (knobs das ações,
-- params das folhas e da Config), para a UI (editor + simulador). Espelha leaf_meta.lua:
-- o CÓDIGO (key) continua sendo o identificador salvo/gerado; isto só muda o TEXTO exibido.
-- Exposto em BRAI.paramMeta; consumido por paramConfig/overrideConfig (skill_params.lua) e
-- pelo editor (modal de Parâmetros, sobreposição em Skills e campos do inspetor).
BRAI = BRAI or {}

-- [key] = { label = <rótulo PT curto>, help = <dica de uma linha> }
BRAI.paramMeta = {
  -- ===== Knobs das skills (modal "Parâmetros") =====
  UseAttackSkill       = { label = "Usar skill de ataque",        help = "Se desligado, este papel usa só o ataque normal (sem skill ofensiva)." },
  AutoMobMode          = { label = "Modo de AoE automática",      help = "0 desliga a skill em área automática; 1 liga." },
  AutoMobCount         = { label = "Mín. de alvos p/ AoE",        help = "Quantos monstros agrupados para valer a pena a skill em área (quem tem ataque de alvo único)." },
  AttackSkillReserveSP = { label = "Reserva de SP (ataque)",      help = "Não usa a skill de ataque se o SP cair abaixo desta reserva." },
  AoEFixedLevel        = { label = "Nível fixo da AoE",           help = "Trava o nível da skill em área. 0 = usa o nível conhecido." },
  AoEMaximizeTargets   = { label = "Mirar no aglomerado",         help = "Centraliza a área onde houver mais monstros." },
  AttackRange          = { label = "Alcance de ataque",           help = "Distância considerada corpo a corpo para a skill principal." },
  UseHomunSSkillAttack = { label = "Usar skill ao alcance",       help = "Permite a skill principal quando o alvo já está no alcance." },
  UseHomunSSkillChase  = { label = "Usar skill perseguindo",      help = "Permite a skill principal enquanto se aproxima do alvo." },
  UseAutoHeal          = { label = "Cura automática",             help = "Liga a cura automática deste papel." },
  HealSelfHP           = { label = "Curar a si abaixo de (HP%)",  help = "Cura o próprio homúnculo quando o HP% fica abaixo deste valor." },
  HealOwnerHP          = { label = "Curar o dono abaixo de (HP%)",help = "Cura o dono quando o HP% dele fica abaixo deste valor." },
  UseOffensiveBuff     = { label = "Manter buffs ofensivos",      help = "Recasta automaticamente os buffs ofensivos ao expirar." },
  UseDefensiveBuff     = { label = "Manter buffs defensivos",     help = "Recasta automaticamente os buffs defensivos ao expirar." },
  UseOwnerBuff         = { label = "Buffar o dono",               help = "Mantém o buff no dono (ex.: Painkiller)." },
  UseCastling          = { label = "Usar Castling",               help = "Liga o Castling (trocar de posição com o dono)." },
  CastleDefendThreshold= { label = "Mín. de mobs p/ Castling",    help = "Quantos monstros no dono para disparar o Castling." },

  -- ===== Params das folhas (inspetor) =====
  pct        = { label = "Porcentagem (%)",            help = "Limiar de HP/SP em porcentagem." },
  count      = { label = "Quantidade (N)",             help = "Número mínimo (ex.: de monstros atacando)." },
  dist       = { label = "Distância (células)",        help = "Distância em células." },
  by         = { label = "Prioridade de alvo",         help = "Como escolher o alvo: mais próximo, menor HP ou quem ataca o dono." },
  skill      = { label = "Skill",                      help = "A skill usada por este nó." },
  level      = { label = "Nível",                      help = "Nível de execução da skill." },
  on         = { label = "Centro do cast (no solo)",   help = "Onde centrar a skill de área: no monstro-alvo ou no dono." },
  ms         = { label = "Tempo (ms)",                 help = "Duração em milissegundos." },
  max        = { label = "Máximo de usos",             help = "Quantas vezes o filho pode dar certo." },
  key        = { label = "Chave (agrupa o limite)",    help = "Compartilha o limite entre nós com a mesma chave." },
  radius     = { label = "Raio (células)",             help = "Raio em células." },
  limit      = { label = "Limite de ameaça",           help = "Máximo de monstros perto permitido." },
  style      = { label = "Estilo",                     help = "Estilo de combate da Eleanor (Combate/Agarrão)." },
  combo      = { label = "Combo",                      help = "Qual cadeia de combo." },
  window     = { label = "Janela do combo (ms)",       help = "Tempo máximo entre um golpe e o próximo." },
  gate       = { label = "Liga ao flag (Config)",      help = "Nome de uma chave da Config que liga/desliga este ramo." },
  comboSpheres = { label = "Barragem de esferas",      help = "Esferas mínimas estimadas antes de iniciar o combo." },
  grappleThreatLimit = { label = "Limite p/ Agarrão",  help = "Máximo de monstros perto para liberar o Agarrão." },
  minGap     = { label = "Intervalo mín. (ms)",        help = "Espaça os golpes do combo p/ reduzir lag." },
  allowStyleSwitch = { label = "Trocar de estilo",     help = "Permite a Eleanor trocar de estilo automaticamente." },
  resummon   = { label = "Re-invocação (política)",    help = "onExpire (só ao expirar), keepFull (manter cheio) ou minCount." },
  minCount   = { label = "Mín. de insetos",            help = "Número mínimo de insetos na Legião (política minCount)." },
  minMobCount= { label = "Mín. de inimigos",           help = "Só invoca com pelo menos N inimigos por perto." },
  vsBossOnly = { label = "Só em Boss/MVP",             help = "Invoca apenas quando o alvo é Boss/MVP." },
  step       = { label = "Passo (células)",            help = "Quantas células anda por vez." },
  bounds     = { label = "Limite do dono (células)",   help = "Não se afasta além desta distância do dono." },
  blockIf    = { label = "Bloquear se (flag)",         help = "Chave da Config que, se ligada, bloqueia o ataque normal." },
  giveUp     = { label = "Desistir após (ticks)",      help = "Desiste de perseguir após N ticks sem progresso (0 = nunca)." },
  reset      = { label = "Reiniciar ao trocar de alvo",help = "Zera o intervalo quando o alvo muda." },
  interval   = { label = "Intervalo entre usos (ms)",  help = "Tempo mínimo entre usos desta skill (0 = sem limite)." },
}

return BRAI.paramMeta
