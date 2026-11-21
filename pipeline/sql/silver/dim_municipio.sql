-- SILVER: municipios do ES com regiao de saude (TabWin/SESA) e nome oficial acentuado (IBGE).
select
    s.cod_mun6,
    i.cod_mun7,
    coalesce(i.municipio, s.municipio)   as municipio,
    s.cod_regiao_saude,
    s.regiao_saude,
    i.microrregiao,
    i.regiao_imediata,
    try_cast(s.lat as double)            as lat,
    try_cast(s.lon as double)            as lon
from read_csv('{seeds}/municipios_es.csv', all_varchar = true) s
left join read_parquet('{bronze}/ibge/municipios.parquet') i on left(i.cod_mun7, 6) = s.cod_mun6
