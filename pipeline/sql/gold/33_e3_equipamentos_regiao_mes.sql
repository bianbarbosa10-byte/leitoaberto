-- GOLD | ESTUDO 3 - equipamentos selecionados por regiao de saude x competencia, com parametro de necessidade.
-- Parametros (habitantes por equipamento): tomografo 100 mil, ressonancia 500 mil, mamografo 240 mil.
with e as (
    select e.competencia, m.regiao_saude, e.equipamento_estudo as equipamento,
           sum(e.qt_existente)                                as existentes,
           sum(e.qt_em_uso)                                   as em_uso,
           sum(e.qt_existente) filter (where e.disponivel_sus) as disponiveis_sus
    from silver.cnes_equipamento e
    left join silver.dim_municipio m on m.cod_mun6 = e.cod_mun
    where e.equipamento_estudo is not null
    group by all
),
pop as (
    select p.ano, m.regiao_saude, sum(p.populacao) as populacao
    from gold.populacao p join silver.dim_municipio m using (cod_mun6)
    group by all
),
par(equipamento, hab_por_equipamento) as (values
    ('Tomógrafo', 100000), ('Ressonância magnética', 500000), ('Mamógrafo', 240000)
)
select
    e.competencia,
    e.regiao_saude,
    e.equipamento,
    e.existentes,
    e.em_uso,
    coalesce(e.disponiveis_sus, 0)                                       as disponiveis_sus,
    p.populacao,
    par.hab_por_equipamento                                              as parametro_hab_por_equipamento,
    round(p.populacao / par.hab_por_equipamento, 1)                      as necessidade_parametro,
    round(100000.0 * coalesce(e.disponiveis_sus, 0) / nullif(p.populacao, 0), 2) as sus_100milhab
from e
left join pop p on p.ano = left(e.competencia, 4)::int and p.regiao_saude = e.regiao_saude
left join par on par.equipamento = e.equipamento
order by e.competencia, e.equipamento, e.regiao_saude
