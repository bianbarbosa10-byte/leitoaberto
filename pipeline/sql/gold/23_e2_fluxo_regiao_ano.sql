-- GOLD | ESTUDO 2 - matriz de fluxo regiao de residencia -> regiao de internacao (residentes do ES), por ano.
select
    ano,
    regiao_res                                   as regiao_residencia,
    regiao_int                                   as regiao_internacao,
    count(*)                                     as internacoes,
    round(count(*) / sum(count(*)) over (partition by ano, regiao_res), 4) as pct_da_origem
from gold.tmp_e2_internacao
where residente_es
group by ano, regiao_res, regiao_int
order by ano, regiao_residencia, regiao_internacao
