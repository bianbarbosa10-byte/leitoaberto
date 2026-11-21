-- GOLD | ESTUDO 3 - leitos por tipo e especialidade de leito, regiao de saude x competencia.
select
    l.competencia,
    m.regiao_saude,
    l.tipo_leito,
    l.categoria,
    l.especialidade_leito,
    sum(l.leitos_existentes)  as leitos_existentes,
    sum(l.leitos_sus)         as leitos_sus,
    sum(l.leitos_nao_sus)     as leitos_nao_sus
from silver.cnes_leito l
left join silver.dim_municipio m on m.cod_mun6 = l.cod_mun
group by all
order by l.competencia, m.regiao_saude, l.tipo_leito, l.especialidade_leito
