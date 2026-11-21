# Segurança do LeitoAberto

Auditoria feita em 2026-11-21, antes da divulgação pública. Repetir os testes depois de qualquer mudança de
infraestrutura (novo papel no banco, novo segredo, novo serviço).

## Modelo de ameaça

| Ativo | Risco | Controle |
|---|---|---|
| Segredos (R2, Neon, sal do hash) | vazamento no código ou nos logs | só em GitHub Secrets e `.env` local (no `.gitignore`); varredura de segredos + push protection do GitHub ligados |
| Banco Neon (gold) | alteração ou apagamento de dados | escrita só com o papel dono (secret do Actions); leitura externa só com `leitoaberto_leitor` |
| Data lake R2 (bronze/silver/gold) | download do dado bruto | bucket privado: URL pública r2.dev desligada, sem domínio público, acesso anônimo recusado |
| Site | XSS, injeção de script | site estático, sem formulários; parâmetros da URL validados por lista; texto escapado antes de virar HTML; CSP |
| Repositório e Actions | código malicioso no workflow, força bruta no histórico | permissões mínimas (`contents: read`), sem `pull_request_target`, `main` protegida contra force push e exclusão |
| Dados pessoais (LGPD) | reidentificação | só dados agregados no site; CPF descartado na Silver; CNES só guarda CNPJ |

## Testes executados

**Repositório e histórico do git**
- Busca de segredos nos 7 commits (strings de conexão Postgres, chaves R2/AWS, tokens GitHub, chave 21st, chaves privadas): nada encontrado.
- `.env`, `.mcp.json`, `.claude/settings.local.json` e `data/` nunca foram versionados.
- Autor dos commits usa o e-mail noreply do GitHub; o e-mail pessoal não aparece no histórico.

**Site publicado**
- HTTPS obrigatório (HTTP → 301) e HSTS ativo (servidos pelo GitHub Pages).
- `.env`, `.git/config`, `.mcp.json`, `package.json` e o arquivo de credenciais retornam 404.
- Build e JSON públicos varridos atrás de segredos e campos pessoais: nada encontrado.
- Injeção pela URL (`?cnes="><img onerror=…>`, `?mes=<script>`) e pela busca da tabela: descartada ou exibida como texto.
- CSP via `<meta>`: `script-src 'self'`, sem scripts embutidos; páginas, gráficos, mapa e tema funcionam sem violações.

**Dependências**
- `npm audit`: 0 vulnerabilidades. `pip-audit` no `requirements.txt`: 0 vulnerabilidades.
- Alertas e correções automáticas do Dependabot ligados.

**Banco Neon (teste de invasão com o papel de leitura)**
- Conexão sem TLS e senha errada recusadas.
- INSERT, UPDATE, DELETE, TRUNCATE, DROP, CREATE (tabela, schema, função, extensão, papel), ALTER ROLE,
  GRANT para si mesmo, leitura de `pg_authid`, `pg_read_file` e `COPY TO PROGRAM`: todos bloqueados,
  inclusive com o modo somente-leitura desligado pelo cliente (o bloqueio vem das permissões, não só do modo).
- Limites: 5 conexões, consultas de até 60 s.

**R2**
- URL pública desligada, sem domínio customizado, leitura e listagem anônimas recusadas.

## Achado corrigido

O primeiro papel de leitura (`leitoaberto_leitura`) foi criado pela API do Neon, que coloca todo papel criado
assim dentro de `neon_superuser`. Na prática ele **podia gravar e apagar dados** e criar papéis. O teste confirmou
a falha. Correção: novo papel `leitoaberto_leitor`, criado em SQL, sem privilégios extras, com
`default_transaction_read_only`, timeout e limite de conexões. **Regra: papéis de leitura sempre em SQL, nunca
pelo painel ou API do Neon.**

## Pendências do dono da conta

- Excluir o papel antigo `leitoaberto_leitura` no painel do Neon.
- Trocar o token do R2 por um com permissão "Object Read & Write" só no bucket `leitoaberto`.
- Trocar a chave da API do 21st.dev (apareceu numa conversa).
- Confirmar 2FA no GitHub, Cloudflare, Neon e no Gmail.

## Limitações conhecidas

- O GitHub Pages não permite cabeçalhos HTTP próprios: sem `X-Frame-Options`/`frame-ancestors` (risco baixo,
  o site não tem ações para sequestrar com clickjacking).
- `style-src 'unsafe-inline'` é necessário para o ECharts.
- As actions do workflow são as oficiais do GitHub (`actions/*`), referenciadas por versão, não por hash.
