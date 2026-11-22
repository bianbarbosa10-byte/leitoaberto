"""Configuracao central do LeitoAberto. Le variaveis do arquivo .env (local) ou do ambiente (GitHub Actions)."""
import os
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[1]


def _carregar_env():
    f = RAIZ / ".env"
    if f.exists():
        for linha in f.read_text(encoding="utf-8").splitlines():
            linha = linha.strip()
            if linha and not linha.startswith("#") and "=" in linha:
                k, v = linha.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


_carregar_env()

# ---------- caminhos ----------
DATA = Path(os.environ.get("LA_DATA_DIR", RAIZ / "data"))  # espelho local do data lake (mesma estrutura do bucket)
SEEDS = RAIZ / "seeds"
SQL = RAIZ / "pipeline" / "sql"
BRONZE, SILVER, GOLD = DATA / "bronze", DATA / "silver", DATA / "gold"

# ---------- escopo ----------
UF = "ES"
COD_UF = "32"
INICIO = os.environ.get("LA_INICIO", "2024-01")  # primeira competencia (AAAA-MM) carregada
# Janela de recarga: a cada mes as ultimas N competencias de cada fonte sao baixadas de novo, mesmo sem
# mudanca aparente no FTP (o SIH continua recebendo AIH atrasadas desses meses). Fora da janela, so baixa
# arquivo novo ou cujo tamanho/data mudou no FTP.
JANELA_MESES = int(os.environ.get("LA_JANELA_MESES", "6"))

# ---------- fontes DATASUS (FTP publico) ----------
FTP_HOST = "ftp.datasus.gov.br"
FONTES = {
    # nome: (diretorio no FTP, prefixo do arquivo)
    "sih_rd": ("/dissemin/publicos/SIHSUS/200801_/Dados", "RD"),
    "cnes_lt": ("/dissemin/publicos/CNES/200508_/Dados/LT", "LT"),
    "cnes_eq": ("/dissemin/publicos/CNES/200508_/Dados/EQ", "EQ"),
    "cnes_sr": ("/dissemin/publicos/CNES/200508_/Dados/SR", "SR"),
    "cnes_st": ("/dissemin/publicos/CNES/200508_/Dados/ST", "ST"),
}
# colunas mantidas na Bronze (o resto do DBF e descartado para caber no plano gratuito)
COLUNAS = {
    "sih_rd": ["n_aih", "ident", "cnes", "munic_res", "munic_mov", "ano_cmpt", "mes_cmpt", "espec", "proc_rea",
               "complex", "car_int", "dias_perm", "morte", "cobranca", "val_tot", "idade", "cod_idade", "dt_inter",
               "dt_saida", "sexo", "diag_princ", "uti_mes_to", "marca_uti"],
    "cnes_lt": None,  # None = todas as colunas
    "cnes_eq": None,
    "cnes_sr": None,
    "cnes_st": ["cnes", "codufmun", "cpf_cnpj", "pf_pj", "regsaude", "vinc_sus", "tpgestao", "esfera_a", "natureza",
                "nat_jur", "tp_unid", "niv_hier", "clientel", "atendhos", "urgemerg", "leithosp", "competen"],
}
# LGPD: identificadores de pessoas nunca entram em claro
HASHEAR = {"sih_rd": ["cpf_aut", "gestor_cpf"]}
SALT = os.environ.get("LA_HASH_SALT", "leitoaberto")

# ---------- IBGE ----------
SIDRA_POP = "https://apisidra.ibge.gov.br/values/t/6579/n6/in%20n3%2032/v/9324/p/all"
IBGE_MUNICIPIOS = "https://servicodados.ibge.gov.br/api/v1/localidades/estados/32/municipios"
IBGE_MALHA = ("https://servicodados.ibge.gov.br/api/v3/malhas/estados/32"
              "?formato=application/vnd.geo+json&intrarregiao=municipio&qualidade=intermediaria")
CNES_API = "https://apidadosabertos.saude.gov.br/cnes/estabelecimentos/{cnes}"

# ---------- nuvem ----------
R2_ACCOUNT_ID = os.environ.get("R2_ACCOUNT_ID")
R2_ACCESS_KEY_ID = os.environ.get("R2_ACCESS_KEY_ID")
R2_SECRET_ACCESS_KEY = os.environ.get("R2_SECRET_ACCESS_KEY")
R2_BUCKET = os.environ.get("R2_BUCKET", "leitoaberto")
DATABASE_URL = os.environ.get("DATABASE_URL")  # string de conexao do Neon (postgresql://...)
