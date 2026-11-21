-- SILVER: AIH reduzida do SIH (1 linha por AIH), tipada e com as categorias usadas nos estudos.
-- Fonte: bronze/datasus/sih_rd/RDES*.parquet
with rd as (
    select * from read_parquet('{bronze}/datasus/sih_rd/*.parquet', union_by_name = true)
),
t as (
    select
        n_aih,
        ident,                                                     -- 1 = principal, 5 = longa permanencia
        lpad(cnes, 7, '0')                                          as cnes,
        munic_res                                                   as cod_mun_res,
        munic_mov                                                   as cod_mun_int,
        ano_cmpt || '-' || lpad(mes_cmpt, 2, '0')                   as competencia,   -- competencia de processamento
        try_cast(espec as int)                                      as cod_espec,
        lpad(proc_rea, 10, '0')                                     as proc_rea,
        try_cast(complex as int)                                    as cod_complexidade,
        try_cast(car_int as int)                                    as cod_carater,
        coalesce(try_cast(dias_perm as int), 0)                     as dias_perm,
        coalesce(try_cast(morte as int), 0) = 1                     as obito,
        try_cast(cobranca as int)                                   as motivo_saida,
        coalesce(try_cast(val_tot as double), 0)                    as valor_total,
        try_cast(idade as int)                                      as idade,
        try_cast(cod_idade as int)                                  as cod_idade,
        try_strptime(dt_inter, '%Y%m%d')::date                      as dt_internacao,
        try_strptime(dt_saida, '%Y%m%d')::date                      as dt_saida,
        case sexo when '1' then 'Masculino' when '3' then 'Feminino' else 'Ignorado' end as sexo,
        diag_princ                                                  as cid_principal,
        coalesce(try_cast(uti_mes_to as int), 0)                    as dias_uti,
        _arquivo, _ingerido_em
    from rd
)
select
    *,
    -- idade em anos (cod_idade: 2 dias, 3 meses, 4 anos, 5 = 100 + idade)
    case cod_idade when 4 then idade when 5 then 100 + idade when 2 then 0 when 3 then 0 end as idade_anos,
    case
        when cod_idade in (2, 3) or (cod_idade = 4 and idade < 1) then '00 <1 ano'
        when cod_idade = 4 and idade <= 14 then '01 1-14'
        when cod_idade = 4 and idade <= 39 then '02 15-39'
        when cod_idade = 4 and idade <= 59 then '03 40-59'
        when cod_idade = 4 and idade <= 79 then '04 60-79'
        when cod_idade in (4, 5) then '05 80+'
    end                                                             as faixa_etaria,
    case cod_espec
        when 1 then 'Cirúrgico' when 2 then 'Obstétrico' when 3 then 'Clínico' when 4 then 'Crônico'
        when 5 then 'Psiquiatria' when 6 then 'Tisiologia' when 7 then 'Pediátrico' when 8 then 'Reabilitação'
        else 'Hospital-dia/Outros'
    end                                                             as especialidade,
    case when cod_complexidade = 3 then 'Alta' else 'Média' end      as complexidade,
    case cod_carater when 1 then 'Eletivo' when 2 then 'Urgência' else 'Outros (acidentes/lesões)' end as carater,
    -- saida = qualquer motivo que nao seja permanencia/continuacao (21-29)
    not coalesce(motivo_saida between 21 and 29, false)             as eh_saida,
    cod_mun_res like '32%'                                          as residente_es,
    -- periodo de ocupacao do leito (logica de censo): [dt_saida - dias_perm, dt_saida)
    dt_saida - dias_perm::int                                       as dt_inicio_ocupacao
from t
