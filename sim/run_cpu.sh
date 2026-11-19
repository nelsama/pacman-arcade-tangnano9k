#!/usr/bin/env bash
# Simulacion del CPU: solo T80sed + ROM de programa. Tarda segundos.
set -e

export PATH="/c/msys64/ucrt64/bin:$PATH"
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
BUILD="sim/build_cpu"

mkdir -p "$BUILD"
cd "$(dirname "$0")/.."

echo "== Analizando =="
for f in pkg_pacman T80_Pack T80_ALU T80_MCode T80_Reg T80 T80sed \
         pacman_program_rom; do
  $GHDL -a --std=08 -fsynopsys --workdir="$BUILD" "src/core/$f.vhd"
done
$GHDL -a --std=08 -fsynopsys --workdir="$BUILD" sim/tb_cpu.vhd

echo "== Elaborando =="
$GHDL -e --std=08 -fsynopsys --workdir="$BUILD" tb_cpu

echo "== Simulando =="
$GHDL -r --std=08 -fsynopsys --workdir="$BUILD" tb_cpu \
      --ieee-asserts=disable --stop-time=2ms
