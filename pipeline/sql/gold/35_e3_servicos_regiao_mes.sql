-- GOLD | ESTUDO 3 - estabelecimentos com servicos especializados selecionados, por regiao x competencia.
select
    s.competencia,
    m.regiao_saude,
    s.servico_estudo                                        as servico,
    count(distinct s.cnes)                                  as estabelecimentos,
    count(distinct s.cnes) filter (where s.oferta_sus)      as estabelecimentos_sus
from silver.cnes_servico s
left join silver.dim_municipio m on m.cod_mun6 = s.cod_mun
where s.servico_estudo is not null
group by all
order by s.competencia, servico, m.regiao_saude
