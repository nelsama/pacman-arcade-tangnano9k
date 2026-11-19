# Pac-Man en Tang Nano 9K: resumen del trabajo

Resumen de lo que se hizo desde el estado que dejó el agente anterior
hasta la versión con color real verificada contra el core original.

## 1. Estado de partida

El proyecto compilaba, pero tenía estos problemas:

- **Relojes HDMI:** el serializador (OSER10) recibía el reloj de pixel
  directo del pin de 27 MHz en lugar de un `CLKDIV` alineado con el reloj
  de 135 MHz.
- **Imagen:** se veía cabeza abajo, con glitches gráficos y una franja
  negra en medio, porque la captura incluía el blanking del core.
- **Fantasmas:** solo se movían en horizontal.
- **Color:** de 2 bits (4 colores) para ahorrar BSRAM, y además mal
  mapeado (los muros salían rojos).
- **Botones:** crédito y start mal cableados.

## 2. Fase 1: corregir la imagen

- **Fantasmas en un solo eje:** el buffer de línea de sprites tenía 16
  posiciones en vez de 256 (`pacman_video.vhd`). Corregido.
- **Recorte:** se midió en simulación la ventana visible real del core:
  288×224 px, con la línea partida en el hcnt (`0x0F7…0x1FF` y sigue en
  `0x080…0x096`). La captura pasó a contar pixeles usando el blanking real
  que exporta el core.
- **Lectura del framebuffer:** cada pixel mostraba el dato de otro porque
  la dirección iba un ciclo atrasada. Corregido.
- **Orientación y color:** rotación de 180° (ROT90 correcto) y mapeo de
  2 bits según las PROM reales.
- **HDMI:** reloj de pixel desde `CLKDIV` (135 MHz / 5), con lock de la PLL
  y reset de los serializadores.
- **Reset:** había una doble inversión de polaridad que funcionaba por
  casualidad; ahora es coherente.

Resultado: la imagen se vio bien en la placa.

## 3. Fase 2: color real de 4 bits (opción A)

A 4 bits el framebuffer no cabía en la BSRAM (hacían falta 16 bloques y
quedaban 12 libres), así que se eliminó y se escribió un renderizador
propio: `src/core/pacman_render.vhd`.

- El core exporta cada escritura de la CPU en la memoria de video (un
  "espía": puertos `O_SNP_*`). Esas escrituras cruzan al dominio de 27 MHz
  y el renderizador mantiene su propia copia de VRAM, color RAM y
  registros de sprites.
- La imagen se dibuja ya girada a 720×480, con los 16 colores reales de la
  PROM 7F.
- Los tiles se calculan pixel a pixel (VRAM → ROM 5E → PROM 4A). Los
  sprites se preparan en un buffer de columna durante la línea HDMI
  anterior (ROM 5F → PROM 4A).
- Como el video original del core queda sin usar, la síntesis lo elimina.
  La BSRAM bajó de 26/26 a **21/26**.

## 4. Verificación

| Herramienta | Qué hace |
|---|---|
| `tools/render_model.py` | Modelo de referencia en Python del video |
| `sim/run_golden.sh` | Simulación larga del core completo: vuelca cuadros reales del juego y la memoria espiada |
| `sim/run_spr.sh` | Core con la CPU sustituida por una inerte y la memoria precargada con escenas de sprites |
| `tools/spr_fit.py` | Mide dónde dibuja el core cada sprite |
| `sim/run_render.sh` | Compara el renderizador VHDL con el core, pixel a pixel |
| `sim/run_win.sh` | Mide la ventana visible del core |
| `sim/tb_net.vhd` | Simulación del netlist post-PnR con las primitivas de Gowin |

**Posición de sprites medida contra el core:**

- `x = 273 − X`, `y = Y − 31`
- Los sprites 1 y 2 van en `y = Y − 30`, porque se leen antes de que
  avance el contador de líneas.
- Solo se dibujan los sprites 1 a 6 (el hardware tiene 6 turnos de
  lectura por línea).
- Solo son visibles en las columnas 17 a 272.

**Resultado:** 0 errores en los 345.600 pixeles de cada cuadro, en 8
escenas con sprites (3 de ellas nuevas, que no se usaron para el ajuste) y
en los cuadros reales del juego. La comparación incluye el paso por el
espía de escrituras y el cruce entre relojes.

También se simuló el netlist post-PnR con las primitivas de Gowin para
descartar fallos de síntesis.

## 5. Problemas que aparecieron por el camino

- **"Sin señal" (1):** se grabó un `.fs` que se estaba sobrescribiendo
  durante una compilación.
- **"Sin señal" (2):** el IDE de Gowin tenía en memoria la lista de
  archivos antigua y compiló sin el renderizador. Hay que reabrir
  `PACMAN.gprj` en el IDE antes de compilar desde ahí.
- **Botones:** el crédito entraba como "start 2 jugadores", el start no
  estaba conectado y el bit de servicio quedaba fijo como "pulsado".
  Ahora:
  - crédito = moneda (pin 86)
  - start = 1 jugador (pin 85)
  - S1 = reset (pin 4)
- **Timing del Z80:** según cómo cayera la colocación, el core cumplía o
  no. Se añadieron restricciones multiciclo en `src/top/PACMAN_top.sdc`,
  porque la CPU solo avanza 1 de cada 8 ciclos. Ahora cumple con margen.
- **Ajuste de sprites:** los dos intentos a ojo (16 px y después 2 px) se
  sustituyeron por los valores medidos contra el core.
- **Error en el renderizador:** el dato de la ROM de sprites llegaba un
  ciclo tarde. Lo detectaron las escenas de prueba y está corregido.

## 6. Estado final

- **Bitstream:** `impl/pnr/PACMAN_top.fs`. Compila sin errores, cumple
  timing en todos los relojes y en simulación coincide pixel a pixel con
  el core original. Pendiente confirmar en la placa cómo quedan los
  sprites.
- **Recursos:** lógica 34 %, BSRAM 21/26.
- **Joystick:** arriba, abajo, izquierda y derecha en los pines 30, 33,
  34 y 40. `joy_fire` (pin 29) no se usa.
- **Audio:** sale por los pines 76/77 como señal digital de 1 bit.
  Necesita un filtro RC (por ejemplo 1 kΩ en serie y 10 nF a masa) y,
  mejor, un amplificador.
- **Cómo compilar:** con `gw_sh tools/check_gprj.tcl`, o desde el IDE
  después de reabrir el proyecto.

## 7. Análisis para Ms. Pac-Man

Es el mismo hardware de video, sonido y entradas, pero no basta con
cambiar las ROMs:

1. **Más ROM de programa:** 8 KB extra en `0x8000–0x9FFF`. Hay que añadir
   A15 al decodificador de direcciones de `pacman.vhd`.
2. **Código cifrado:** la placa auxiliar original descifra y parchea el
   código al vuelo. La forma simple es precalcular la imagen descifrada de
   24 KB (equivale a los sets bootleg sin cifrar).
3. **ROMs gráficas `5E`/`5F` nuevas:** mismo formato. El renderizador
   sirve tal cual.

No cambian las PROMs de color y sonido, el renderizador, el HDMI, los
relojes, las entradas ni las restricciones de timing. La BSRAM quedaría
en 25/26.
