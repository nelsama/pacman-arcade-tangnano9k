#!/usr/bin/env bash
# Verificacion de la rotacion: imprime que fila de origen aparece en cada
# franja de la pantalla.
set -e

export PATH="/c/msys64/ucrt64/bin:$PATH"
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
BUILD="sim/build_rot"

mkdir -p "$BUILD"
cd "$(dirname "$0")/.."

$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_video_out.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" sim/tb_rot.vhd
$GHDL -e --std=08 -fsynopsys --workdir="$BUILD" tb_rot
$GHDL -r --std=08 -fsynopsys --workdir="$BUILD" tb_rot \
      --ieee-asserts=disable --stop-time=19ms
