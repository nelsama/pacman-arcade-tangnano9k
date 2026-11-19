#!/usr/bin/env bash
# Verifica pacman_render contra un volcado golden.
# Uso: sim/run_render.sh sim/golden/f0030.txt [SXC SYC]
set -e
cd "$(dirname "$0")/.."
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
B="sim/build_render"; mkdir -p "$B"
F="-a --std=08 -frelaxed -fsynopsys --workdir=$B"
rm -f "$B/.done_tb_render.vhd"   # siempre: depende de pacman_render
for s in src/core/pkg_pacman.vhd src/core/pacrom_5e.vhd src/core/pacrom_5f.vhd \
         src/core/pacrom_4a_dst.vhd src/core/pacrom_7f_dst.vhd \
         src/core/pacman_render.vhd sim/tb_render.vhd; do
  if [ ! -f "$B/.done_$(basename $s)" ] || [ "$s" -nt "$B/.done_$(basename $s)" ]; then
    $GHDL $F $s && touch "$B/.done_$(basename $s)"
  fi
done
$GHDL -e --std=08 -frelaxed -fsynopsys --workdir=$B -o $B/tb_render.exe tb_render
[ -n "$1" ] || exit 0
G="-gDUMP=$1"
[ -n "$2" ] && G="$G -gSXC=$2 -gSYC=$3"
$B/tb_render.exe $G --ieee-asserts=disable --stop-time=100ms
