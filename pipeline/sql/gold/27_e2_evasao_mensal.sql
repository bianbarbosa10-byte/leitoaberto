-- GOLD | ESTUDO 2 - serie mensal da evasao regional (residentes do ES), por regiao de residencia.
select
    competencia,
    regiao_res                                         as regiao_saude,
    count(*)                                           as internacoes,
    count(*) filter (where regiao_res <> regiao_int)   as fora_da_regiao,
    round(count(*) filter (where regiao_res <> regiao_int) / count(*), 4) as evasao
from gold.tmp_e2_internacao
where residente_es
group by all
order by competencia, regiao_saude
