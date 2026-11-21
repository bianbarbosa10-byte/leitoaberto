# LeitoAberto

**Dados abertos sobre leitos, internações e acesso hospitalar no SUS do Espírito Santo.**

Pipeline de engenharia de dados (arquitetura medalhão Bronze → Silver → Gold) que coleta automaticamente,
todo mês, os dados públicos do DATASUS (SIH/SUS e CNES) e do IBGE, calcula os indicadores de três estudos
e publica tudo em um site estático e em um banco PostgreSQL para o Power BI. Custo de infraestrutura: R$ 0.

```
DATASUS FTP (SIH-RD, CNES LT/EQ/SR/ST) ─┐
IBGE (SIDRA 6579, localidades, malha) ──┼─► GitHub Actions (todo dia 10, 06:00 BRT; repete 11–15)
API dados abertos CNES ─────────────────┘            │
                                                     ▼
   BRONZE  .dbc original + Parquet (texto)      ┐
   SILVER  tipado, limpo, códigos traduzidos     ├─ Cloudflare R2 (data lake, Parquet)
   GOLD    indicadores dos estudos 1, 2 e 3      ┘   + Neon PostgreSQL (schema gold)
                                                     │
                         Site Astro + ECharts (GitHub Pages)  ·  Power BI (conecta no Neon)
```

## Os estudos

| Estudo | Pergunta | Tabelas gold |
|---|---|---|
| 1 · Eficiência operacional | Como os hospitais usam os leitos? Ocupação (lógica de censo), permanência, giro, mortalidade | `e1_hospital_mes`, `e1_perfil_internacao` |
| 2 · Vazio assistencial e fluxo | Onde os capixabas se internam, a que distância, quem fica sem atendimento | `e2_*` |
| 3 · Capacidade instalada | Leitos, UTI, equipamentos e serviços por habitante e por região | `e3_*` |

Dimensões: `dim_calendario` (com completude do SIH), `dim_hospital`, `dim_municipio`, `populacao`, `meta_atualizacao`.

## Estrutura

```
pipeline/
  config.py          fontes, caminhos, variáveis de ambiente
  storage.py         Cloudflare R2 (API S3) com espelho local em data/
  bronze.py          ingestão incremental: FTP DATASUS, IBGE, API CNES + manifesto
  dbc.py / dbf.py    descompactador .dbc e leitor .dbf em Python puro
  transform.py       executa sql/silver e sql/gold no DuckDB e exporta Parquet
  sql/silver/*.sql   uma tabela por arquivo
  sql/gold/*.sql     em ordem numérica; prefixo tmp_ = intermediária (não publicada)
  publish.py         carrega a gold no Neon com troca atômica de schema
  export_site.py     gera os JSON do site a partir da gold (Neon ou Parquet local)
  run.py             orquestrador
seeds/               tabelas de referência fixas (municípios/regiões de saúde, domínios, SIGTAP)
scripts/gerar_seeds.py   regenera os seeds a partir do TabWin local (uso único)
site/                Astro + ECharts
.github/workflows/pipeline.yml   agendamento mensal + deploy do site
docs/                passo a passo de configuração e validação
```

## Rodar localmente

```powershell
py -3.13 -m venv .venv
.venv\Scripts\pip install -r requirements.txt
copy .env.example .env          # opcional: sem credenciais roda 100% local em data/

.venv\Scripts\python -m pipeline.run              # Bronze -> Silver -> Gold (-> R2 e Neon se configurados)
.venv\Scripts\python -m pipeline.run --forcar     # reprocessa mesmo sem dado novo
.venv\Scripts\python -m pipeline.export_site      # gera os dados do site

cd site
npm install
npm run dev                                         # http://localhost:4321
```

A primeira carga (desde jan/2024, ~170 arquivos) leva ~15 minutos; as seguintes só baixam o que mudou.

## Atualização automática

O workflow roda no dia 10 de cada mês e repete nos dias 11 a 15 (o DATASUS costuma atrasar). O manifesto da
Bronze guarda tamanho e data de cada arquivo do FTP: só arquivos novos **ou republicados** são baixados
(o DATASUS republica competências antigas do SIH quando chegam AIH atrasadas). Sem novidade, a execução
termina em segundos e o site não é reconstruído. Também é possível rodar manualmente em *Actions → Pipeline
mensal → Run workflow*.

## Validação

Os números foram conferidos contra os estudos originais do PIH: Estudo 1 idêntico em todo 2024 e 100% nos
leitos; Estudo 3 idêntico (leitos, UTI, equipamentos, serviços); Estudo 2 com todas as AIH originais presentes
e idênticas, mais 3.090 AIH de 2025 que o DATASUS publicou depois. Detalhes em [docs/validacao.md](docs/validacao.md).

## Fontes e licença dos dados

DATASUS/Ministério da Saúde (SIH/SUS, CNES) e IBGE: dados públicos. Campos de CPF de autorizadores são
pseudonimizados na Bronze (LGPD). Este projeto não é um canal oficial do Ministério da Saúde nem da SESA-ES.
