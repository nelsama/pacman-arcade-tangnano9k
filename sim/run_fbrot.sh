#!/usr/bin/env bash
# Verifica pacman_video_out (captura + rotacion + raster) pixel a pixel.
set -e
cd "$(dirname "$0")/.."
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
B="sim/build_fbrot"; mkdir -p "$B"
F="-a --std=08 -frelaxed -fsynopsys --workdir=$B"
$GHDL $F sim/pacman_sdp_fb_sim.vhd
$GHDL $F src/core/pacman_framebuffer.vhd
$GHDL $F src/core/pacman_video_out.vhd
$GHDL $F sim/tb_fbrot.vhd
$GHDL -e --std=08 -frelaxed -fsynopsys --workdir=$B -o $B/tb_fbrot.exe tb_fbrot
$B/tb_fbrot.exe --ieee-asserts=disable --stop-time=200ms
