-- GOLD: 1 linha por hospital (CNES) que teve AIH no periodo ou tem leitos no CNES.
-- Atributos do cadastro (CNES-ST) da competencia mais recente; nome curto do projeto PIH quando existir.
with cnes_aih as (
    select cnes, count(*) as aih_periodo from silver.sih_aih group by cnes
),
cnes_leito as (
    select distinct cnes from silver.cnes_leito
),
todos as (
    select cnes from cnes_aih union select cnes from cnes_leito
),
st as (
    select * from silver.cnes_estabelecimento
    qualify row_number() over (partition by cnes order by competencia desc) = 1
),
ult_leito as (
    select cnes, sum(leitos_sus) filter (where considera_ocupacao) as leitos_sus_operacionais,
           sum(leitos_existentes) as leitos_existentes
    from silver.cnes_leito
    where competencia = (select max(competencia) from silver.cnes_leito)
    group by cnes
),
pih as (
    select lpad(cnes, 7, '0') as cnes, unidade_hospitalar, tipo_demanda
    from read_csv('{seeds}/hospitais_pih.csv', all_varchar = true)
)
select
    t.cnes,
    coalesce(pih.unidade_hospitalar, st.nome_fantasia, 'CNES ' || t.cnes)   as hospital,
    st.razao_social,
    st.cnpj,
    st.cod_mun                                                              as cod_mun6,
    m.municipio,
    m.regiao_saude,
    st.tipo_gestao,
    st.cod_natureza_juridica,
    st.natureza_juridica,
    st.grupo_natureza,
    st.cod_tipo_unidade,
    st.tipo_unidade,
    pih.tipo_demanda,
    coalesce(l.leitos_sus_operacionais, 0)                                  as leitos_sus_operacionais_ultimo_mes,
    coalesce(l.leitos_existentes, 0)                                        as leitos_existentes_ultimo_mes,
    case
        when coalesce(l.leitos_sus_operacionais, 0) < 50 then '1 Pequeno (<50)'
        when l.leitos_sus_operacionais < 150 then '2 Médio (50-149)'
        when l.leitos_sus_operacionais < 300 then '3 Grande (150-299)'
        else '4 Especial (300+)'
    end                                                                     as porte,
    coalesce(a.aih_periodo, 0) > 0                                          as tem_aih,
    coalesce(st.lat, m.lat)                                                 as lat,
    coalesce(st.lon, m.lon)                                                 as lon
from todos t
left join st on st.cnes = t.cnes
left join pih on pih.cnes = t.cnes
left join ult_leito l on l.cnes = t.cnes
left join cnes_aih a on a.cnes = t.cnes
left join silver.dim_municipio m on m.cod_mun6 = st.cod_mun
order by hospital
