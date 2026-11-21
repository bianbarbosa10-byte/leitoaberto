-- GOLD | ESTUDO 1 - producao por procedimento: hospital x mes (competencia de processamento) x procedimento SIGTAP.
-- Atencao: o SIH so traz AIH APROVADAS; a producao real do hospital tende a ser maior
-- (AIH rejeitadas, glosadas, em reapresentacao ou nao faturadas nao aparecem aqui).
select
    cnes,
    competencia,
    proc_rea,
    count(*)                                          as aih_aprovadas,
    count(*) filter (where eh_saida)                  as saidas,
    sum(dias_perm)                                    as pacientes_dia,
    count(*) filter (where obito)                     as obitos,
    count(*) filter (where obito and dias_perm >= 2)  as obitos_48h_mais,
    round(sum(valor_total), 2)                        as valor_total_aih
from silver.sih_aih
group by all
order by cnes, competencia, aih_aprovadas desc
