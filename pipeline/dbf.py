"""Leitor rapido de DBF (numpy) para os .dbf do DATASUS. Tudo vira texto (a tipagem fica para a Silver).
Parser proprio do cabecalho: o dbfread falha em arquivos com cabecalho grande (ex.: CNES-ST)."""
import struct
import numpy as np
import pandas as pd


def ler_dbf(buf: bytes, encoding="latin-1") -> pd.DataFrame:
    nrec, hs, rl = struct.unpack("<IHH", buf[4:12])
    campos, pos, off = [], 32, 1
    while pos + 32 <= hs and buf[pos] != 0x0D:
        nome = buf[pos:pos + 11].split(b"\0")[0].decode("latin-1").strip().lower()
        ln = buf[pos + 16]
        campos.append((nome, off, ln))
        off += ln
        pos += 32
    n = min(nrec, (len(buf) - hs) // rl)
    dados = np.frombuffer(buf, dtype=np.uint8, count=n * rl, offset=hs).reshape(n, rl)
    vivo = dados[:, 0] != 0x2A  # registro excluido
    cols = {}
    for nome, o, ln in campos:
        col = np.ascontiguousarray(dados[:, o:o + ln]).view(f"S{ln}").ravel()
        s = pd.Series(col).str.decode(encoding).str.replace("\x00", "", regex=False).str.strip()
        cols[nome] = s.replace("", None)
    df = pd.DataFrame(cols)
    return df[vivo].reset_index(drop=True)
