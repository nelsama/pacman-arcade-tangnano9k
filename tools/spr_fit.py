"""
Busca, sprite a sprite, donde dibuja realmente el core cada sprite en las
escenas de prueba (sim/spr/scene_*.txt) y deduce las constantes
  x_nativa = SXC_s - X     y_nativa = Y - SYC_s
para cada numero de sprite s.

  python -I tools/spr_fit.py sim/spr/scene_*.txt
"""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_model as m


def sprite_pixels(code, color, fx, fy):
    px = []
    for ly in range(16):
        for lx in range(16):
            c = m.R4A[color * 4 + m.sprite_pix(code, 15 - lx if fx else lx,
                                               15 - ly if fy else ly)] & 0x0F
            if c:
                px.append((lx, ly, c))
    return px


res = collections.defaultdict(list)
for f in sys.argv[1:]:
    d = m.load(f)
    T = m.render_tiles(d)
    I = d['I']
    for s in range(8):
        attr, color = d['A'][2 * s], d['A'][2 * s + 1] & 0x1F
        X, Y = d['X'][2 * s + 1], d['X'][2 * s]
        px = sprite_pixels(attr >> 2, color, attr & 1, (attr >> 1) & 1)
        if len(px) < 12:
            continue
        best = None
        for sx in range(-15, 288):
            for sy in range(-15, 224):
                ok = bad = 0
                for lx, ly, c in px:
                    x, y = sx + lx, sy + ly
                    if 0 <= x < 288 and 0 <= y < 224:
                        if I[y][x] == c and T[y][x] != c:
                            ok += 1
                        elif I[y][x] != c:
                            bad += 1
                if best is None or ok - 2 * bad > best[0]:
                    best = (ok - 2 * bad, ok, bad, sx, sy)
        score, ok, bad, sx, sy = best
        visible = ok > 0.6 * len(px)
        print(f'{os.path.basename(f)} spr{s} X={X:3d} Y={Y:3d} n={len(px):3d} '
              f'-> sx={sx:4d} sy={sy:4d} ok={ok:3d} bad={bad:3d} '
              f'SXC={sx + X:4d} SYC={Y - sy:4d} {"" if visible else "(no visible / dudoso)"}')
        if visible:
            res[s].append((sx + X, Y - sy))

print()
for s in range(8):
    print(f'sprite {s}:', collections.Counter(res[s]).most_common(3))
