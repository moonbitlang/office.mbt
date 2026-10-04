import struct, glob, sys, random, os
# The fonts to sweep (fonts that don't exist are skipped).
fonts = sorted(glob.glob(os.path.expanduser('~/.cargo/git/checkouts/typst-assets-*/*/files/fonts/*.[ot]tf'))) + \
        sorted(glob.glob(os.path.expanduser('~/.cargo/git/checkouts/typst-dev-assets-*/*/files/fonts/*.[ot]t[fc]'))) + \
        ['/System/Library/AssetsV2/com_apple_MobileAsset_Font8/86ba2c91f017a3749571a82f2c6d890ac7ffb2fb.asset/AssetData/PingFang.ttc',
         '/System/Library/Fonts/GeezaPro.ttc', '/System/Library/Fonts/Helvetica.ttc', '/System/Library/Fonts/Times.ttc',
         '/System/Library/Fonts/Supplemental/Arial.ttf', '/System/Library/Fonts/SFNS.ttf', '/System/Library/Fonts/NewYork.ttf',
         '/System/Library/Fonts/Menlo.ttc', '/System/Library/Fonts/STHeiti Medium.ttc', '/System/Library/Fonts/Supplemental/Songti.ttc',
         '/System/Library/Fonts/Hiragino Sans GB.ttc', '/System/Library/Fonts/Apple Color Emoji.ttc', '/System/Library/Fonts/Supplemental/Zapfino.ttf']
def faces(d):
    if d[:4] == b'ttcf':
        n = struct.unpack('>I', d[8:12])[0]
        return [struct.unpack('>I', d[12+4*i:16+4*i])[0] for i in range(n)]
    return [0]
def tables(d, o):
    nt = struct.unpack('>H', d[o+4:o+6])[0]
    t = {}
    for i in range(nt):
        r = o + 12 + 16*i
        t[d[r:r+4].decode('latin1')] = struct.unpack('>II', d[r+8:r+16])
    return t
out = []
for f in fonts:
    if not os.path.exists(f): continue
    d = open(f, 'rb').read()
    offs = faces(d)
    idxs = range(len(offs)) if len(offs) <= 3 else [0, 1, len(offs)-1]
    for idx in idxs:
        t = tables(d, offs[idx])
        if 'maxp' not in t: continue
        n = struct.unpack('>H', d[t['maxp'][0]+4:t['maxp'][0]+6])[0]
        rnd = random.Random(f + str(idx))
        sets = [[], list(range(1, min(n, 40))), [rnd.randrange(n) for _ in range(60)], [n-1, n//2, 3, n//3, 3, 1], list(range(n-1, max(0, n-25), -1))]
        if n < 3000:
            sets.append(list(range(n)))
        coord_sets = ['']
        if 'fvar' in t:
            fo = t['fvar'][0]
            axes_off, _, count, size = struct.unpack('>HHHH', d[fo+4:fo+12])
            axes = []
            for a in range(count):
                ao = fo + axes_off + a*size
                tag = d[ao:ao+4].decode('latin1')
                mn, df, mx = [struct.unpack('>i', d[ao+4+4*k:ao+8+4*k])[0]/65536 for k in range(3)]
                axes.append((tag, mn, df, mx))
            coord_sets.append(','.join(f'{a[0]}={a[3]}' for a in axes))
            coord_sets.append(','.join(f'{a[0]}={a[1]}' for a in axes))
            coord_sets.append(','.join(f'{a[0]}={(a[1]+a[2])/2 + 0.37}' for a in axes[:2]))
            coord_sets.append(','.join(f'{a[0]}={a[2]}' for a in axes))
        for s in sets:
            for c in coord_sets:
                out.append(f"{f}\t{idx}\t{','.join(map(str, s))}\t{c}")
open(sys.argv[1], 'w').write('\n'.join(out) + '\n')
print(len(out))
