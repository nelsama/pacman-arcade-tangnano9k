#!/usr/bin/env bash
# Golden del video: ejecuta el core y vuelca cuadros + memoria espiada.
# Uso: sim/run_golden.sh [stop_time]   (por defecto 7000ms)
set -e
cd "$(dirname "$0")/.."
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
B="sim/build_golden"; mkdir -p "$B" sim/golden
F="-a --std=08 -fsynopsys --workdir=$B"
for s in src/core/pkg_pacman.vhd src/core/T80_Pack.vhd src/core/T80_ALU.vhd src/core/T80_MCode.vhd \
         src/core/T80_Reg.vhd src/core/T80.vhd src/core/T80sed.vhd src/core/pacman_mul4.vhd \
         src/core/pacman_vram_addr.vhd src/core/pacman_rams.vhd src/core/pacman_program_rom.vhd \
         src/core/pacrom_5e.vhd src/core/pacrom_5f.vhd src/core/pacrom_1m.vhd src/core/pacrom_4a_dst.vhd \
         src/core/pacrom_7f_dst.vhd src/core/pacman_video.vhd src/core/pacman_audio.vhd \
         src/core/pacman_debounce.vhd src/core/dac.vhd sim/clk_pacman_sim.vhd \
         src/core/pacman_clocks_gowin.vhd src/core/pacman.vhd sim/tb_golden.vhd; do
  if [ ! -f "$B/.done_$(basename $s)" ] || [ "$s" -nt "$B/.done_$(basename $s)" ]; then
    $GHDL $F $s && touch "$B/.done_$(basename $s)"
  fi
done
$GHDL -e --std=08 -fsynopsys --workdir=$B -o $B/tb_golden.exe tb_golden
$B/tb_golden.exe --ieee-asserts=disable --stop-time=${1:-7000ms} ${2:+-gDUMP_FIRST=$2} ${3:+-gDUMP_EVERY=$3}
