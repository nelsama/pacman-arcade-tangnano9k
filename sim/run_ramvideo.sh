#!/usr/bin/env bash
# Simulacion RAM + VIDEO. Tarda segundos.
set -e

export PATH="/c/msys64/ucrt64/bin:$PATH"
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
BUILD="sim/build_ramvideo"

mkdir -p "$BUILD"
cd "$(dirname "$0")/.."

echo "== Analizando =="
for f in pkg_pacman T80_Pack pacman_mul4 pacman_vram_addr pacman_rams \
         pacrom_5e pacrom_5f pacrom_1m pacrom_4a_dst pacrom_7f_dst \
         pacman_video; do
  $GHDL -a --std=08 -fsynopsys --workdir="$BUILD" "src/core/$f.vhd"
done
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" sim/tb_ram_video.vhd

echo "== Elaborando =="
$GHDL -e --std=08 -fsynopsys --workdir="$BUILD" tb_ram_video

echo "== Simulando =="
$GHDL -r --std=08 -fsynopsys --workdir="$BUILD" tb_ram_video \
      --ieee-asserts=disable --stop-time=1ms
