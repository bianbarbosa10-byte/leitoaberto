-- GOLD: procedimentos SIGTAP realizados no periodo, com grupo, subgrupo e complexidade.
-- Codigo SIGTAP: GG SS FF PPP D  (grupo, subgrupo, forma de organizacao, procedimento, digito).
with p as (
    select proc_rea,
           any_value(complexidade) as complexidade,
           count(*)                as aih_periodo
    from silver.sih_aih
    group by proc_rea
),
grupos(cod, nome) as (values
    ('01', 'Ações de promoção e prevenção em saúde'), ('02', 'Procedimentos com finalidade diagnóstica'),
    ('03', 'Procedimentos clínicos'), ('04', 'Procedimentos cirúrgicos'),
    ('05', 'Transplantes de órgãos, tecidos e células'), ('06', 'Medicamentos'),
    ('07', 'Órteses, próteses e materiais especiais'), ('08', 'Ações complementares da atenção à saúde')
),
subgrupos(cod, nome) as (values
    ('0201','Coleta de material'), ('0209','Diagnóstico por endoscopia'), ('0211','Diagnóstico em especialidades'),
    ('0301','Consultas e atendimentos'), ('0303','Tratamentos clínicos'), ('0304','Tratamento em oncologia'),
    ('0305','Tratamento em nefrologia'), ('0306','Hemoterapia'), ('0308','Lesões e envenenamentos'),
    ('0310','Parto e nascimento'), ('0401','Pequenas cirurgias (pele e mucosa)'), ('0403','Cirurgia do sistema nervoso'),
    ('0404','Cirurgia de cabeça e pescoço'), ('0405','Cirurgia do aparelho da visão'),
    ('0406','Cirurgia do aparelho circulatório'), ('0407','Cirurgia do aparelho digestivo'),
    ('0408','Cirurgia do sistema osteomuscular'), ('0409','Cirurgia do aparelho geniturinário'),
    ('0410','Cirurgia de mama'), ('0411','Cirurgia obstétrica'), ('0412','Cirurgia torácica'),
    ('0413','Cirurgia reparadora'), ('0414','Cirurgia bucomaxilofacial'), ('0415','Outras cirurgias'),
    ('0416','Cirurgia em oncologia'), ('0417','Anestesiologia'), ('0418','Cirurgia em nefrologia'),
    ('0501','Transplantes: coleta e exames'), ('0505','Transplantes'), ('0506','Acompanhamento pós-transplante')
)
select
    p.proc_rea,
    coalesce(s.procedimento, 'Procedimento ' || p.proc_rea)  as procedimento,
    left(p.proc_rea, 2)                                       as cod_grupo,
    coalesce(g.nome, 'Grupo ' || left(p.proc_rea, 2))         as grupo,
    left(p.proc_rea, 4)                                       as cod_subgrupo,
    coalesce(sg.nome, 'Subgrupo ' || left(p.proc_rea, 4))     as subgrupo,
    p.complexidade,
    p.aih_periodo
from p
left join read_csv('{seeds}/procedimentos_sigtap.csv', all_varchar = true) s on s.proc_rea = p.proc_rea
left join grupos g     on g.cod = left(p.proc_rea, 2)
left join subgrupos sg on sg.cod = left(p.proc_rea, 4)
order by p.aih_periodo desc
