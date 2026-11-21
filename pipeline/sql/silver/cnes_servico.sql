-- SILVER: servicos especializados por estabelecimento x competencia (CNES-SR).
-- servico_estudo = recorte de servicos usado no Estudo 3 (nulo = fora do recorte).
with sr as (
    select * from read_parquet('{bronze}/datasus/cnes_sr/*.parquet', union_by_name = true)
),
dom as (
    select dominio, codigo, descricao from read_csv('{seeds}/dominios.csv', all_varchar = true)
)
select
    lpad(sr.cnes, 7, '0')                                       as cnes,
    sr.codufmun                                                 as cod_mun,
    left(sr.competen, 4) || '-' || substr(sr.competen, 5, 2)    as competencia,
    sr.serv_esp                                                 as cod_servico,
    sr.class_sr                                                 as cod_classificacao,
    ds.descricao                                                as descricao_servico,
    dc.descricao                                                as descricao_classificacao,
    sr.amb_sus = '1'                                            as ambulatorial_sus,
    sr.hosp_sus = '1'                                           as hospitalar_sus,
    (sr.amb_sus = '1' or sr.hosp_sus = '1')                     as oferta_sus,
    case sr.serv_esp
        when '162' then 'Terapia intensiva' when '132' then 'Oncologia' when '116' then 'Cardiologia'
        when '130' then 'Doença renal crônica' when '155' then 'Traumato-ortopedia'
        when '105' then 'Neurologia/neurocirurgia' when '112' then 'Pré-natal, parto e nascimento'
        when '140' then 'Urgência e emergência' when '149' then 'Transplante' when '151' then 'Medicina nuclear'
        when '128' then 'Hemoterapia' when '121' then 'Diagnóstico por imagem' when '142' then 'Endoscopia'
        when '150' then 'Cirurgia vascular' when '169' then 'Urologia' when '115' then 'Atenção psicossocial'
    end                                                         as servico_estudo
from sr
left join dom ds on ds.dominio = 'serv_esp' and ds.codigo = sr.serv_esp
left join dom dc on dc.dominio = 'serv_esp+class_sr' and dc.codigo = sr.serv_esp || '-' || sr.class_sr
