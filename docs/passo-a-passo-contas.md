# Passo a passo: colocar o LeitoAberto na nuvem

Tudo é gratuito. Ordem sugerida: GitHub → Cloudflare R2 → Neon → segredos → primeira execução.

## 1. GitHub (repositório + Actions + Pages)

1. Crie uma conta em https://github.com (se ainda não tiver).
2. Crie um repositório **público** chamado `leitoaberto` (sem README, para não conflitar).
3. No PowerShell, na pasta do projeto, faça login no GitHub CLI: `gh auth login`.
4. Me avise e eu faço o `git init`, o primeiro commit e o push.
5. Em *Settings → Pages*, em **Source**, escolha **GitHub Actions**.

O site ficará em `https://<seu-usuario>.github.io/leitoaberto/`.

## 2. Cloudflare R2 (data lake)

1. Crie uma conta em https://dash.cloudflare.com.
2. Menu **R2 Object Storage** → ative o plano gratuito (10 GB, sem custo de saída). A Cloudflare pede um cartão
   para ativar o R2, mas não cobra dentro do plano gratuito. *Alternativa sem cartão: Backblaze B2. Nesse caso me avise,
   porque só muda o endpoint em `pipeline/storage.py`.*
3. **Create bucket** → nome `leitoaberto` → localização automática.
4. **Manage R2 API Tokens** → *Create API token* → permissão **Object Read & Write**, restrita ao bucket `leitoaberto`.
5. Anote: **Account ID**, **Access Key ID** e **Secret Access Key** (o secret só aparece uma vez).

## 3. Neon (PostgreSQL da camada Gold)

1. Crie uma conta em https://neon.tech (plano Free).
2. Crie o projeto `leitoaberto`, região **AWS São Paulo (sa-east-1)**, banco `leitoaberto`.
3. Copie a *connection string* (`postgresql://...?sslmode=require`).
4. (Opcional, para o Power BI) Crie um usuário só de leitura **pelo SQL Editor** do Neon, conectado com o
   usuário dono. Não crie pelo painel "Roles" nem pela API: o Neon coloca esses papéis em `neon_superuser`
   e eles passam a poder gravar (ver [seguranca.md](seguranca.md)).
   ```sql
   create role leitoaberto_leitor login nocreatedb nocreaterole nobypassrls connection limit 5
     password 'senha-longa-aleatoria';
   alter role leitoaberto_leitor set default_transaction_read_only = on;
   alter role leitoaberto_leitor set statement_timeout = '60s';
   grant connect on database leitoaberto to leitoaberto_leitor;
   ```
   O pipeline já dá `select` no schema `gold` para esse usuário a cada carga.

## 4. Segredos no GitHub

No repositório: *Settings → Secrets and variables → Actions → New repository secret*:

| Nome | Valor |
|---|---|
| `R2_ACCOUNT_ID` | Account ID da Cloudflare |
| `R2_ACCESS_KEY_ID` | Access Key do token R2 |
| `R2_SECRET_ACCESS_KEY` | Secret do token R2 |
| `DATABASE_URL` | connection string do Neon |
| `LA_HASH_SALT` | um texto aleatório longo (pseudonimização LGPD) |

Se o bucket não se chamar `leitoaberto`, crie também a *variable* `R2_BUCKET`.

Para rodar localmente com a nuvem, preencha os mesmos valores no arquivo `.env` (copie de `.env.example`).

## 5. Primeira execução

*Actions → Pipeline mensal → Run workflow*. A primeira carga leva ~15 a 20 minutos. Depois disso o
agendamento cuida de tudo todo dia 10.

Opção mais rápida: rodar a primeira carga no seu computador, com o `.env` preenchido
(`.venv\Scripts\python -m pipeline.run --forcar`), que envia para o R2 e o Neon o que já está em `data/`.

## 6. Power BI

*Obter dados → Banco de dados PostgreSQL* → servidor = host do Neon, banco = `leitoaberto`, usuário
`leitoaberto_leitor`. Use as tabelas do schema `gold`. As medidas continuam as mesmas do PIH: somar
numerador e denominador antes de dividir.
