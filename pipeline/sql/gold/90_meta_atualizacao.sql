-- GOLD: metadados da ultima atualizacao (exibidos no site).
select
    now()::timestamp                                                   as atualizado_em,
    (select max(competencia) from silver.sih_aih)                       as ultima_competencia_sih,
    (select max(competencia) from silver.cnes_leito)                    as ultima_competencia_cnes,
    (select max(ano) from silver.ibge_populacao)                        as ultimo_ano_populacao,
    (select max(competencia) from gold.dim_calendario where status_dados = 'Consolidado') as ultima_competencia_consolidada,
    (select count(*) from silver.sih_aih)                               as aih_carregadas,
    (select count(*) from gold.dim_hospital where tem_aih)              as hospitais_com_aih,
    '{inicio}'                                                          as competencia_inicial
