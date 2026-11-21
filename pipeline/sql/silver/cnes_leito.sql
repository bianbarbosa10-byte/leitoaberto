-- SILVER: leitos por estabelecimento x competencia x tipo/especialidade de leito (CNES-LT).
with lt as (
    select * from read_parquet('{bronze}/datasus/cnes_lt/*.parquet', union_by_name = true)
),
dom as (
    select dominio, codigo, descricao from read_csv('{seeds}/dominios.csv', all_varchar = true)
),
t as (
    select
        lpad(lt.cnes, 7, '0')                                    as cnes,
        lt.codufmun                                              as cod_mun,
        left(lt.competen, 4) || '-' || substr(lt.competen, 5, 2) as competencia,
        try_cast(lt.tp_leito as int)                             as tp_leito,
        try_cast(lt.codleito as int)                             as cod_leito,
        coalesce(try_cast(lt.qt_exist as int), 0)                as leitos_existentes,
        coalesce(try_cast(lt.qt_sus as int), 0)                  as leitos_sus,
        coalesce(try_cast(lt.qt_nsus as int), 0)                 as leitos_nao_sus,
        lt.nat_jur,
        lt.tp_unid
    from lt
)
select
    t.*,
    case t.tp_leito
        when 1 then 'Cirúrgico' when 2 then 'Clínico' when 3 then 'Complementar' when 4 then 'Obstétrico'
        when 5 then 'Pediátrico' when 6 then 'Outras Especialidades' when 7 then 'Hospital/DIA'
    end                                                          as tipo_leito,
    d.descricao                                                  as especialidade_leito,
    -- Estudo 3: UTI = codigos de UTI/UCO adulto, pediatrica, neonatal e queimados
    case
        when t.cod_leito in (74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 85, 86) then 'UTI'
        when t.tp_leito in (1, 2, 4, 5, 6) then 'Internação'
        when t.tp_leito = 7 then 'Hospital-dia'
        else 'Outros complementares'
    end                                                          as categoria,
    -- Estudo 1: leitos operacionais = internacao + complementares (hospital-dia fica fora)
    t.tp_leito <> 7                                              as considera_ocupacao
from t
left join dom d on d.dominio = 'codleito' and try_cast(d.codigo as int) = t.cod_leito
