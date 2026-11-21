"""Gera as tabelas de referencia (seeds/*.csv) a partir dos arquivos locais do TabWin e do projeto PIH.

Roda UMA vez, no seu computador (o GitHub Actions nao tem acesso ao TabWin). O resultado fica versionado
em seeds/ e o pipeline usa esses CSV como dimensoes fixas.

Uso:  .venv\\Scripts\\python.exe scripts\\gerar_seeds.py
"""
import csv
import re
import struct
import sys
from pathlib import Path

import openpyxl

RAIZ = Path(__file__).resolve().parents[1]
SEEDS = RAIZ / "seeds"
AREA = RAIZ.parent
PIH = AREA / "PIH-Proj. Inteligência Hospitalar"
TABWIN = AREA / "Centralizador" / "Projetos" / "TABWIN"
DIC = PIH / "DICIONARIO_DADOS_TRATADOS_csv"


def gravar(nome, cab, linhas):
    with open(SEEDS / nome, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(cab)
        w.writerows(linhas)
    print(f"  {nome}: {len(linhas)} linhas")


def ler_map(path):
    """Leitor do mapa .MAP do TabWin (centroide/rotulo de cada municipio)."""
    b = path.read_bytes()
    p, out = 18, {}
    while p < len(b) - 20:
        p += 1
        ln = b[p]; code = b[p + 1:p + 1 + ln].decode("latin1"); p += 11
        p += 26
        lx, ly = struct.unpack("<2f", b[p:p + 8]); p += 8
        npt = struct.unpack("<H", b[p:p + 2])[0]; p += 2 + 8 * npt
        out.setdefault(code, (round(ly, 5), round(lx, 5)))
    return out


def municipios():
    cnv = TABWIN / "TAB_CNES" / "CNV"
    nomes = {}
    for ln in (cnv / "es_municip.cnv").read_text(encoding="latin-1").splitlines()[1:]:
        m = re.match(r"\s*\d+\s+(\d{6})\s+(.+?)\s{2,}\d{6}", ln)
        if m:
            nomes[m.group(1)] = m.group(2).strip()
    reg = {}
    for ln in (cnv / "es_regsaud.cnv").read_text(encoding="latin-1").splitlines()[1:]:
        m = re.match(r"\s*\d+\s+(\d+)\s+(.+?)\s{2,}(\d{6})\s*$", ln)
        if m:
            reg[m.group(3)] = (m.group(1), m.group(2).strip())
    cen = ler_map(TABWIN / "MAPAS" / "es_municip.MAP")
    linhas = []
    for cod, nome in sorted(nomes.items()):
        if cod.endswith("0000") or cod == "320000":
            continue
        cr, rg = reg.get(cod, (None, None))
        lat, lon = cen.get(cod, (None, None))
        linhas.append((cod, nome, cr, rg, lat, lon))
    gravar("municipios_es.csv", ["cod_mun6", "municipio", "cod_regiao_saude", "regiao_saude", "lat", "lon"], linhas)


def dominios():
    """Codigos -> descricao das tabelas de dominio usadas nos estudos (dicionario do projeto PIH)."""
    quero = {
        "DIC_LEITOS.csv": ["CODLEITO", "TP_LEITO", "TP_UNID"],
        "DIC_REDUZIDO.csv": ["PROC_REA", "COBRANCA", "CAR_INT", "COD_IDADE"],
        "DIC_EQUIPAMENTOS.csv": ["TIPEQUIP+CODEQUIP", "TIPEQUIP"],
        "DIC_SERVICO_ESPECIALIZADO.csv": ["SERV_ESP", "SERV_ESP+CLASS_SR"],
    }
    vistos, linhas = set(), []
    for arq, cols in quero.items():
        with open(DIC / arq, encoding="utf-8-sig") as f:
            for r in csv.DictReader(f, delimiter=";"):
                if r["coluna"] in cols and (r["coluna"], r["codigo"]) not in vistos:
                    vistos.add((r["coluna"], r["codigo"]))
                    linhas.append((r["coluna"].lower(), r["codigo"], r["descricao"].strip()))
    # natureza juridica completa (TabWin)
    for ln in (TABWIN / "TAB_CNES" / "CNV" / "NATJUR.CNV").read_text(encoding="latin-1").splitlines():
        m = re.match(r"\s+\d+\s+\d+\s+\d{3}-\d\s+(.+?)\s{2,}(\d{4})\s*$", ln)
        if m and ("nat_jur", m.group(2)) not in vistos:
            vistos.add(("nat_jur", m.group(2)))
            linhas.append(("nat_jur", m.group(2), m.group(1).strip()))
    linhas.sort()
    gravar("dominios.csv", ["dominio", "codigo", "descricao"], linhas)


def procedimentos():
    """Nomes SIGTAP usados no Estudo 2 (aba Aux_RDZ do DADOS - TRATADOS.xlsx)."""
    wb = openpyxl.load_workbook(PIH / "DADOS - TRATADOS.xlsx", read_only=True, data_only=True)
    vistos, linhas = set(), []
    for r in wb["Aux_RDZ"].iter_rows(min_row=3, values_only=True):
        if r[4] and r[5]:
            cod = str(int(r[4])).zfill(10)
            if cod not in vistos:
                vistos.add(cod)
                linhas.append((cod, str(r[5]).strip()))
    gravar("procedimentos_sigtap.csv", ["proc_rea", "procedimento"], sorted(linhas))


def hospitais():
    """Nome curto e tipo de demanda dos hospitais do Estudo 1 (aba dim_unidade do Excel do Power BI)."""
    wb = openpyxl.load_workbook(PIH / "Indicadores_Hospitalares_PowerBI.xlsx", read_only=True, data_only=True)
    ws = wb["dim_unidade"]
    it = ws.iter_rows(values_only=True)
    cab = list(next(it))
    i = {c: cab.index(c) for c in ("cnes", "unidade_hospitalar", "tipo_demanda")}
    linhas = sorted({(str(r[i["cnes"]]).zfill(7), r[i["unidade_hospitalar"]], r[i["tipo_demanda"]]) for r in it if r[0]})
    gravar("hospitais_pih.csv", ["cnes", "unidade_hospitalar", "tipo_demanda"], linhas)


if __name__ == "__main__":
    if not TABWIN.exists() or not PIH.exists():
        sys.exit(f"Pastas nao encontradas: {TABWIN} / {PIH}")
    SEEDS.mkdir(exist_ok=True)
    municipios()
    dominios()
    procedimentos()
    hospitais()
