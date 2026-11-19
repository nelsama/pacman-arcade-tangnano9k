"""
Genera una escena de prueba de sprites para el core de Pac-Man (CPU inerte):
  sim/spr/mem.hex  4096 lineas: VRAM(1024) CRAM(1024) -(1024) RAM trabajo(1024)
                   (atributos de sprite en 0xFF0..0xFFF -> RAM de trabajo 0x3F0..)
  sim/spr/xy.hex   16 lineas: posiciones de sprite (0x5060..0x506F)
y, tras la simulacion, convierte el cuadro capturado en un volcado con el
formato de sim/golden (para tools/render_model.py).

  python -I tools/spr_scene.py gen <semilla>
  python -I tools/spr_scene.py dump <cuadro_tb_golden> <salida>
"""
import sys, random

def gen(seed):
    rnd = random.Random(seed)
    v = [rnd.choice([0x40] * 6 + list(range(0x00, 0x40))) for _ in range(1024)]
    c = [rnd.choice([0x10, 0x01, 0x05, 0x09, 0x14, 0x1F]) for _ in range(1024)]
    w = [0] * 1024
    xy = [0] * 16
    for s in range(8):
        code = rnd.randrange(0, 64)
        fy, fx = rnd.randrange(2), rnd.randrange(2)
        w[0x3F0 + 2 * s] = (code << 2) | (fy << 1) | fx
        w[0x3F1 + 2 * s] = rnd.choice([1, 3, 5, 7, 9, 0x11, 0x16, 0x18])
        xy[2 * s] = rnd.randrange(0, 256)       # registro par
        xy[2 * s + 1] = rnd.randrange(0, 256)   # registro impar
    with open('sim/spr/mem.hex', 'w') as f:
        for b in v + c + [0] * 1024 + w:
            f.write('%02X\n' % b)
    with open('sim/spr/xy.hex', 'w') as f:
        for b in xy:
            f.write('%02X\n' % b)

def dump(cap, out):
    mem = [int(l, 16) for l in open('sim/spr/mem.hex')]
    xy = [int(l, 16) for l in open('sim/spr/xy.hex')]
    img = [l for l in open(cap) if l.startswith('I ')]
    with open(out, 'w') as f:
        f.write('V ' + bytes(mem[0:1024]).hex().upper() + '\n')
        f.write('C ' + bytes(mem[1024:2048]).hex().upper() + '\n')
        f.write('A ' + bytes(mem[3072 + 0x3F0:3072 + 0x400]).hex().upper() + '\n')
        f.write('X ' + bytes(xy).hex().upper() + '\n')
        f.write('F 0\nN 0\n')
        f.writelines(img)

if __name__ == '__main__':
    if sys.argv[1] == 'gen':
        gen(int(sys.argv[2]))
    else:
        dump(sys.argv[2], sys.argv[3])
