#!/usr/bin/env bash
# Mide la ventana visible del core (ver sim/tb_win.vhd).
set -e
cd "$(dirname "$0")/.."
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
B="sim/build_win"; mkdir -p "$B"
F="-a --std=08 -fsynopsys --workdir=$B"
for s in src/core/pkg_pacman.vhd src/core/T80_Pack.vhd src/core/T80_ALU.vhd src/core/T80_MCode.vhd \
         src/core/T80_Reg.vhd src/core/T80.vhd src/core/T80sed.vhd src/core/pacman_mul4.vhd \
         src/core/pacman_vram_addr.vhd src/core/pacman_rams.vhd src/core/pacman_program_rom.vhd \
         src/core/pacrom_5e.vhd src/core/pacrom_5f.vhd src/core/pacrom_1m.vhd src/core/pacrom_4a_dst.vhd \
         src/core/pacrom_7f_dst.vhd src/core/pacman_video.vhd src/core/pacman_audio.vhd \
         src/core/pacman_debounce.vhd src/core/dac.vhd sim/clk_pacman_sim.vhd \
         src/core/pacman_clocks_gowin.vhd src/core/pacman.vhd sim/tb_win.vhd; do
  $GHDL $F $s
done
$GHDL -e --std=08 -fsynopsys --workdir=$B -o $B/tb_win.exe tb_win
$B/tb_win.exe --ieee-asserts=disable --stop-time=40ms
