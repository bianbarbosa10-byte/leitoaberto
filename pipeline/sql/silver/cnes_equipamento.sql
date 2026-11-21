-- SILVER: equipamentos por estabelecimento x competencia (CNES-EQ).
-- equipamento_estudo = agrupamento usado no Estudo 3 (nulo = equipamento fora do recorte do estudo).
with eq as (
    select * from read_parquet('{bronze}/datasus/cnes_eq/*.parquet', union_by_name = true)
),
dom as (
    select codigo, descricao from read_csv('{seeds}/dominios.csv', all_varchar = true)
    where dominio = 'tipequip+codequip'
),
t as (
    select
        lpad(eq.cnes, 7, '0')                                       as cnes,
        eq.codufmun                                                 as cod_mun,
        left(eq.competen, 4) || '-' || substr(eq.competen, 5, 2)    as competencia,
        try_cast(eq.tipequip as int)                                as tipo_equipamento,
        try_cast(eq.codequip as int)                                as cod_equipamento,
        coalesce(try_cast(eq.qt_exist as int), 0)                   as qt_existente,
        coalesce(try_cast(eq.qt_uso as int), 0)                     as qt_em_uso,
        eq.ind_sus = '1'                                            as disponivel_sus
    from eq
)
select
    t.*,
    t.tipo_equipamento || '-' || t.cod_equipamento                  as chave_equipamento,
    d.descricao                                                     as descricao_equipamento,
    case t.tipo_equipamento || '-' || t.cod_equipamento
        when '1-11' then 'Tomógrafo' when '1-12' then 'Ressonância magnética'
        when '1-2' then 'Mamógrafo' when '1-3' then 'Mamógrafo' when '1-17' then 'Mamógrafo'
        when '1-13' then 'Ultrassom' when '1-14' then 'Ultrassom' when '1-15' then 'Ultrassom'
        when '1-18' then 'PET/CT' when '5-64' then 'Respirador/ventilador'
    end                                                             as equipamento_estudo
from t
left join dom d on d.codigo = t.tipo_equipamento || '-' || t.cod_equipamento
