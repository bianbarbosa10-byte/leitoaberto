-- GOLD | ESTUDO 1 - perfil das internacoes por hospital x mes x carater x faixa etaria x complexidade
-- (visoes de perfil para permanencia e mortalidade). Competencia de processamento da AIH.
select
    cnes,
    competencia,
    carater,
    faixa_etaria,
    complexidade,
    count(*)                                          as aih_aprovadas,
    count(*) filter (where eh_saida)                  as saidas,
    sum(dias_perm)                                    as pacientes_dia,
    count(*) filter (where obito)                     as obitos,
    count(*) filter (where obito and dias_perm >= 1)  as obitos_24h_mais,
    count(*) filter (where obito and dias_perm >= 2)  as obitos_48h_mais,
    round(sum(valor_total), 2)                        as valor_total_aih
from silver.sih_aih
group by all
order by cnes, competencia, carater, faixa_etaria, complexidade
