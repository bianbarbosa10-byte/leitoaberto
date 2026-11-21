-- GOLD: municipios do ES com regiao de saude, centroide e populacao do ano mais recente.
select
    m.cod_mun6,
    m.cod_mun7,
    m.municipio,
    m.cod_regiao_saude,
    m.regiao_saude,
    m.microrregiao,
    m.regiao_imediata,
    m.lat,
    m.lon,
    p.populacao        as populacao_atual,
    p.ano_ibge         as ano_populacao
from silver.dim_municipio m
left join gold.populacao p
       on p.cod_mun6 = m.cod_mun6 and p.ano = (select max(ano) from gold.dim_calendario)
order by m.municipio
