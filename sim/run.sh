#!/usr/bin/env bash
# Simulacion del core Pac-Man con GHDL (MSYS2).
set -e

export PATH="/c/msys64/ucrt64/bin:$PATH"
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
FLAGS="-a --std=08 -fsynopsys"
BUILD="sim/build"

mkdir -p "$BUILD"
cd "$(dirname "$0")/.."

echo "== Analizando fuentes =="
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pkg_pacman.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/T80_Pack.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/T80_ALU.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/T80_MCode.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/T80_Reg.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/T80.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/T80sed.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_mul4.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_vram_addr.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_rams.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_program_rom.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacrom_5e.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacrom_5f.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacrom_1m.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacrom_4a_dst.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacrom_7f_dst.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_video.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_audio.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_debounce.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/dac.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" sim/clk_pacman_sim.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_clocks_gowin.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" sim/tb_image_pkg.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" sim/tb_pacman.vhd

echo "== Elaborando =="
$GHDL -e --std=08 -fsynopsys --workdir="$BUILD" tb_pacman

echo "== Simulando =="
$GHDL -r --std=08 -fsynopsys --workdir="$BUILD" tb_pacman --ieee-asserts=disable
