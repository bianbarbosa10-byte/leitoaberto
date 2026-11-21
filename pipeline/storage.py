"""Data lake no Cloudflare R2 (API S3) com espelho local em data/.

O pipeline sempre le e escreve em data/ (rapido, simples de testar). Quando as credenciais do R2 existem:
  - baixar(prefixo)  traz do bucket o que falta/mudou localmente;
  - enviar(caminho)  sobe um arquivo local para a mesma chave no bucket.
Sem credenciais, tudo funciona so no disco (modo local).
"""
import hashlib
from pathlib import Path

from . import config as C


def _cliente():
    if not (C.R2_ACCOUNT_ID and C.R2_ACCESS_KEY_ID and C.R2_SECRET_ACCESS_KEY):
        return None
    import boto3
    from botocore.config import Config
    return boto3.client(
        "s3",
        endpoint_url=f"https://{C.R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
        aws_access_key_id=C.R2_ACCESS_KEY_ID,
        aws_secret_access_key=C.R2_SECRET_ACCESS_KEY,
        region_name="auto",
        config=Config(retries={"max_attempts": 5, "mode": "standard"}),
    )


_S3 = _cliente()
NUVEM = _S3 is not None


def chave(p: Path) -> str:
    return p.resolve().relative_to(C.DATA.resolve()).as_posix()


def _md5(p: Path) -> str:
    h = hashlib.md5()
    with open(p, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def baixar(prefixo: str, ignorar_sufixo: tuple = ()) -> int:
    """Sincroniza bucket -> data/ para as chaves que comecam com `prefixo`. Retorna quantos arquivos baixou."""
    if not NUVEM:
        return 0
    n = 0
    for pagina in _S3.get_paginator("list_objects_v2").paginate(Bucket=C.R2_BUCKET, Prefix=prefixo):
        for obj in pagina.get("Contents", []):
            k = obj["Key"]
            if ignorar_sufixo and k.lower().endswith(tuple(s.lower() for s in ignorar_sufixo)):
                continue
            local = C.DATA / k
            etag = obj["ETag"].strip('"')
            if local.exists() and local.stat().st_size == obj["Size"] and ("-" in etag or _md5(local) == etag):
                continue  # etag com "-" = upload multipart (nao e md5): compara so o tamanho
            local.parent.mkdir(parents=True, exist_ok=True)
            _S3.download_file(C.R2_BUCKET, k, str(local))
            n += 1
    return n


def enviar(p: Path):
    if NUVEM:
        _S3.upload_file(str(p), C.R2_BUCKET, chave(p))


def enviar_pasta(pasta: Path, padrao: str = "*"):
    n = 0
    for p in sorted(pasta.rglob(padrao)):
        if p.is_file():
            enviar(p)
            n += 1
    return n
