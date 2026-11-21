-- intermediaria do ESTUDO 2: internacoes principais (IDENT=1) com regiao de residencia/internacao e distancia.
select
    a.competencia,
    left(a.competencia, 4)::int                         as ano,
    a.cnes,
    a.cod_mun_res,
    a.cod_mun_int,
    a.residente_es,
    coalesce(mr.regiao_saude, 'Fora do ES')             as regiao_res,
    coalesce(mi.regiao_saude, '?')                      as regiao_int,
    a.especialidade,
    a.complexidade,
    a.carater,
    a.proc_rea,
    left(a.proc_rea, 4)                                 as subgrupo_proc,
    case
        when a.cod_mun_res = a.cod_mun_int then 0.0
        when mr.lat is not null and mi.lat is not null
            then round(haversine_km(mr.lat, mr.lon, mi.lat, mi.lon), 1)
    end                                                 as dist_km
from silver.sih_aih a
left join silver.dim_municipio mr on mr.cod_mun6 = a.cod_mun_res
left join silver.dim_municipio mi on mi.cod_mun6 = a.cod_mun_int
where a.ident = '1'
