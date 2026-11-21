"""Camada BRONZE: copia fiel das fontes, sem regra de negocio.

  bronze/datasus/<fonte>/raw/<ARQ>.dbc      arquivo original do FTP do DATASUS (imutavel)
  bronze/datasus/<fonte>/<ARQ>.parquet      mesmo conteudo em Parquet, tudo texto + metadados de carga
  bronze/ibge/*.json|.geojson|.parquet      populacao (SIDRA 6579), municipios e malha do IBGE
  bronze/cnes_api/estabelecimentos.parquet  nome/endereco/coordenadas dos estabelecimentos (API dados abertos)
  bronze/_manifest.json                     controle de carga (o que ja foi baixado, tamanho e data no FTP)

Incremental e idempotente: so baixa arquivo novo ou que mudou (tamanho/data) no FTP.
"""
import ftplib
import hashlib
import io
import json
import re
import time
from datetime import datetime, timezone

import pandas as pd
import requests

from . import config as C
from . import storage
from .dbc import dbc_bytes_to_dbf
from .dbf import ler_dbf

MANIFESTO = C.BRONZE / "_manifest.json"
AGORA = lambda: datetime.now(timezone.utc).isoformat(timespec="seconds")  # noqa: E731


def ler_manifesto():
    if MANIFESTO.exists():
        return json.loads(MANIFESTO.read_text(encoding="utf-8"))
    return {"arquivos": {}, "fontes_web": {}, "execucoes": []}


def gravar_manifesto(m):
    MANIFESTO.parent.mkdir(parents=True, exist_ok=True)
    MANIFESTO.write_text(json.dumps(m, ensure_ascii=False, indent=1, sort_keys=True), encoding="utf-8")
    storage.enviar(MANIFESTO)


def _tentar(fn, tentativas=4, espera=15):
    for i in range(tentativas):
        try:
            return fn()
        except Exception as e:  # FTP do DATASUS cai com frequencia
            if i == tentativas - 1:
                raise
            print(f"    falhou ({e.__class__.__name__}: {e}); nova tentativa em {espera * (i + 1)}s", flush=True)
            time.sleep(espera * (i + 1))


# ---------------------------------------------------------------- DATASUS (FTP)
LISTA = re.compile(r"^(\d\d-\d\d-\d\d)\s+(\d\d:\d\d[AP]M)\s+(\d+)\s+(\S+)$")


def _ftp():
    f = ftplib.FTP(C.FTP_HOST, timeout=60)
    f.login()
    return f


def listar_ftp(diretorio, prefixo):
    """Arquivos <prefixo>ES<AAMM>.dbc do diretorio, a partir de C.INICIO -> {nome: (tamanho, modificado, comp)}."""
    def _ler():
        linhas = []
        with _ftp() as f:
            f.cwd(diretorio)
            f.retrlines("LIST", linhas.append)
        return linhas
    out = {}
    padrao = re.compile(rf"^{prefixo}{C.UF}(\d\d)(\d\d)\.dbc$", re.I)
    for ln in _tentar(_ler):
        m = LISTA.match(ln.strip())
        if not m:
            continue
        data, hora, tam, nome = m.groups()
        a = padrao.match(nome)
        if not a:
            continue
        comp = f"20{a.group(1)}-{a.group(2)}"
        if comp >= C.INICIO:
            modif = datetime.strptime(f"{data} {hora}", "%m-%d-%y %I:%M%p").isoformat()
            out[nome.upper()] = (int(tam), modif, comp)
    return out


def baixar_ftp(diretorio, nome) -> bytes:
    def _ler():
        buf = io.BytesIO()
        with _ftp() as f:
            f.cwd(diretorio)
            f.retrbinary(f"RETR {nome}", buf.write)
        return buf.getvalue()
    return _tentar(_ler)


def _pseudo(s: pd.Series) -> pd.Series:
    u = {v: hashlib.sha256(f"{C.SALT}|{v}".encode()).hexdigest()[:20] for v in s.dropna().unique()}
    return s.map(u)


def dbc_para_parquet(fonte, nome, raw: bytes, comp, modif):
    df = ler_dbf(dbc_bytes_to_dbf(raw))
    cols = C.COLUNAS.get(fonte)
    if cols:
        df = df[[c for c in cols if c in df.columns]]
    for c in C.HASHEAR.get(fonte, []):
        if c in df.columns:
            df[c] = _pseudo(df[c])
    df["_arquivo"], df["_competencia"], df["_ftp_modificado"], df["_ingerido_em"] = nome, comp, modif, AGORA()
    destino = C.BRONZE / "datasus" / fonte / nome.replace(".DBC", ".parquet")
    destino.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(destino, index=False, compression="zstd")
    return destino, len(df)


def ingerir_datasus(man, so=None, forcar=False):
    novos = []
    for fonte, (diretorio, prefixo) in C.FONTES.items():
        if so and fonte not in so:
            continue
        try:
            remotos = listar_ftp(diretorio, prefixo)
        except Exception as e:  # FTP fora do ar: segue com as outras fontes; o agendamento tenta de novo amanha
            print(f"{fonte}: AVISO - FTP nao respondeu ({e.__class__.__name__}); fonte pulada nesta execucao", flush=True)
            man.setdefault("falhas", {})[fonte] = AGORA()
            continue
        print(f"{fonte}: {len(remotos)} arquivos no FTP desde {C.INICIO}", flush=True)
        for nome, (tam, modif, comp) in sorted(remotos.items()):
            atual = man["arquivos"].get(nome)
            parquet = C.BRONZE / "datasus" / fonte / nome.replace(".DBC", ".parquet")
            if not forcar and atual and atual["tamanho"] == tam and atual["modificado"] == modif and parquet.exists():
                continue
            t0 = time.time()
            try:
                raw = baixar_ftp(diretorio, nome)
            except Exception as e:
                print(f"  {nome}: AVISO - download falhou ({e.__class__.__name__}); fica para a proxima execucao", flush=True)
                continue
            bruto = C.BRONZE / "datasus" / fonte / "raw" / nome
            bruto.parent.mkdir(parents=True, exist_ok=True)
            bruto.write_bytes(raw)
            destino, linhas = dbc_para_parquet(fonte, nome, raw, comp, modif)
            storage.enviar(bruto)
            storage.enviar(destino)
            motivo = "novo" if not atual else "atualizado no FTP"
            man["arquivos"][nome] = dict(fonte=fonte, competencia=comp, tamanho=tam, modificado=modif,
                                         linhas=linhas, ingerido_em=AGORA())
            gravar_manifesto(man)  # grava a cada arquivo: se cair no meio, a proxima execucao continua dali
            novos.append(nome)
            print(f"  {nome:14s} {linhas:>8,} linhas  {motivo:18s} {time.time() - t0:5.1f}s", flush=True)
    return novos


# ---------------------------------------------------------------- IBGE e API CNES
def _get(url, **kw):
    def _ler():
        r = requests.get(url, timeout=120, headers={"User-Agent": "LeitoAberto-pipeline"}, **kw)
        r.raise_for_status()
        return r
    return _tentar(_ler, espera=10)


def _salvar_web(man, nome, conteudo: bytes):
    """Grava o arquivo bruto da web; retorna True se o conteudo mudou desde a ultima carga."""
    h = hashlib.sha256(conteudo).hexdigest()
    destino = C.BRONZE / "ibge" / nome
    if man["fontes_web"].get(nome, {}).get("sha256") == h and destino.exists():
        return False
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_bytes(conteudo)
    storage.enviar(destino)
    man["fontes_web"][nome] = dict(sha256=h, ingerido_em=AGORA())
    return True


def ingerir_ibge(man):
    mudou = []
    r = _get(C.SIDRA_POP)
    if _salvar_web(man, "sidra_6579_populacao.json", r.content):
        d = pd.DataFrame(r.json()[1:])
        d = d.rename(columns={"D1C": "cod_mun7", "D1N": "municipio", "D3C": "ano", "V": "valor"})
        d = d[["cod_mun7", "municipio", "ano", "valor"]].astype(str)
        d["_ingerido_em"] = AGORA()
        d.to_parquet(C.BRONZE / "ibge" / "populacao.parquet", index=False)
        storage.enviar(C.BRONZE / "ibge" / "populacao.parquet")
        mudou.append("populacao")
    r = _get(C.IBGE_MUNICIPIOS)
    if _salvar_web(man, "municipios.json", r.content):
        d = pd.DataFrame([{"cod_mun7": str(x["id"]), "municipio": x["nome"],
                           "microrregiao": x["microrregiao"]["nome"],
                           "regiao_imediata": x["regiao-imediata"]["nome"]} for x in r.json()])
        d.to_parquet(C.BRONZE / "ibge" / "municipios.parquet", index=False)
        storage.enviar(C.BRONZE / "ibge" / "municipios.parquet")
        mudou.append("municipios")
    r = _get(C.IBGE_MALHA)
    if _salvar_web(man, "malha_es_municipios.geojson", r.content):
        mudou.append("malha")
    print(f"ibge: {', '.join(mudou) or 'sem mudanca'}", flush=True)
    return mudou


def ingerir_cnes_api(man, cnes_lista):
    """Nome fantasia, endereco e coordenadas dos estabelecimentos (1 chamada por CNES)."""
    destino = C.BRONZE / "cnes_api" / "estabelecimentos.parquet"
    antigos = pd.read_parquet(destino) if destino.exists() else pd.DataFrame(columns=["codigo_cnes"])
    linhas, falhas = [], 0
    for cnes in sorted(cnes_lista):
        try:
            r = requests.get(C.CNES_API.format(cnes=int(cnes)), timeout=30,
                             headers={"User-Agent": "LeitoAberto-pipeline"})
            if r.status_code == 200 and r.content:
                linhas.append({k: (None if v is None else str(v)) for k, v in r.json().items()})
            else:
                falhas += 1
        except requests.RequestException:
            falhas += 1
        time.sleep(0.2)
    if not linhas:
        print("cnes_api: indisponivel, mantendo carga anterior", flush=True)
        return False
    novo = pd.DataFrame(linhas)
    novo["codigo_cnes"] = novo["codigo_cnes"].str.zfill(7)
    # mantem quem falhou desta vez com o dado anterior
    if len(antigos):
        antigos["codigo_cnes"] = antigos["codigo_cnes"].astype(str).str.zfill(7)
        novo = pd.concat([novo, antigos[~antigos.codigo_cnes.isin(novo.codigo_cnes)]], ignore_index=True)
    novo["_ingerido_em"] = AGORA()
    destino.parent.mkdir(parents=True, exist_ok=True)
    novo.astype(str).to_parquet(destino, index=False)
    storage.enviar(destino)
    man["fontes_web"]["cnes_api"] = dict(registros=len(novo), falhas=falhas, ingerido_em=AGORA())
    print(f"cnes_api: {len(novo)} estabelecimentos ({falhas} falhas)", flush=True)
    return True


def cnes_hospitalares():
    """CNES que aparecem no SIH (AIH) ou tem leitos no CNES-LT."""
    import duckdb
    g = lambda f: (C.BRONZE / "datasus" / f).as_posix() + "/*.parquet"  # noqa: E731
    q = f"select distinct lpad(cnes,7,'0') from read_parquet('{g('sih_rd')}') union " \
        f"select distinct lpad(cnes,7,'0') from read_parquet('{g('cnes_lt')}')"
    return [r[0] for r in duckdb.sql(q).fetchall() if r[0]]


def executar(so=None, forcar=False):
    """Roda a ingestao completa. Retorna a lista do que mudou (vazia = nada novo)."""
    baixados = storage.baixar("bronze/", ignorar_sufixo=(".dbc",))
    if baixados:
        print(f"R2 -> local: {baixados} arquivos da bronze", flush=True)
    man = ler_manifesto()
    mudou = ingerir_datasus(man, so=so, forcar=forcar)
    if not so:
        mudou += ingerir_ibge(man)
        api = C.BRONZE / "cnes_api" / "estabelecimentos.parquet"
        if mudou or not api.exists():
            ingerir_cnes_api(man, cnes_hospitalares())
    man["execucoes"] = (man["execucoes"] + [dict(em=AGORA(), mudou=mudou)])[-24:]
    gravar_manifesto(man)
    return mudou
