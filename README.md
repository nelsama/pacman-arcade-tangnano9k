# Pac-Man arcade en Tang Nano 9K

Port del core VHDL de Pac-Man de MikeJ (FPGAArcade) a la placa Sipeed
Tang Nano 9K (Gowin GW1NR-9), con salida HDMI 720x480 @ 60 Hz.

- Imagen girada (ROT90) y centrada, con los 16 colores reales de la PROM 7F.
- Sin framebuffer: `src/core/pacman_render.vhd` dibuja la imagen a 27 MHz a
  partir de una copia de la memoria de video que el core exporta.
- Verificado pixel a pixel contra el video original del core en simulacion.

Detalle completo del trabajo: [docs/RESUMEN_PORT_TN9K.md](docs/RESUMEN_PORT_TN9K.md).

## ROMs

Las ROMs de Pac-Man **no se incluyen** (tienen copyright). Los ficheros
`src/core/pacman_program_rom.vhd` y `src/core/pacrom_*.vhd` estan en el
repositorio con la tabla vacia. Para rellenarlos:

1. Copia tus ROMs (set `pacman` de MAME) en `roms/pacman/`:
   `pacman.6e pacman.6f pacman.6h pacman.6j pacman.5e pacman.5f
   82s126.1m 82s126.4a 82s123.7f`
2. Ejecuta `python tools/rom2vhd.py`.

## Compilar

Con Gowin EDA (probado con V1.9.12.03):

```
gw_sh tools/check_gprj.tcl
```

o abriendo `PACMAN.gprj` en el IDE. El bitstream queda en
`impl/pnr/PACMAN_top.fs`.

## Conexiones

| Funcion | Pin |
|---|---|
| Reloj 27 MHz | 52 |
| HDMI | 68-75 |
| Joystick arriba / abajo / izquierda / derecha | 30 / 33 / 34 / 40 (activos en bajo) |
| Credito (moneda) | 86 |
| Start 1 jugador | 85 |
| Reset | S1 (pin 4) |
| Audio L / R (sigma-delta 1 bit, requiere filtro RC) | 77 / 76 |

## Simulacion (GHDL)

| Script | Prueba |
|---|---|
| `sim/run_render.sh <volcado>` | renderizador contra un volcado del core |
| `sim/run_spr.sh <semillas>` | escenas de sprites dibujadas por el core original |
| `sim/run_golden.sh` | core completo, vuelca cuadros reales del juego |
| `sim/run_win.sh` | ventana visible del core |

## Licencia

MIT (ver `LICENSE`): port a Tang Nano 9K (c) 2026 Nelson Figueroa, sobre el
proyecto pacman-KR260 de MakarenaLabs. El core original es de MikeJ
(FPGAArcade) y el T80 de Daniel Wallner, cada uno con su licencia en la
cabecera de sus ficheros.
