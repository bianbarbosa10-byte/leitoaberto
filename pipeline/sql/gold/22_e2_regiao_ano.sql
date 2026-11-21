-- GOLD | ESTUDO 2 - indicadores por regiao de saude x ano.
-- autossuficiencia = % das internacoes de residentes feitas na propria regiao (evasao = 1 - autossuficiencia)
-- invasao          = % das internacoes realizadas na regiao que sao de residentes de outras regioes/UF
-- leitos_ociosos_equiv = leitos SUS que sobrariam se cada hospital operasse a 85% de ocupacao (media mensal)
with res as (
    select ano, regiao_res as regiao_saude,
           count(*)                                         as residentes_internados,
           count(*) filter (where regiao_res = regiao_int)  as na_propria_regiao,
           avg(dist_km)                                     as dist_media_km
    from gold.tmp_e2_internacao
    where residente_es
    group by all
),
dest as (
    select ano, regiao_int as regiao_saude,
           count(*)                                         as internacoes_na_regiao,
           count(*) filter (where regiao_res <> regiao_int) as de_fora_da_regiao,
           count(*) filter (where not residente_es)         as de_fora_do_es
    from gold.tmp_e2_internacao
    group by all
),
pop as (
    select p.ano, m.regiao_saude, sum(p.populacao) as populacao, count(*) as municipios
    from gold.populacao p join silver.dim_municipio m using (cod_mun6)
    group by all
),
ocup as (
    select left(e.competencia, 4)::int as ano, h.regiao_saude,
           sum(e.pacientes_dia) as pacientes_dia,
           sum(e.leitos_dia)    as leitos_dia,
           sum(e.leitos_sus_operacionais) / count(distinct e.competencia) as leitos_sus_medios,
           sum(greatest((e.leitos_dia - e.pacientes_dia / 0.85) / e.dias_no_mes, 0))
               / count(distinct e.competencia)                            as leitos_ociosos_equiv
    from gold.e1_hospital_mes e
    join gold.dim_hospital h using (cnes)
    group by all
)
select
    p.ano,
    p.regiao_saude,
    p.populacao,
    p.municipios,
    r.residentes_internados,
    r.na_propria_regiao,
    round(r.dist_media_km, 1)                                              as dist_media_km,
    d.internacoes_na_regiao,
    d.de_fora_da_regiao,
    d.de_fora_do_es,
    round(r.na_propria_regiao / nullif(r.residentes_internados, 0), 4)    as autossuficiencia,
    round(1 - r.na_propria_regiao / nullif(r.residentes_internados, 0), 4) as evasao,
    round(d.de_fora_da_regiao / nullif(d.internacoes_na_regiao, 0), 4)     as invasao,
    round(1000.0 * r.residentes_internados / nullif(p.populacao, 0), 2)   as tx_internacao_1000hab,
    o.pacientes_dia,
    o.leitos_dia,
    round(o.leitos_sus_medios, 1)                                          as leitos_sus_medios,
    round(o.pacientes_dia / nullif(o.leitos_dia, 0), 4)                    as ocupacao,
    round(o.leitos_ociosos_equiv, 1)                                       as leitos_ociosos_equiv
from pop p
left join res r  on r.ano = p.ano and r.regiao_saude = p.regiao_saude
left join dest d on d.ano = p.ano and d.regiao_saude = p.regiao_saude
left join ocup o on o.ano = p.ano and o.regiao_saude = p.regiao_saude
where p.ano in (select distinct ano from gold.tmp_e2_internacao)
order by p.ano, p.regiao_saude
