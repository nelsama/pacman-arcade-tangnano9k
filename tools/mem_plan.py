bsram = 479232
ssram_max = 95000          # estimacion conservadora de LUTs libres como RAM
items = {'prog':131072,'5e':32768,'5f':32768,'1m':4096,'rams':24576,'fb':405504}
need = sum(items.values()) - bsram

import itertools
best = None
for r in range(1, len(items)):
    for combo in itertools.combinations(items.keys(), r):
        s = sum(items[c] for c in combo)
        if s >= need and s <= ssram_max:
            if best is None or s < best[0]:
                best = (s, combo)

print('faltan liberar:', need)
print('mejor combo:', best)

if best:
    s, combo = best
    rest = sum(items[k] for k in items if k not in combo)
    print('a SSRAM:', combo, '=', s, 'bits')
    print('queda en BSRAM:', rest, 'de', bsram, '->', 'CABE' if rest <= bsram else 'NO')
