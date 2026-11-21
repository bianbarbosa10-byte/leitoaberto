-- GOLD | ESTUDO 2 - fluxos intermunicipais (residente do ES internado em outro municipio), por ano.
-- Inclui coordenadas de origem e destino para mapas de fluxo.
select
    f.ano,
    f.cod_mun_res                      as cod_origem,
    o.municipio                        as origem,
    o.regiao_saude                     as regiao_origem,
    o.lat                              as lat_origem,
    o.lon                              as lon_origem,
    f.cod_mun_int                      as cod_destino,
    d.municipio                        as destino,
    d.regiao_saude                     as regiao_destino,
    d.lat                              as lat_destino,
    d.lon                              as lon_destino,
    f.internacoes,
    f.dist_km,
    o.regiao_saude <> d.regiao_saude   as entre_regioes
from (
    select ano, cod_mun_res, cod_mun_int, count(*) as internacoes, any_value(dist_km) as dist_km
    from gold.tmp_e2_internacao
    where residente_es and cod_mun_res <> cod_mun_int
    group by all
) f
left join silver.dim_municipio o on o.cod_mun6 = f.cod_mun_res
left join silver.dim_municipio d on d.cod_mun6 = f.cod_mun_int
order by f.ano, f.internacoes desc
