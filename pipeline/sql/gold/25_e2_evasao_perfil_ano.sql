-- GOLD | ESTUDO 2 - evasao regional (internacao fora da regiao de residencia) por perfil, por ano.
-- dimensao: especialidade | complexidade | carater | subgrupo SIGTAP (4 primeiros digitos do procedimento)
with base as (
    select ano, regiao_res, regiao_int, especialidade, complexidade, carater, subgrupo_proc
    from gold.tmp_e2_internacao
    where residente_es
),
subgrupos(cod, nome) as (values
    ('0301','Consultas/atendimentos'), ('0303','Tratamentos clínicos'), ('0304','Tratamento em oncologia'),
    ('0305','Tratamento em nefrologia'), ('0308','Lesões e envenenamentos'), ('0310','Parto e nascimento'),
    ('0401','Pequenas cirurgias (pele/mucosa)'), ('0403','Cirurgia do sistema nervoso'),
    ('0404','Cirurgia cabeça e pescoço'), ('0405','Cirurgia do aparelho da visão'),
    ('0406','Cirurgia do aparelho circulatório'), ('0407','Cirurgia do aparelho digestivo'),
    ('0408','Cirurgia do sistema osteomuscular'), ('0409','Cirurgia do aparelho geniturinário'),
    ('0410','Cirurgia de mama'), ('0411','Cirurgia obstétrica'), ('0412','Cirurgia torácica'),
    ('0413','Cirurgia reparadora'), ('0414','Cirurgia bucomaxilofacial'), ('0415','Outras cirurgias'),
    ('0416','Cirurgia em oncologia'), ('0418','Cirurgia em nefrologia'), ('0501','Transplantes (coleta/exames)'),
    ('0505','Transplantes'), ('0506','Acompanhamento pós-transplante'), ('0201','Coleta de material'),
    ('0209','Diagnóstico por endoscopia'), ('0211','Diagnóstico em especialidades')
),
longo as (
    select ano, regiao_res, regiao_int, 'especialidade' as dimensao, especialidade as categoria from base
    union all select ano, regiao_res, regiao_int, 'complexidade', complexidade from base
    union all select ano, regiao_res, regiao_int, 'carater', carater from base
    union all select b.ano, b.regiao_res, b.regiao_int, 'subgrupo', coalesce(s.nome, b.subgrupo_proc)
              from base b left join subgrupos s on s.cod = b.subgrupo_proc
)
select
    ano,
    regiao_res                                         as regiao_saude,
    dimensao,
    categoria,
    count(*)                                           as internacoes,
    count(*) filter (where regiao_res <> regiao_int)   as fora_da_regiao,
    round(count(*) filter (where regiao_res <> regiao_int) / count(*), 4) as evasao
from longo
group by all
order by ano, regiao_saude, dimensao, internacoes desc
