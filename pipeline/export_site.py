"""Exporta da camada GOLD os recortes que o site usa (JSON pequenos em site/src/data e site/public/data).

Fonte: Neon (schema gold) quando DATABASE_URL existe; senao, os Parquet locais em data/gold.
Uso:  python -m pipeline.export_site
"""
import json
from datetime import date, datetime
from decimal import Decimal

import duckdb
import requests

from . import config as C

SITE_DATA = C.RAIZ / "site" / "src" / "data"
SITE_PUBLIC = C.RAIZ / "site" / "public" / "data"


def _con():
    con = duckdb.connect()
    if C.DATABASE_URL:
        con.execute("install postgres; load postgres")
        con.execute(f"attach '{C.DATABASE_URL}' as neon (type postgres, read_only)")
        fonte = "neon"
        for (t,) in con.execute("select table_name from duckdb_tables() where database_name = 'neon' "
                                "and schema_name = 'gold'").fetchall():
            con.execute(f"create view {t} as select * from neon.gold.{t}")
    else:
        fonte = "parquet local"
        for p in C.GOLD.glob("*.parquet"):
            con.execute(f"create view {p.stem} as select * from read_parquet('{p.as_posix()}')")
    print(f"export_site: lendo a gold de {fonte}")
    return con


def _json(v):
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    if isinstance(v, Decimal):
        return float(v)
    raise TypeError(type(v))


def salvar(con, nome, sql):
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    linhas = [dict(zip(cols, r)) for r in cur.fetchall()]
    SITE_DATA.mkdir(parents=True, exist_ok=True)
    (SITE_DATA / f"{nome}.json").write_text(json.dumps(linhas, default=_json, ensure_ascii=False), encoding="utf-8")
    print(f"  {nome:28s} {len(linhas):>6} linhas")


def _sem_ilhas_oceanicas(g) -> bytes:
    """Vitoria inclui Trindade e Martim Vaz (~1.100 km mar adentro), o que estraga o enquadramento do mapa.
    Remove os poligonos a leste de 39 graus O (o continente do ES vai ate ~39,7 O)."""
    def no_continente(anel):
        return max(p[0] for p in anel) < -39.0
    for f in g["features"]:
        geom = f["geometry"]
        if geom["type"] == "MultiPolygon":
            partes = [poly for poly in geom["coordinates"] if no_continente(poly[0])]
            geom["coordinates"] = partes
            if len(partes) == 1:
                geom["type"], geom["coordinates"] = "Polygon", partes[0]
    return json.dumps(g, separators=(",", ":")).encode()


def _colunar(con, sql):
    """Resultado em formato colunar compacto {coluna: [valores]} (bem menor que lista de objetos)."""
    cur = con.execute(sql)
    cols = [d[0] for d in cur.description]
    linhas = cur.fetchall()
    def v(x):
        if isinstance(x, Decimal):
            x = float(x)
        if isinstance(x, float):
            return round(x, 2) if not x.is_integer() else int(x)
        return x
    return {c: [v(r[i]) for r in linhas] for i, c in enumerate(cols)}


def _gravar_publico(rel, obj):
    p = SITE_PUBLIC / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, default=_json, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    return p.stat().st_size


def exportar_estudo1(con):
    """Dados do Estudo 1 para filtros no navegador (ano, mes, estabelecimento):
      e1/indice.json       meses, hospitais e dicionario de procedimentos
      e1/todos.json        hospital x mes (todos), perfil e procedimentos do ES inteiro por mes
      e1/h/<cnes>.json     perfil e procedimentos de um hospital por mes (baixado so quando escolhido)"""
    import shutil
    shutil.rmtree(SITE_PUBLIC / "e1", ignore_errors=True)
    indice = {
        "meses": _colunar(con, "select competencia, status_dados, completude_sih from dim_calendario order by 1"),
        "hospitais": _colunar(con, """select cnes, hospital, municipio, regiao_saude, grupo_natureza, porte
                                      from dim_hospital where tem_aih order by hospital"""),
        "procedimentos": _colunar(con, """select proc_rea, procedimento, cod_grupo, grupo, subgrupo, complexidade
                                          from dim_procedimento order by proc_rea"""),
    }
    tam = _gravar_publico("e1/indice.json", indice)
    todos = {
        "hosp_mes": _colunar(con, """
            select cnes, competencia, pacientes_dia, leitos_dia, leitos_sus_operacionais, saidas, aih_aprovadas,
                   pacientes_dia_competencia, obitos, obitos_48h_mais, round(valor_total_aih, 2) valor_total_aih
            from e1_hospital_mes order by cnes, competencia"""),
        "perfil": _colunar(con, """
            select competencia, carater, faixa_etaria, complexidade, sum(saidas) saidas, sum(pacientes_dia) pacientes_dia,
                   sum(obitos_48h_mais) obitos_48h_mais
            from e1_perfil_internacao group by all order by 1, 2, 3, 4"""),
        "proc": _colunar(con, """
            select competencia, proc_rea, sum(aih_aprovadas) aih, sum(saidas) saidas, sum(pacientes_dia) dias,
                   sum(obitos) obitos, round(sum(valor_total_aih), 2) valor
            from e1_procedimento_mes group by all order by 1, 2"""),
    }
    tam += _gravar_publico("e1/todos.json", todos)
    n = 0
    for (cnes,) in con.execute("select cnes from dim_hospital where tem_aih").fetchall():
        h = {
            "perfil": _colunar(con, f"""
                select competencia, carater, faixa_etaria, complexidade, saidas, pacientes_dia, obitos_48h_mais
                from e1_perfil_internacao where cnes = '{cnes}' order by 1, 2, 3, 4"""),
            "proc": _colunar(con, f"""
                select competencia, proc_rea, aih_aprovadas aih, saidas, pacientes_dia dias, obitos, valor_total_aih valor
                from e1_procedimento_mes where cnes = '{cnes}' order by 1, 2"""),
        }
        tam += _gravar_publico(f"e1/h/{cnes}.json", h)
        n += 1
    print(f"  e1/ (indice, todos, {n} hospitais)  {tam / 1024:,.0f} KB")


def main():
    con = _con()
    exportar_estudo1(con)

    salvar(con, "meta", "select * from meta_atualizacao")
    salvar(con, "calendario", "select competencia, ano, mes, mes_ano, dias_no_mes, completude_sih, status_dados "
                              "from dim_calendario order by competencia")

    # ---------------- Estudo 1
    salvar(con, "e1_es_mes", """
        select e.competencia, c.status_dados,
               sum(pacientes_dia) pacientes_dia, sum(leitos_dia) leitos_dia, sum(saidas) saidas,
               sum(pacientes_dia_competencia) pacientes_dia_competencia, sum(leitos_sus_operacionais) leitos_sus_operacionais,
               sum(obitos) obitos, sum(obitos_48h_mais) obitos_48h_mais, sum(valor_total_aih) valor_total_aih
        from e1_hospital_mes e join dim_calendario c using (competencia)
        group by all order by 1""")
    salvar(con, "e1_hospital_ano", """
        select left(e.competencia, 4)::int ano, e.cnes, h.hospital, h.municipio, h.regiao_saude, h.natureza_juridica,
               h.grupo_natureza, h.tipo_gestao, h.porte, h.lat, h.lon,
               count(distinct e.competencia) meses,
               sum(pacientes_dia) pacientes_dia, sum(leitos_dia) leitos_dia, sum(saidas) saidas,
               sum(pacientes_dia_competencia) pacientes_dia_competencia,
               round(avg(leitos_sus_operacionais), 1) leitos_sus_medios,
               sum(obitos) obitos, sum(obitos_24h_mais) obitos_24h_mais, sum(obitos_48h_mais) obitos_48h_mais,
               sum(valor_total_aih) valor_total_aih
        from e1_hospital_mes e join dim_hospital h using (cnes)
        group by all
        having sum(saidas) > 0 or sum(leitos_dia) > 0
        order by ano, saidas desc, e.cnes""")
    salvar(con, "e1_hospital_mes", """
        select cnes, competencia, pacientes_dia, leitos_dia, saidas, pacientes_dia_competencia,
               leitos_sus_operacionais, obitos, obitos_48h_mais
        from e1_hospital_mes where saidas > 0 or leitos_dia > 0 order by cnes, competencia""")
    salvar(con, "e1_perfil_ano", """
        select left(competencia, 4)::int ano, carater, faixa_etaria, complexidade,
               sum(saidas) saidas, sum(pacientes_dia) pacientes_dia, sum(obitos) obitos, sum(obitos_48h_mais) obitos_48h_mais
        from e1_perfil_internacao group by all order by 1, 2, 3, 4""")

    # ---------------- Estudo 2
    salvar(con, "e2_regiao_ano", "select * from e2_regiao_ano order by ano, regiao_saude")
    salvar(con, "e2_municipio_ano", "select * from e2_municipio_ano order by ano, municipio")
    salvar(con, "e2_fluxo_regiao_ano", "select * from e2_fluxo_regiao_ano")
    salvar(con, "e2_fluxo_municipio_ano", """
        select * from e2_fluxo_municipio_ano
        qualify row_number() over (partition by ano order by internacoes desc, cod_origem, cod_destino) <= 150
        order by ano, internacoes desc, cod_origem, cod_destino""")
    salvar(con, "e2_evasao_perfil_ano", "select * from e2_evasao_perfil_ano where dimensao <> 'subgrupo' or internacoes >= 30")
    salvar(con, "e2_procedimento_ano", """
        select * from e2_procedimento_evasao_ano
        qualify row_number() over (partition by ano order by fora_da_regiao desc, proc_rea) <= 20
        order by ano, fora_da_regiao desc, proc_rea""")
    salvar(con, "e2_evasao_mensal", "select * from e2_evasao_mensal order by competencia, regiao_saude")

    # ---------------- Estudo 3
    salvar(con, "e3_leitos_regiao_mes", "select * from e3_leitos_regiao_mes order by competencia, regiao_saude")
    salvar(con, "e3_leitos_municipio", """
        select * from e3_leitos_municipio_mes
        where competencia = (select max(competencia) from e3_leitos_municipio_mes) order by municipio""")
    salvar(con, "e3_leitos_tipo", """
        select regiao_saude, tipo_leito, sum(leitos_existentes) leitos_existentes, sum(leitos_sus) leitos_sus
        from e3_leitos_tipo_regiao_mes
        where competencia = (select max(competencia) from e3_leitos_tipo_regiao_mes)
        group by all order by 1, 2""")
    salvar(con, "e3_equipamentos_regiao", """
        select * from e3_equipamentos_regiao_mes
        where competencia = (select max(competencia) from e3_equipamentos_regiao_mes) order by equipamento, regiao_saude""")
    salvar(con, "e3_servicos_regiao", """
        select * from e3_servicos_regiao_mes
        where competencia = (select max(competencia) from e3_servicos_regiao_mes) order by servico, regiao_saude""")

    # ---------------- malha municipal (mapa)
    SITE_PUBLIC.mkdir(parents=True, exist_ok=True)
    local = C.BRONZE / "ibge" / "malha_es_municipios.geojson"
    try:
        geo = requests.get(C.IBGE_MALHA, timeout=60, headers={"User-Agent": "LeitoAberto-site"}).content
        json.loads(geo)
    except Exception:
        geo = local.read_bytes()
    geo = _sem_ilhas_oceanicas(json.loads(geo))
    (SITE_PUBLIC / "es_municipios.geojson").write_bytes(geo)
    print(f"  es_municipios.geojson        {len(geo) / 1024:,.0f} KB")


if __name__ == "__main__":
    main()
