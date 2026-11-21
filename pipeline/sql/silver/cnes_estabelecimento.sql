-- SILVER: cadastro dos estabelecimentos por competencia (CNES-ST) + nome/coordenadas da API de dados abertos.
with st as (
    select * from read_parquet('{bronze}/datasus/cnes_st/*.parquet', union_by_name = true)
),
dom as (
    select dominio, codigo, descricao from read_csv('{seeds}/dominios.csv', all_varchar = true)
),
api as (
    select * from read_parquet('{bronze}/cnes_api/estabelecimentos.parquet')
)
select
    lpad(st.cnes, 7, '0')                                       as cnes,
    left(st.competen, 4) || '-' || substr(st.competen, 5, 2)    as competencia,
    st.codufmun                                                 as cod_mun,
    nullif(api.nome_fantasia, 'None')                           as nome_fantasia,
    nullif(api.nome_razao_social, 'None')                       as razao_social,
    case when st.pf_pj = '3' then st.cpf_cnpj end               as cnpj,        -- so pessoa juridica (LGPD)
    try_cast(st.tp_unid as int)                                 as cod_tipo_unidade,
    dt.descricao                                                as tipo_unidade,
    st.nat_jur                                                  as cod_natureza_juridica,
    dn.descricao                                                as natureza_juridica,
    case left(st.nat_jur, 1)
        when '1' then 'Administração Pública' when '2' then 'Entidades Empresariais'
        when '3' then 'Entidades sem Fins Lucrativos' when '4' then 'Pessoas Físicas'
    end                                                         as grupo_natureza,
    case st.tpgestao when 'M' then 'Municipal' when 'E' then 'Estadual' when 'D' then 'Dupla' end as tipo_gestao,
    st.vinc_sus = '1'                                           as vinculo_sus,
    st.atendhos = '1'                                           as atendimento_hospitalar,
    st.urgemerg = '1'                                           as urgencia_emergencia,
    try_cast(nullif(api.latitude_estabelecimento_decimo_grau, 'None') as double)  as lat,
    try_cast(nullif(api.longitude_estabelecimento_decimo_grau, 'None') as double) as lon
from st
left join api on api.codigo_cnes = lpad(st.cnes, 7, '0')
left join dom dt on dt.dominio = 'tp_unid' and try_cast(dt.codigo as int) = try_cast(st.tp_unid as int)
left join dom dn on dn.dominio = 'nat_jur' and dn.codigo = st.nat_jur
