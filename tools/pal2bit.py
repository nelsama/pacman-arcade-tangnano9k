# Mapeo de los 4 bits de indice del core a 2 bits (4 colores).
#
# Indices del core y su color real segun PACROM_7F_DST:
#   0,4,8,10 -> 0x00 negro
#   1        -> 0x07 azul      (laberinto)
#   2,13,14  -> rosa
#   3,5      -> amarillo       (Pac-Man, puntos)
#   6        -> naranja
#   9        -> cian
#   11       -> rojo           (Blinky)
#   12       -> verde
#   7,15     -> gris/beige
#
# Con 2 bits elegimos 4 colores. La asignacion prioriza que se distingan
# los elementos de juego:
#   00 negro      <- 0, 4, 8, 10
#   01 azul       <- 1              (muros del laberinto)
#   10 amarillo   <- 2,3,5,6,7,12,15 (Pac-Man, puntos, sprites calidos)
#   11 rojo       <- 9,11,13,14      (fantasmas)

MAP = {
    0:0, 4:0, 8:0, 10:0,
    1:1,
    2:2, 3:2, 5:2, 6:2, 7:2, 12:2, 15:2,
    9:3, 11:3, 13:3, 14:3,
}

COLORS = {
    0: (0x00, 0x00, 0x00),   # negro
    1: (0x00, 0x00, 0xFF),   # azul
    2: (0xFF, 0xFF, 0x00),   # amarillo
    3: (0xFF, 0x00, 0x00),   # rojo
}

if __name__ == '__main__':
    print('idx -> 2bit')
    for i in range(16):
        print('  %2d -> %d' % (i, MAP[i]))
