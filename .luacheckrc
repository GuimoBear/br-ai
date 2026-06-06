-- .luacheckrc — configuração do linter (luacheck) do BR-AI.
-- O projeto inteiro vive sob o namespace global BRAI e fala com a API nativa do
-- cliente do RO por globais. Declaramos esses globais aqui para o lint focar em
-- bugs reais (typos, variáveis não usadas, shadowing) e não em ruído de estilo.

std = "max"               -- união de Lua 5.1..5.4 (o código roda em todas)
max_line_length = false   -- tabelas de dados (skills/perfis) usam linhas longas de propósito

-- Globais DEFINIDOS pelo próprio projeto (leitura+escrita).
globals = {
  "BRAI",          -- namespace global de todo o motor
  "BRAI_BASE",     -- raiz do runtime no cliente (definida no AI.lua)
  "SIM_DISPATCH",  -- ponto de entrada do simulador (runtime.lua)
  "AI",            -- função chamada pelo cliente do RO a cada tick (AI.lua)
}

-- API NATIVA do cliente do RO: o código só CHAMA; quem implementa é o jogo
-- (ou o mock do simulador via ro_api.lua).
read_globals = {
  "GetV", "GetActors", "GetTick", "GetMsg", "GetResMsg",
  "IsMonster", "IsBoss", "Move", "Attack",
  "SkillObject", "SkillGround", "TraceAI",
}

ignore = { "212", "213", "542" }   -- arg/loop var não usados e branch vazio intencional (idiomático)

-- Os testes (tools/) têm scaffolding com locais não usados/shadowing — toleramos lá,
-- mantendo o motor (lua/) sob lint estrito.
files["tools"] = { ignore = { "211", "311", "421", "431" } }

exclude_files = {
  "desktop/node_modules",
  "trees",                 -- só dados (tree.json) + pacotes gerados
}
