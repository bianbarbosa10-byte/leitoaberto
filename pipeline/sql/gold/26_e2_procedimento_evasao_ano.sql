-- GOLD | ESTUDO 2 - procedimentos que mais levam residentes do ES a internar fora da sua regiao (top 50 por ano).
with p as (
    select ano, proc_rea,
           count(*)                                                       as internacoes,
           count(*) filter (where regiao_res <> regiao_int)               as fora_da_regiao,
           avg(dist_km) filter (where regiao_res <> regiao_int)           as dist_media_fora_km,
           any_value(complexidade)                                        as complexidade
    from gold.tmp_e2_internacao
    where residente_es
    group by all
)
select
    p.ano,
    p.proc_rea,
    coalesce(s.procedimento, p.proc_rea)                  as procedimento,
    p.complexidade,
    p.internacoes,
    p.fora_da_regiao,
    round(p.fora_da_regiao / p.internacoes, 4)            as pct_fora_da_regiao,
    round(p.dist_media_fora_km, 1)                        as dist_media_fora_km
from p
left join read_csv('{seeds}/procedimentos_sigtap.csv', all_varchar = true) s on s.proc_rea = p.proc_rea
qualify row_number() over (partition by p.ano order by p.fora_da_regiao desc) <= 50
order by p.ano, p.fora_da_regiao desc
