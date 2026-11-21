-- SILVER: populacao residente estimada por municipio do ES e ano (IBGE/SIDRA tabela 6579).
select
    left(cod_mun7, 6)            as cod_mun6,
    cod_mun7,
    try_cast(ano as int)         as ano,
    try_cast(valor as bigint)    as populacao
from read_parquet('{bronze}/ibge/populacao.parquet')
where try_cast(valor as bigint) is not null
