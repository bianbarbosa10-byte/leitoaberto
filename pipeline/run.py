"""Orquestrador do LeitoAberto:  Bronze (ingestao) -> Silver -> Gold -> Neon.

Uso:
  python -m pipeline.run                  execucao normal (so processa se algo mudou nas fontes)
  python -m pipeline.run --forcar         reprocessa Silver/Gold/Neon mesmo sem dado novo
  python -m pipeline.run --rebaixar       baixa de novo todos os arquivos do FTP
  python -m pipeline.run --sem-ingestao   so Silver/Gold/Neon (usa a bronze que ja existe)

No GitHub Actions grava `mudou=true|false` em $GITHUB_OUTPUT para decidir se o site e reconstruido.
"""
import argparse
import os
import time

from . import bronze, publish, storage, transform


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--forcar", action="store_true")
    ap.add_argument("--rebaixar", action="store_true")
    ap.add_argument("--sem-ingestao", action="store_true")
    ap.add_argument("--sem-publicar", action="store_true")
    a = ap.parse_args()
    t0 = time.time()
    print(f"LeitoAberto | armazenamento: {'Cloudflare R2 + espelho local' if storage.NUVEM else 'somente local (data/)'}")

    mudou = []
    if not a.sem_ingestao:
        print("\n=== BRONZE ===", flush=True)
        mudou = bronze.executar(forcar=a.rebaixar)
    elif storage.NUVEM:
        storage.baixar("bronze/", ignorar_sufixo=(".dbc",))

    processar = bool(mudou) or a.forcar or a.sem_ingestao
    if not processar:
        print("\nNenhuma fonte mudou desde a ultima execucao: nada a processar.")
    else:
        print("\n=== SILVER / GOLD ===", flush=True)
        transform.executar()
        if not a.sem_publicar:
            print("\n=== PUBLICACAO (Neon) ===", flush=True)
            publish.executar()

    saida = os.environ.get("GITHUB_OUTPUT")
    if saida:
        with open(saida, "a", encoding="utf-8") as f:
            f.write(f"mudou={'true' if processar else 'false'}\n")
    print(f"\nconcluido em {time.time() - t0:.0f}s | arquivos novos/atualizados: {len(mudou)}")


if __name__ == "__main__":
    main()
