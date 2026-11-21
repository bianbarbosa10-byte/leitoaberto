-- GOLD | ESTUDO 3 - Capacidade instalada: leitos por municipio x competencia do CNES (grade completa).
-- Leitos de internacao = cirurgico, clinico, obstetrico, pediatrico e outras especialidades.
-- UTI = UTI/UCO adulto, pediatrica, neonatal e queimados (codigos 74-83, 85, 86).
with comp as (select distinct competencia from silver.cnes_leito),
l as (
    select competencia, cod_mun as cod_mun6,
           sum(leitos_existentes) filter (where categoria = 'Internação') as leitos_internacao_existentes,
           sum(leitos_sus)        filter (where categoria = 'Internação') as leitos_internacao_sus,
           sum(leitos_existentes) filter (where categoria = 'UTI')        as uti_existentes,
           sum(leitos_sus)        filter (where categoria = 'UTI')        as uti_sus,
           count(distinct cnes)                                           as estabelecimentos_com_leito
    from silver.cnes_leito
    group by all
)
select
    c.competencia,
    m.cod_mun6,
    m.municipio,
    m.regiao_saude,
    m.lat,
    m.lon,
    p.populacao,
    coalesce(l.leitos_internacao_existentes, 0)                                   as leitos_internacao_existentes,
    coalesce(l.leitos_internacao_sus, 0)                                          as leitos_internacao_sus,
    coalesce(l.uti_existentes, 0)                                                 as uti_existentes,
    coalesce(l.uti_sus, 0)                                                        as uti_sus,
    coalesce(l.estabelecimentos_com_leito, 0)                                     as estabelecimentos_com_leito,
    round(1000.0 * coalesce(l.leitos_internacao_existentes, 0) / nullif(p.populacao, 0), 3) as leitos_existentes_1000hab,
    round(1000.0 * coalesce(l.leitos_internacao_sus, 0) / nullif(p.populacao, 0), 3)        as leitos_sus_1000hab,
    round(10000.0 * coalesce(l.uti_sus, 0) / nullif(p.populacao, 0), 3)                     as uti_sus_10milhab,
    round(l.leitos_internacao_sus / nullif(l.leitos_internacao_existentes, 0), 4)           as pct_sus_internacao
from comp c
cross join silver.dim_municipio m
left join gold.populacao p on p.ano = left(c.competencia, 4)::int and p.cod_mun6 = m.cod_mun6
left join l on l.competencia = c.competencia and l.cod_mun6 = m.cod_mun6
order by c.competencia, m.municipio
