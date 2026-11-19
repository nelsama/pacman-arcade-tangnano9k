#!/usr/bin/env bash
# Simulacion del modulo de video (rapida, sin CPU).
set -e

export PATH="/c/msys64/ucrt64/bin:$PATH"
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
BUILD="sim/build_video"

mkdir -p "$BUILD"
cd "$(dirname "$0")/.."

if [ ! -f "$BUILD/pkg_pacman.o" ]; then
  echo "== Analizando =="
  for f in pkg_pacman T80_Pack pacman_mul4 pacrom_5e pacrom_5f \
           pacrom_1m pacrom_4a_dst pacrom_7f_dst pacman_video; do
    $GHDL -a --std=08 -fsynopsys --workdir="$BUILD" "src/core/$f.vhd"
  done
  $GHDL -a --std=08 -fsynopsys --workdir="$BUILD" sim/tb_video.vhd
fi

echo "== Elaborando =="
$GHDL -e --std=08 -fsynopsys --workdir="$BUILD" tb_video

echo "== Simulando (1 ms virtual) =="
$GHDL -r --std=08 -fsynopsys --workdir="$BUILD" tb_video \
      --ieee-asserts=disable --stop-time=1ms
