"""Descompactador DATASUS .dbc -> .dbf em Python puro (port do blast.c de Mark Adler, PKWare DCL implode)."""
import struct

MAXBITS = 13
LENLEN = [2, 35, 36, 53, 38, 23]
DISTLEN = [2, 20, 53, 230, 247, 151, 248]
BASE = [3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264]
EXTRA = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]


def _construct(rep):
    length = []
    for b in rep:
        length += [b & 15] * ((b >> 4) + 1)
    count = [0] * (MAXBITS + 1)
    for l in length:
        count[l] += 1
    offs = [0] * (MAXBITS + 1)
    for l in range(1, MAXBITS):
        offs[l + 1] = offs[l] + count[l]
    symbol = [0] * len(length)
    for s, l in enumerate(length):
        if l:
            symbol[offs[l]] = s
            offs[l] += 1
    # tabela direta: (code, len) -> symbol, códigos já invertidos como no blast.c
    table = {}
    code = first = index = 0
    for l in range(1, MAXBITS + 1):
        c = count[l]
        for k in range(c):
            table[(first + k, l)] = symbol[index + k]
        index += c
        first = (first + c) << 1
    return table


LENCODE = _construct(LENLEN)
DISTCODE = _construct(DISTLEN)


def blast(data: bytes) -> bytes:
    pos = 0
    bitbuf = 0
    bitcnt = 0
    n = len(data)

    def need(k):
        nonlocal pos, bitbuf, bitcnt
        while bitcnt < k:
            if pos >= n:
                raise ValueError("fim inesperado dos dados")
            bitbuf |= data[pos] << bitcnt
            pos += 1
            bitcnt += 8

    def bits(k):
        nonlocal bitbuf, bitcnt
        need(k)
        v = bitbuf & ((1 << k) - 1)
        bitbuf >>= k
        bitcnt -= k
        return v

    def decode(table):
        nonlocal bitbuf, bitcnt
        code = 0
        for l in range(1, MAXBITS + 1):
            need(1)
            code |= (bitbuf & 1) ^ 1
            bitbuf >>= 1
            bitcnt -= 1
            s = table.get((code, l))
            if s is not None:
                return s
            code <<= 1
        raise ValueError("código Huffman inválido")

    lit = bits(8)
    if lit != 0:
        raise ValueError("literais codificados (lit=1) não suportados")
    dictbits = bits(8)
    if dictbits < 4 or dictbits > 6:
        raise ValueError("dicionário inválido")
    out = bytearray()
    while True:
        if bits(1):
            sym = decode(LENCODE)
            ln = BASE[sym] + bits(EXTRA[sym])
            if ln == 519:
                break
            sb = 2 if ln == 2 else dictbits
            dist = (decode(DISTCODE) << sb) + bits(sb) + 1
            if dist > len(out):
                raise ValueError("distância além do início")
            start = len(out) - dist
            if dist >= ln:
                out += out[start:start + ln]
            else:
                for i in range(ln):
                    out.append(out[start + i])
        else:
            out.append(bits(8))
    return bytes(out)


def dbc_bytes_to_dbf(raw: bytes) -> bytes:
    hs = struct.unpack('<H', raw[8:10])[0]
    return raw[:hs] + blast(raw[hs + 4:])


def dbc_to_dbf(path_in: str) -> bytes:
    return dbc_bytes_to_dbf(open(path_in, 'rb').read())


if __name__ == '__main__':
    import sys, time
    t = time.time()
    b = dbc_to_dbf(sys.argv[1])
    print(len(b), 'bytes em', round(time.time() - t, 1), 's')
    if len(sys.argv) > 2:
        ref = open(sys.argv[2], 'rb').read()
        print('igual ao .dbf de referência:', b == ref, len(ref))
