"""Camadas SILVER e GOLD com DuckDB.

Cada arquivo pipeline/sql/<camada>/<nome>.sql e um SELECT. Ele vira a tabela <camada>.<nome> no DuckDB
(data/leitoaberto.duckdb) e e exportado para data/<camada>/<nome>.parquet. Na gold os arquivos rodam em
ordem alfabetica (prefixo numerico), entao uma tabela pode usar as anteriores.

Placeholders nos SQL: {bronze} {silver} {seeds} {inicio}
"""
import time

import duckdb

from . import config as C
from . import storage

DB = C.DATA / "leitoaberto.duckdb"


def _render(sql: str) -> str:
    return (sql.replace("{bronze}", C.BRONZE.as_posix())
               .replace("{silver}", C.SILVER.as_posix())
               .replace("{seeds}", C.SEEDS.as_posix())
               .replace("{inicio}", C.INICIO))


def conectar():
    C.DATA.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(str(DB))
    con.execute("set preserve_insertion_order = false")
    # distancia em linha reta (km) entre dois pontos
    con.execute("""create or replace macro haversine_km(lat1, lon1, lat2, lon2) as
        2 * 6371 * asin(sqrt(pow(sin(radians(lat2 - lat1) / 2), 2)
        + cos(radians(lat1)) * cos(radians(lat2)) * pow(sin(radians(lon2 - lon1) / 2), 2)))""")
    return con


def rodar_camada(con, camada: str, so=None):
    pasta_sql = C.SQL / camada
    saida = C.DATA / camada
    saida.mkdir(parents=True, exist_ok=True)
    con.execute(f"create schema if not exists {camada}")
    feitas = []
    for f in sorted(pasta_sql.glob("*.sql")):
        nome = f.stem.split("_", 1)[1] if f.stem[:2].isdigit() else f.stem
        if so and nome not in so:
            continue
        t0 = time.time()
        con.execute(f"create or replace table {camada}.{nome} as {_render(f.read_text(encoding='utf-8'))}")
        if nome.startswith("tmp_"):  # tabela intermediaria: usada pelas seguintes, nao e publicada
            n = con.execute(f"select count(*) from {camada}.{nome}").fetchone()[0]
            print(f"  {camada}.{nome:32s} {n:>10,} linhas  {time.time() - t0:5.1f}s (intermediaria)", flush=True)
            continue
        destino = saida / f"{nome}.parquet"
        con.execute(f"copy {camada}.{nome} to '{destino.as_posix()}' (format parquet, compression zstd)")
        n = con.execute(f"select count(*) from {camada}.{nome}").fetchone()[0]
        print(f"  {camada}.{nome:32s} {n:>10,} linhas  {time.time() - t0:5.1f}s", flush=True)
        feitas.append(destino)
    return feitas


def executar(enviar=True):
    con = conectar()
    try:
        print("silver:", flush=True)
        s = rodar_camada(con, "silver")
        print("gold:", flush=True)
        g = rodar_camada(con, "gold")
    finally:
        con.close()
    if enviar:
        for p in s + g:
            storage.enviar(p)
    return g
