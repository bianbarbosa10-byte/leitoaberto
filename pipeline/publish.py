"""Publica a camada GOLD no Neon (PostgreSQL), que serve o site e o Power BI.

Carga atomica: tudo vai para o schema gold_novo; so no final, numa unica transacao, gold vira gold_antigo
e gold_novo vira gold. Se algo falhar no meio, o site continua lendo a versao anterior intacta.
A descricao de cada tabela (comentario no topo do .sql) vira COMMENT ON TABLE no Postgres.
"""
import re

import duckdb
import psycopg

from . import config as C


def _descricao(nome):
    for f in (C.SQL / "gold").glob(f"*{nome}.sql"):
        linhas = []
        for ln in f.read_text(encoding="utf-8").splitlines():
            if not ln.startswith("--"):
                break
            linhas.append(ln.lstrip("-").strip())
        return re.sub(r"\s+", " ", " ".join(linhas)).replace("'", "''")[:1000]
    return ""


def executar():
    if not C.DATABASE_URL:
        print("publish: DATABASE_URL nao definida, pulando publicacao no Neon")
        return False
    tabelas = sorted(p.stem for p in C.GOLD.glob("*.parquet"))
    with psycopg.connect(C.DATABASE_URL, autocommit=True) as pg:
        pg.execute("drop schema if exists gold_novo cascade")
        pg.execute("create schema gold_novo")
    con = duckdb.connect()
    con.execute("install postgres; load postgres")
    con.execute(f"attach '{C.DATABASE_URL}' as neon (type postgres)")
    for t in tabelas:
        con.execute(f"create table neon.gold_novo.{t} as select * from read_parquet('{(C.GOLD / (t + '.parquet')).as_posix()}')")
        n = con.execute(f"select count(*) from read_parquet('{(C.GOLD / (t + '.parquet')).as_posix()}')").fetchone()[0]
        print(f"  neon gold.{t:32s} {n:>10,} linhas", flush=True)
    con.close()
    with psycopg.connect(C.DATABASE_URL) as pg:
        for t in tabelas:
            d = _descricao(t)
            if d:
                pg.execute(f"comment on table gold_novo.{t} is '{d}'")
        pg.execute("drop schema if exists gold_antigo cascade")
        if pg.execute("select 1 from information_schema.schemata where schema_name = 'gold'").fetchone():
            pg.execute("alter schema gold rename to gold_antigo")
        pg.execute("alter schema gold_novo rename to gold")
        pg.execute("drop schema if exists gold_antigo cascade")
        pg.execute("""do $$ begin
                        if exists (select 1 from pg_roles where rolname = 'leitoaberto_leitura') then
                          grant usage on schema gold to leitoaberto_leitura;
                          grant select on all tables in schema gold to leitoaberto_leitura;
                        end if; end $$""")
    print(f"publish: {len(tabelas)} tabelas publicadas no schema gold do Neon", flush=True)
    return True
