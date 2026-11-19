"""Busca una configuracion de rPLL que de exactamente 25 MHz (o lo mas
cerca posible) desde 27 MHz con las restricciones de Gowin:

    PFD  = 27 / (IDIV+1)                  en [3, 400] MHz
    VCO  = PFD * (FBDIV+1) * ODIV         en [400, 1200] MHz
    CLKOUT  = VCO / ODIV
    CLKOUTD = CLKOUT / DYN_SDIV_SEL       (SDIV en {2,4,8,...})
"""

TARGET = 25.0
best = []

for idiv in range(0, 64):
    pfd = 27.0 / (idiv + 1)
    if not (3.0 <= pfd <= 400.0):
        continue
    for fbdiv in range(0, 64):
        for odiv in (1, 2, 4, 8, 16, 32, 48, 64):
            vco = pfd * (fbdiv + 1) * odiv
            if not (400.0 <= vco <= 1200.0):
                continue
            clkout = vco / odiv
            for sdiv in (1, 2, 4, 8):
                fout = clkout / sdiv
                err = abs(fout - TARGET) / TARGET * 100
                if err < 0.6:
                    best.append((err, fout, vco, idiv, fbdiv, odiv, sdiv, pfd))

best.sort()
print("err%   fout      VCO      IDIV FBDIV ODIV SDIV  PFD")
seen = set()
n = 0
for e, f, v, i, fb, od, sd, pf in best:
    key = (round(f, 3), i, fb, od, sd)
    if key in seen:
        continue
    seen.add(key)
    print("%5.3f %9.4f %8.1f %4d %5d %4d %4d %7.3f"
          % (e, f, v, i, fb, od, sd, pf))
    n += 1
    if n >= 12:
        break
