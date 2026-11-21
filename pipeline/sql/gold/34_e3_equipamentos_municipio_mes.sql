-- GOLD | ESTUDO 3 - equipamentos selecionados por municipio x competencia.
select
    e.competencia,
    e.cod_mun                                           as cod_mun6,
    m.municipio,
    m.regiao_saude,
    e.equipamento_estudo                                as equipamento,
    sum(e.qt_existente)                                 as existentes,
    sum(e.qt_existente) filter (where e.disponivel_sus) as disponiveis_sus
from silver.cnes_equipamento e
left join silver.dim_municipio m on m.cod_mun6 = e.cod_mun
where e.equipamento_estudo is not null
group by all
order by e.competencia, m.municipio, equipamento
