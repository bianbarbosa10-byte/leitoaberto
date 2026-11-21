-- GOLD | ESTUDO 2 - Vazio assistencial e fluxo, por municipio de residencia x ano.
-- evasao_municipal = % das internacoes de residentes feitas FORA do proprio municipio
-- evasao_regional  = % feitas fora da propria regiao de saude
-- invasao_municipal = % das internacoes realizadas no municipio que sao de residentes de outros municipios
-- sem_atendimento_hospitalar = municipio sem nenhuma internacao SUS realizada no ano (vazio assistencial)
with anos as (select distinct ano from gold.tmp_e2_internacao),
res as (
    select ano, cod_mun_res as cod_mun6,
           count(*)                                                   as internacoes,
           count(*) filter (where cod_mun_res = cod_mun_int)           as no_proprio_municipio,
           count(*) filter (where regiao_res = regiao_int)             as na_propria_regiao,
           avg(dist_km)                                               as dist_media_km,
           avg(dist_km) filter (where cod_mun_res <> cod_mun_int)      as dist_media_fora_km,
           count(*) filter (where complexidade = 'Alta')               as alta_complexidade
    from gold.tmp_e2_internacao
    where residente_es
    group by all
),
dest as (
    select ano, cod_mun_int as cod_mun6,
           count(*)                                                   as internacoes_realizadas,
           count(*) filter (where cod_mun_res <> cod_mun_int)          as de_outros_municipios
    from gold.tmp_e2_internacao
    group by all
),
ocup as (
    select left(e.competencia, 4)::int as ano, h.cod_mun6,
           sum(e.pacientes_dia) as pacientes_dia, sum(e.leitos_dia) as leitos_dia
    from gold.e1_hospital_mes e
    join gold.dim_hospital h using (cnes)
    group by all
)
select
    a.ano,
    m.cod_mun6,
    m.municipio,
    m.regiao_saude,
    m.lat,
    m.lon,
    p.populacao,
    coalesce(r.internacoes, 0)                                                     as internacoes,
    coalesce(r.no_proprio_municipio, 0)                                            as no_proprio_municipio,
    coalesce(r.na_propria_regiao, 0)                                               as na_propria_regiao,
    round(r.dist_media_km, 1)                                                      as dist_media_km,
    round(r.dist_media_fora_km, 1)                                                 as dist_media_fora_km,
    coalesce(r.alta_complexidade, 0)                                               as alta_complexidade,
    round(1000.0 * r.internacoes / nullif(p.populacao, 0), 2)                     as tx_internacao_1000hab,
    round(1 - r.no_proprio_municipio / nullif(r.internacoes, 0), 4)               as evasao_municipal,
    round(1 - r.na_propria_regiao / nullif(r.internacoes, 0), 4)                  as evasao_regional,
    coalesce(d.internacoes_realizadas, 0)                                          as internacoes_realizadas,
    coalesce(d.de_outros_municipios, 0)                                            as de_outros_municipios,
    round(d.de_outros_municipios / nullif(d.internacoes_realizadas, 0), 4)         as invasao_municipal,
    round(o.pacientes_dia / nullif(o.leitos_dia, 0), 4)                            as ocupacao_hospitais,
    coalesce(d.internacoes_realizadas, 0) = 0                                      as sem_atendimento_hospitalar
from anos a
cross join silver.dim_municipio m
left join gold.populacao p on p.ano = a.ano and p.cod_mun6 = m.cod_mun6
left join res r  on r.ano = a.ano and r.cod_mun6 = m.cod_mun6
left join dest d on d.ano = a.ano and d.cod_mun6 = m.cod_mun6
left join ocup o on o.ano = a.ano and o.cod_mun6 = m.cod_mun6
order by a.ano, m.municipio
