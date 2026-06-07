# Infra — versão estática (S3 + CloudFront, OIDC)

Passo-a-passo (uma vez) para o deploy automático do `dist-static/` pela Action
`.github/workflows/deploy-s3.yml`. Nada de chaves AWS longas: usamos **OIDC**.

## 1. Bucket S3 (privado, servido pelo CloudFront)
- Crie um bucket (ex.: `brai-app`), **Block Public Access = ON** (privado).
- Não precisa de "static website hosting": quem serve é o CloudFront.

## 2. CloudFront (cache + compressão + free tier)
- Crie uma distribuição com **Origin = o bucket S3** usando **OAC** (Origin Access Control)
  e adicione a policy sugerida ao bucket (deixa só o CloudFront ler).
- **Default root object**: `index.html`.
- **Compress objects automatically: Yes** (gzip/brotli).
- (Opcional) custom error 403/404 → `/index.html` se quiser navegação amigável.
- Free tier **perpétuo**: 1 TB/mês de saída + 10 M requisições — custo tende a ~US$0.

## 3. OIDC: GitHub ↔ AWS (sem chaves)
1. IAM → Identity providers → **Add provider** → OpenID Connect:
   - URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`
2. Crie uma **IAM Role** (Web identity) confiando nesse provider, **restrita ao repo**:
   - Condition: `token.actions.githubusercontent.com:sub` = `repo:<OWNER>/<REPO>:ref:refs/heads/main`
   - (e `:aud` = `sts.amazonaws.com`)
3. Permissões da role (mínimas):
   - `s3:PutObject`, `s3:DeleteObject`, `s3:ListBucket` no bucket (`arn:aws:s3:::<bucket>` e `/*`)
   - `cloudfront:CreateInvalidation` na distribuição

## 4. Variáveis/segredos do repositório (Settings → Secrets and variables → Actions)
- **Secret** `AWS_DEPLOY_ROLE_ARN` = ARN da role criada no passo 3.
- **Variables**: `AWS_REGION` (ex.: `us-east-1`), `S3_BUCKET` (nome do bucket),
  `CLOUDFRONT_ID` (ID da distribuição).

## 5. Deploy
- Push na `main` (ou rode o workflow manualmente: **Actions → Deploy estático → Run**).
- A Action faz `build_static.js`, roda os gates (smoke do bundle + validação),
  sincroniza o S3 com os cabeçalhos de cache e invalida só `index.html`,
  `editor.html` e `data/manifest.json` (barato; ≤ 1000 paths/mês são grátis).

## URLs
- Simulador: `https://<dist>.cloudfront.net/`  (ou domínio próprio)
- Editor:    `https://<dist>.cloudfront.net/editor.html`

## Custos / cache (resumo)
- Assets e dados têm **hash no nome** → `Cache-Control: immutable` (sem re-egress).
- Fengari vem do **CDN público (jsDelivr)** → zero egress nosso na maior dependência.
- Só `*.html` + `manifest.json` têm cache curto e são invalidados a cada deploy.
- **Segurança**: nenhum segredo entra no bundle; credenciais AWS são efêmeras (OIDC).
