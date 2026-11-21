# Validação contra os estudos originais (PIH)

Carga de 20/11/2026: SIH-RD do ES de 2024-01 a 2026-09, CNES de 2024-01 a 2026-10, IBGE SIDRA 6579.

## Estudo 1 · `gold.e1_hospital_mes` × `Indicadores_Hospitalares_PowerBI.xlsx`

2.190 linhas hospital × mês do Excel, todas encontradas na gold (73 hospitais).

| Campo | Linhas idênticas | Soma Excel | Soma gold |
|---|---|---|---|
| leitos_sus_operacionais | 100% | 188.174 | 188.174 |
| leitos_dia | 100% | 5.720.681 | 5.720.681 |
| saidas | 98,6% | 733.041 | 738.661 |
| obitos | 99,0% | 30.370 | 30.600 |
| pacientes_dia (censo) | 93,4% | 3.709.049 | 3.759.339 |

Todo o ano de 2024 é idêntico. As diferenças começam em 2025-06 e crescem nos meses recentes: o DATASUS
republicou os arquivos RD em 10/11/2026 com AIH processadas depois da extração usada no Excel.

## Estudo 2 · `gold.e2_*` × `Estudo 2 - Dados para validação.xlsx`

- As 318.259 AIH (tipo 1) de 2025 do arquivo original estão todas na Silver, com município de residência e
  de internação idênticos. A carga nova tem 321.349: são 3.090 AIH a mais, publicadas depois.
- População 2025 por região: idêntica (538.516 / 2.458.949 / 430.125 / 699.264).
- Invasão da região Central: 18,16% nas duas versões. A autossuficiência varia na 3ª casa decimal por causa das AIH novas.
- Os municípios em vazio assistencial são os mesmos (Viana, Marataízes, Conceição da Barra, Sooretama...).

## Estudo 3 · `gold.e3_*` × `Estudo 3 - Dados para validação.xlsx`

Idêntico em dez/2025: leitos de internação existentes, SUS, UTI, estabelecimentos e taxas por região;
mamógrafos (existentes, em uso, SUS, necessidade) e serviços (ex.: Atenção psicossocial 88/46, 421/140, 55/37, 101/61).

## Como repetir

```powershell
.venv\Scripts\python -m pipeline.run --sem-ingestao --sem-publicar
```
e compare `data/leitoaberto.duckdb` (schemas `silver` e `gold`) com as planilhas de validação.
