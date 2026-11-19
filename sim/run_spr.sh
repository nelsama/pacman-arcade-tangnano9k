#!/usr/bin/env bash
# Prueba de sprites: core con CPU inerte y memoria de video precargada.
# Uso: sim/run_spr.sh <semilla> ...   -> sim/spr/scene_<semilla>.txt
set -e
cd "$(dirname "$0")/.."
GHDL="C:/msys64/ucrt64/bin/ghdl.exe"
B="sim/build_spr"; mkdir -p "$B" sim/golden
F="-a --std=08 -fsynopsys --workdir=$B"
for s in src/core/pkg_pacman.vhd sim/spr/t80_stub.vhd src/core/pacman_mul4.vhd \
         src/core/pacman_vram_addr.vhd sim/spr/pacman_rams_init.vhd src/core/pacman_program_rom.vhd \
         src/core/pacrom_5e.vhd src/core/pacrom_5f.vhd src/core/pacrom_1m.vhd src/core/pacrom_4a_dst.vhd \
         src/core/pacrom_7f_dst.vhd sim/spr/pacman_video_init.vhd src/core/pacman_audio.vhd \
         src/core/pacman_debounce.vhd src/core/dac.vhd sim/clk_pacman_sim.vhd \
         src/core/pacman_clocks_gowin.vhd src/core/pacman.vhd sim/tb_golden.vhd; do
  if [ ! -f "$B/.done_$(basename $s)" ] || [ "$s" -nt "$B/.done_$(basename $s)" ]; then
    $GHDL $F $s && touch "$B/.done_$(basename $s)"
  fi
done
$GHDL -e --std=08 -fsynopsys --workdir=$B -o $B/tb_spr.exe tb_golden
for seed in "$@"; do
  python -I tools/spr_scene.py gen $seed
  rm -f sim/golden/f0003.txt
  $B/tb_spr.exe --ieee-asserts=disable --stop-time=140ms -gDUMP_FIRST=3 -gDUMP_EVERY=1000 > /dev/null
  python -I tools/spr_scene.py dump sim/golden/f0003.txt sim/spr/scene_$seed.txt
  rm -f sim/golden/f0003.txt
  echo "escena $seed lista"
done
