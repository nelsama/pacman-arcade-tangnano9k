"""
Modelo de referencia del video de Pac-Man en coordenadas NATIVAS del core
(x = pixel dentro de la linea 0..287, y = linea 0..223).

Reproduce un cuadro a partir de la memoria de video (VRAM, color RAM,
atributos y posiciones de sprites) y lo compara con el golden volcado por
sim/tb_golden.vhd (imagen real del core original).

Uso:
  python -I tools/render_model.py sim/golden/f0030.txt [...]      compara
  python -I tools/render_model.py --fit sim/golden/*.txt         ajusta
  python -I tools/render_model.py --png out.png sim/golden/f0030.txt

Las mismas formulas son las que implementa src/core/pacman_render.vhd.
"""
import sys, os, itertools, zlib, struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def rom(name):
    return open(os.path.join(ROOT, 'roms', 'pacman', name), 'rb').read()

R5E = rom('pacman.5e')     # tiles
R5F = rom('pacman.5f')     # sprites
R4A = rom('82s126.4a')     # lookup de color
R7F = rom('82s123.7f')     # paleta

# --- parametros de sprites ---------------------------------------------------
# Medidos con tools/spr_fit.py sobre escenas de prueba dibujadas por el core
# original (sim/run_spr.sh):
#   x nativa = SXC - X
#   y nativa = Y - SYC          (sprites 3..6)
#   y nativa = Y - SYC + 1      (sprites 1 y 2: se leen antes de que avance
#                                el contador de lineas)
#   los sprites 0 y 7 no se dibujan (solo hay 6 ranuras de lectura)
#   solo se ven en x = SXC-256 .. SXC-1 (17..272): buffer de linea de 256
P = dict(SXC=273, SYC=31)


def load(path):
    d = {'I': []}
    for ln in open(path):
        t, v = ln[0], ln[2:].strip()
        if t in 'VCAX':
            d[t] = bytes.fromhex(v)
        elif t == 'F':
            d['F'] = v
        elif t == 'N':
            d['N'] = int(v)
        elif t == 'I':
            d['I'].append([int(c, 16) for c in v])
    return d


def tile_addr(x, y):
    tc, vr = x // 8, y // 8 + 2
    if tc < 2:
        return 0x3C0 + tc * 32 + vr
    if tc >= 34:
        return (tc - 34) * 32 + vr
    return vr * 32 + (tc - 2)


def pix2(b, xx):
    return (((b >> (7 - xx)) & 1) << 1) | ((b >> (3 - xx)) & 1)


def tile_pix(d, x, y):
    a = tile_addr(x, y)
    code, col = d['V'][a], d['C'][a] & 0x1F
    b = R5E[code * 16 + (8 if (x % 8) < 4 else 0) + (y % 8)]
    return R4A[col * 4 + pix2(b, x % 4)] & 0x0F


SPR_XB = (8, 16, 24, 0)


def sprite_pix(code, lx, ly):
    b = R5F[code * 64 + SPR_XB[lx // 4] + (ly if ly < 8 else 32 + ly - 8)]
    return pix2(b, lx % 4)


def render_tiles(d):
    return [[tile_pix(d, x, y) for x in range(288)] for y in range(224)]


def render(d, p=P, tiles=None):
    img = [row[:] for row in (tiles or render_tiles(d))]
    A, X = d['A'], d['X']
    for s in range(6, 0, -1):           # el de numero menor queda encima
        attr, color = A[2 * s], A[2 * s + 1] & 0x1F
        code, fy, fx = attr >> 2, (attr >> 1) & 1, attr & 1
        sx = p['SXC'] - X[2 * s + 1]
        sy = X[2 * s] - p['SYC'] + (1 if s <= 2 else 0)
        for ly in range(16):
            y = sy + ly
            if not 0 <= y < 224:
                continue
            for lx in range(16):
                for x in (sx + lx, sx + lx - 256):
                    if p['SXC'] - 256 <= x < p['SXC']:   # zona de sprites (17..272)
                        c = R4A[color * 4 + sprite_pix(code, 15 - lx if fx else lx,
                                                        15 - ly if fy else ly)] & 0x0F
                        if c:
                            img[y][x] = c
    return img


def diff(a, b):
    return sum(1 for y in range(224) for x in range(288) if a[y][x] != b[y][x])


def png(path, img, rot=True):
    # imagen ya girada (ROT90) como se ve en pantalla: 224 x 288
    W, H = (224, 288) if rot else (288, 224)
    rows = []
    for sy in range(H):
        row = bytearray([0])
        for sx in range(W):
            v = img[223 - sx][sy] if rot else img[sy][sx]
            c = R7F[v]
            r = ((c >> 0) & 1) * 0x21 + ((c >> 1) & 1) * 0x47 + ((c >> 2) & 1) * 0x97
            g = ((c >> 3) & 1) * 0x21 + ((c >> 4) & 1) * 0x47 + ((c >> 5) & 1) * 0x97
            bl = ((c >> 6) & 1) * 0x51 + ((c >> 7) & 1) * 0xAE
            row += bytes((r, g, bl))
        rows.append(bytes(row))
    def chunk(t, data):
        return struct.pack('>I', len(data)) + t + data + struct.pack('>I', zlib.crc32(t + data))
    raw = b''.join(rows)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b''))


def main(argv):
    if argv and argv[0] == '--png':
        out, path = argv[1], argv[2]
        d = load(path)
        png(out, d['I'])
        png(out.replace('.png', '_model.png'), render(d))
        return
    fit = argv and argv[0] == '--fit'
    files = argv[1:] if fit else argv
    ds = [load(f) for f in files]
    for d in ds:
        d['T'] = render_tiles(d)
    if fit:
        best = None
        for sxc, syc in itertools.product(range(268, 278), range(25, 50)):
            p = dict(SXC=sxc, SYC=syc)
            e = sum(diff(render(d, p, d['T']), d['I']) for d in ds)
            if best is None or e < best[0]:
                best = (e, p)
                print('mejor hasta ahora:', best, flush=True)
        print('AJUSTE:', best)
        return
    for f, d in zip(files, ds):
        m = render(d, P, d['T'])
        e = diff(m, d['I'])
        print(f'{os.path.basename(f)}: escrituras={d["N"]:4d} flip={d["F"]} '
              f'pixeles distintos={e:6d} (solo tiles: {diff(d["T"], d["I"])})')


if __name__ == '__main__':
    main(sys.argv[1:])
