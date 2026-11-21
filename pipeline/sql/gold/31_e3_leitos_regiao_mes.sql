-- GOLD | ESTUDO 3 - leitos por regiao de saude x competencia, com o parametro de 2,5 leitos SUS/1.000 hab.
-- (Portaria GM/MS 1.631/2015 usa parametros de 2,5 a 3 leitos/1.000 hab; aqui o piso de 2,5.)
with r as (
    select competencia, regiao_saude,
           sum(populacao)                    as populacao,
           sum(leitos_internacao_existentes) as leitos_internacao_existentes,
           sum(leitos_internacao_sus)        as leitos_internacao_sus,
           sum(uti_existentes)               as uti_existentes,
           sum(uti_sus)                      as uti_sus,
           sum(estabelecimentos_com_leito)   as estabelecimentos_com_leito
    from gold.e3_leitos_municipio_mes
    group by all
)
select
    r.*,
    round(1000.0 * leitos_internacao_existentes / nullif(populacao, 0), 3) as leitos_existentes_1000hab,
    round(1000.0 * leitos_internacao_sus / nullif(populacao, 0), 3)        as leitos_sus_1000hab,
    round(10000.0 * uti_existentes / nullif(populacao, 0), 3)              as uti_existentes_10milhab,
    round(10000.0 * uti_sus / nullif(populacao, 0), 3)                     as uti_sus_10milhab,
    round(uti_existentes / nullif(leitos_internacao_existentes, 0), 4)     as uti_pct_leitos_internacao,
    round(leitos_internacao_sus / nullif(leitos_internacao_existentes, 0), 4) as pct_sus_internacao,
    round(uti_sus / nullif(uti_existentes, 0), 4)                          as pct_sus_uti,
    round(populacao * 2.5 / 1000 - leitos_internacao_sus, 0)               as deficit_sus_vs_2_5_por_mil
from r
order by competencia, regiao_saude
