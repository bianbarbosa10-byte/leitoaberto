-- GOLD: populacao por municipio para cada ano do calendario.
-- Quando o IBGE ainda nao publicou a estimativa do ano (ou nao ha estimativa, como em 2022/2023),
-- usa o ano disponivel mais recente anterior; ano_ibge mostra qual foi usado.
with anos as (select distinct ano from gold.dim_calendario),
pares as (
    select a.ano, p.cod_mun6, p.ano as ano_ibge, p.populacao,
           row_number() over (partition by a.ano, p.cod_mun6
                              order by (p.ano <= a.ano) desc, abs(a.ano - p.ano), p.ano desc) as ordem
    from anos a
    join silver.ibge_populacao p on true
)
select ano, cod_mun6, ano_ibge, populacao
from pares
where ordem = 1
order by ano, cod_mun6
