#!/usr/bin/env python3
"""Decodifica o cabecalho de indices .NTX do Clipper.

Formato do cabecalho NTX (offset / tamanho):
    0  WORD  assinatura (0x0006)
    2  WORD  versao
    4  LONG  offset da pagina raiz
    8  LONG  offset da proxima pagina livre
   12  WORD  tamanho do item (chave + 8)
   14  WORD  tamanho da chave
   16  WORD  casas decimais da chave
   18  WORD  maximo de itens por pagina
   20  WORD  meia pagina
   22  CHAR[256] expressao da chave
  278  BYTE  flag de unicidade

Uso: dump-ntx.py <diretorio>
"""
import struct, sys, glob, os

def info(path):
    d = open(path, 'rb').read()
    sig, ver, root, unused, itemsz, keysz, keydec, maxitem, half = struct.unpack('<HHIIHHHHH', d[0:22])
    key = d[22:278].split(b'\x00')[0].decode('cp860', errors='replace')
    uniq = d[278] if len(d) > 278 else None
    print(f"{os.path.basename(path):<16} sig={sig} ver={ver} keysize={keysz} dec={keydec} "
          f"unique={uniq} maxitem={maxitem} filesize={len(d)}  KEY='{key}'")

if __name__ == '__main__':
    base = sys.argv[1] if len(sys.argv) > 1 else '.'
    for p in sorted(glob.glob(os.path.join(base, '*.NTX'))):
        info(p)
