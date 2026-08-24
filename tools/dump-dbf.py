import struct, sys, os, glob

def info(path):
    with open(path,'rb') as f:
        d = f.read()
    ver = d[0]
    yy,mm,dd = d[1],d[2],d[3]
    nrec = struct.unpack('<I', d[4:8])[0]
    hdrlen = struct.unpack('<H', d[8:10])[0]
    reclen = struct.unpack('<H', d[10:12])[0]
    fields=[]
    off=32
    while d[off] != 0x0D:
        fd = d[off:off+32]
        name = fd[0:11].split(b'\x00')[0].decode('latin1')
        ftype = chr(fd[11])
        flen = fd[16]
        fdec = fd[17]
        fields.append((name,ftype,flen,fdec))
        off += 32
    print(f"### {os.path.basename(path)}")
    print(f"  version byte: 0x{ver:02X}  lastupdate: {1900+yy if yy<100 else yy}-{mm:02d}-{dd:02d}  records: {nrec}  hdrlen: {hdrlen}  reclen: {reclen}  filesize: {len(d)}")
    calc = 1 + sum(x[2] for x in fields)
    print(f"  fields ({len(fields)}), sum+1 = {calc} {'OK' if calc==reclen else '*** MISMATCH ***'}")
    for i,(n,t,l,dec) in enumerate(fields,1):
        print(f"    {i:2d}. {n:<12} {t}  len={l:<4} dec={dec}")
    # dump records
    start = hdrlen
    print(f"  --- records ---")
    shown=0
    for r in range(nrec):
        rec = d[start + r*reclen : start + (r+1)*reclen]
        if len(rec) < reclen: 
            print(f"    !! record {r+1} truncated (file too short)")
            break
        flag = chr(rec[0])
        vals=[]
        o=1
        for (n,t,l,dec) in fields:
            v = rec[o:o+l].decode('cp860', errors='replace')
            o+=l
            vals.append(f"{n}={v!r}")
        print(f"    [{r+1}]{'DEL' if flag=='*' else '   '} " + " | ".join(vals))
        shown+=1
        if shown>=40:
            print("    ... (truncated listing)")
            break
    print()

for p in sorted(glob.glob(sys.argv[1] + "/*.DBF")):
    try:
        info(p)
    except Exception as e:
        print(f"### {os.path.basename(p)} -- ERRO: {e}\n")
