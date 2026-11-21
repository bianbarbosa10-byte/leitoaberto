-- GOLD: 1 linha por mes (competencia AAAA-MM), de {inicio} ate a ultima competencia do SIH.
-- completude_sih = fracao esperada das AIH daquele mes de alta que ja foi processada, estimada pela
-- defasagem historica (competencia de processamento - mes de alta) dos meses ja "fechados" (>= 6 meses).
with aih as (
    select
        year(strptime(competencia, '%Y-%m')) * 12 + month(strptime(competencia, '%Y-%m')) as i_proc,
        year(dt_saida) * 12 + month(dt_saida)                                              as i_saida
    from silver.sih_aih
    where dt_saida is not null
),
u as (select max(i_proc) as u from aih),
base as (select i_proc - i_saida as defasagem from aih, u where i_saida <= u.u - 6 and i_proc >= i_saida),
dist as (select defasagem, count(*) / sum(count(*)) over () as p from base group by defasagem),
acum as (select defasagem, sum(p) over (order by defasagem) as acumulado from dist),
meses as (
    select m::date as data_mes
    from range(strptime('{inicio}', '%Y-%m'),
               (select max(strptime(competencia, '%Y-%m')) from silver.sih_aih) + interval 1 month,
               interval 1 month) t(m)
),
cal as (
    select
        strftime(data_mes, '%Y-%m')                                           as competencia,
        data_mes,
        year(data_mes)                                                        as ano,
        month(data_mes)                                                       as mes,
        ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'][month(data_mes)] as mes_nome,
        ['jan','fev','mar','abr','mai','jun','jul','ago','set','out','nov','dez'][month(data_mes)]
            || '/' || right(year(data_mes)::varchar, 2)                       as mes_ano,
        year(data_mes) || '-T' || quarter(data_mes)                           as trimestre,
        year(data_mes) || '-S' || (case when month(data_mes) <= 6 then 1 else 2 end) as semestre,
        day(last_day(data_mes))                                               as dias_no_mes,
        (select u from u) - (year(data_mes) * 12 + month(data_mes))           as meses_ate_ultima
    from meses
)
select
    cal.* exclude (meses_ate_ultima),
    round(coalesce((select max(acumulado) from acum where defasagem <= cal.meses_ate_ultima), 0), 4) as completude_sih,
    case when coalesce((select max(acumulado) from acum where defasagem <= cal.meses_ate_ultima), 0) >= 0.99
         then 'Consolidado' else 'Preliminar' end                             as status_dados
from cal
order by competencia
