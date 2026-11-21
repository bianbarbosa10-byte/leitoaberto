-- GOLD | ESTUDO 1 - Eficiencia operacional. 1 linha por hospital (com AIH) x mes. Grade completa (zeros).
--
-- Taxa de ocupacao = pacientes-dia / leitos-dia
--   pacientes-dia: dias de leito ocupado distribuidos pelo MES REAL de ocupacao (censo). Cada AIH ocupa
--   [dt_saida - dias_perm, dt_saida): o dia da internacao conta, o da saida nao.
--   leitos-dia: leitos SUS operacionais (internacao + complementares; sem hospital-dia) x dias do mes.
-- Saidas, permanencia, giro e mortalidade usam a competencia de PROCESSAMENTO da AIH.
-- Taxas por linha sao para conferencia: em agregacoes, some numerador e denominador antes de dividir.
with hosp as (
    select distinct cnes from silver.sih_aih
),
grade as (
    select h.cnes, c.competencia, c.dias_no_mes, c.status_dados
    from hosp h cross join gold.dim_calendario c
),
leitos as (
    select
        cnes, competencia,
        sum(leitos_sus) filter (where tp_leito in (1, 2, 4, 5, 6)) as leitos_sus_internacao,
        sum(leitos_sus) filter (where tp_leito = 3)                as leitos_sus_complementar,
        sum(leitos_sus) filter (where tp_leito = 7)                as leitos_sus_hospital_dia,
        sum(leitos_existentes)                                     as leitos_existentes_total
    from silver.cnes_leito
    group by all
),
periodos as (
    select cnes, dt_inicio_ocupacao as ini, dt_saida as fim,
           unnest(generate_series(date_trunc('month', dt_inicio_ocupacao),
                                  date_trunc('month', dt_saida - 1),
                                  interval 1 month)) as mes
    from silver.sih_aih
    where dias_perm > 0 and dt_saida is not null
),
censo as (
    select cnes, strftime(mes, '%Y-%m') as competencia,
           sum(date_diff('day', greatest(ini, mes::date), least(fim, (mes + interval 1 month)::date))) as pacientes_dia
    from periodos
    group by all
),
producao as (
    select
        cnes, competencia,
        count(*)                                                    as aih_aprovadas,
        count(*) filter (where eh_saida)                            as saidas,
        count(*) filter (where not eh_saida)                        as aih_continuacao,
        sum(dias_perm)                                              as pacientes_dia_competencia,
        sum(dias_perm) filter (where eh_saida)                      as dias_perm_saidas,
        count(*) filter (where obito)                               as obitos,
        count(*) filter (where obito and dias_perm < 1)             as obitos_menos_24h,
        count(*) filter (where obito and dias_perm >= 1)            as obitos_24h_mais,
        count(*) filter (where obito and dias_perm >= 2)            as obitos_48h_mais,
        sum(dias_uti)                                               as dias_uti,
        sum(valor_total)                                            as valor_total_aih
    from silver.sih_aih
    group by all
),
j as (
    select
        g.cnes, g.competencia, g.dias_no_mes, g.status_dados,
        coalesce(l.leitos_sus_internacao, 0)                        as leitos_sus_internacao,
        coalesce(l.leitos_sus_complementar, 0)                      as leitos_sus_complementar,
        coalesce(l.leitos_sus_internacao, 0) + coalesce(l.leitos_sus_complementar, 0) as leitos_sus_operacionais,
        coalesce(l.leitos_sus_hospital_dia, 0)                      as leitos_sus_hospital_dia,
        coalesce(l.leitos_existentes_total, 0)                      as leitos_existentes_total,
        coalesce(c.pacientes_dia, 0)                                as pacientes_dia,
        coalesce(p.aih_aprovadas, 0)                                as aih_aprovadas,
        coalesce(p.saidas, 0)                                       as saidas,
        coalesce(p.aih_continuacao, 0)                              as aih_continuacao,
        coalesce(p.pacientes_dia_competencia, 0)                    as pacientes_dia_competencia,
        coalesce(p.dias_perm_saidas, 0)                             as dias_perm_saidas,
        coalesce(p.obitos, 0)                                       as obitos,
        coalesce(p.obitos_menos_24h, 0)                             as obitos_menos_24h,
        coalesce(p.obitos_24h_mais, 0)                              as obitos_24h_mais,
        coalesce(p.obitos_48h_mais, 0)                              as obitos_48h_mais,
        coalesce(p.dias_uti, 0)                                     as dias_uti,
        coalesce(p.valor_total_aih, 0)                              as valor_total_aih
    from grade g
    left join leitos l   on l.cnes = g.cnes and l.competencia = g.competencia
    left join censo c    on c.cnes = g.cnes and c.competencia = g.competencia
    left join producao p on p.cnes = g.cnes and p.competencia = g.competencia
)
select
    j.*,
    j.leitos_sus_operacionais * j.dias_no_mes                                         as leitos_dia,
    round(j.pacientes_dia / nullif(j.leitos_sus_operacionais * j.dias_no_mes, 0), 4)  as taxa_ocupacao,
    round(j.pacientes_dia_competencia / nullif(j.saidas, 0), 2)                       as media_permanencia_dias,
    round(j.dias_perm_saidas / nullif(j.saidas, 0), 2)                                as media_permanencia_saidas_dias,
    round(j.saidas / nullif(j.leitos_sus_operacionais, 0), 2)                         as giro_leito,
    round((j.leitos_sus_operacionais * j.dias_no_mes - j.pacientes_dia) / nullif(j.saidas, 0), 2) as intervalo_substituicao,
    round(j.obitos / nullif(j.saidas, 0), 4)                                          as taxa_mortalidade_geral,
    round(j.obitos_24h_mais / nullif(j.saidas, 0), 4)                                 as taxa_mortalidade_inst_24h,
    round(j.obitos_48h_mais / nullif(j.saidas, 0), 4)                                 as taxa_mortalidade_inst_48h
from j
order by cnes, competencia
