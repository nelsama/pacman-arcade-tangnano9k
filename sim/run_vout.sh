#!/usr/bin/env bash
# Simulacion del framebuffer: comprueba geometria y rotacion.
set -e

export PATH="/c/msys64/ucrt64/bin:$PATH"
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
BUILD="sim/build_vout"

mkdir -p "$BUILD"
cd "$(dirname "$0")/.."

$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" src/core/pacman_video_out.vhd
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" sim/tb_video_out.vhd
$GHDL -e --std=08 -fsynopsys --workdir="$BUILD" tb_video_out

$GHDL -r --std=08 -fsynopsys --workdir="$BUILD" tb_video_out \
      --stop-time=20ms
