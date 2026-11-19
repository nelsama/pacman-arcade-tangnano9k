#!/usr/bin/env python3
"""Genera los modulos VHDL de ROM a partir de los ficheros de Pac-Man.

Uso:
    python tools/rom2vhd.py            # roms/pacman/ -> src/core/
    python tools/rom2vhd.py --check    # solo comprueba las ROMs

Origen: roms/pacman/ con los nombres del ROM set de MAME:
    pacman.6e pacman.6f pacman.6h pacman.6j    programa (4 x 4 KB)
    pacman.5e pacman.5f                       graficos (2 x 4 KB)
    82s126.1m                                 audio (512 B)
    82s126.4a                                 lookup de color (256 B)
    82s123.7f                                 paleta (16 B)

En el repositorio los ficheros VHDL de ROM se guardan con la tabla vacia
(las ROMs tienen copyright): hay que ejecutar este script antes de
sintetizar o simular.

Sustituye SOLO el bloque marcado entre
    -- >>> CONTENIDO ROM <nombre> >>>
    -- <<< CONTENIDO ROM <nombre> <<<
de cada fichero, de modo que el envoltorio (entidad y proceso de
lectura) se mantiene escrito a mano y el script solo mete la tabla.
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROM_DIR = os.path.join(ROOT, "roms", "pacman")
SRC_DIR = os.path.join(ROOT, "src", "core")

# (fichero fuente, fichero vhd, bits de datos, bits del puerto ADDR, nombre)
# ROMs grandes -> array constante (BRAM).
ROMS = [
    ("pacman.5e",   "pacrom_5e.vhd",     12, 12, "5E"),
    ("pacman.5f",   "pacrom_5f.vhd",     12, 12, "5F"),
    ("82s126.1m",   "pacrom_1m.vhd",      9,  9, "1M"),
]

# PROMs de color: tablas combinacionales (funcion con case -> LUT).
FUNC_ROMS = [
    ("82s126.4a",   "pacrom_4a_dst.vhd",  256, 8, "4A"),
    ("82s123.7f",   "pacrom_7f_dst.vhd",   16, 4, "7F"),
]

# Las ROMs de programa se juntan en una sola de 16 KB.
PROG_ROMS = ["pacman.6e", "pacman.6f", "pacman.6h", "pacman.6j"]
PROG_VHD = "pacman_program_rom.vhd"
PROG_NAME = "PROG"


def read_bytes(name, expect):
    path = os.path.join(ROM_DIR, name)
    if not os.path.exists(path):
        raise SystemExit("falta la ROM %s" % path)
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < expect:
        data = data + b"\x00" * (expect - len(data))
    elif len(data) > expect:
        # 82s123.7f trae 32 bytes; solo se usan los 16 primeros.
        data = data[:expect]
    return data


def table_entries(data, addr_bits):
    """Devuelve las lineas 'when "..." => d := x"NN";'.

    El case compara con std_logic_vector, asi que la etiqueta debe tener
    exactamente addr_bits bits.
    """
    out = []
    for i, b in enumerate(data):
        out.append('      when "%s" => d := x"%02X";'
                   % (format(i, '0%db' % addr_bits), b))
    return out


def replace_block(text, name, body):
    start = "-- >>> CONTENIDO ROM %s >>>" % name
    end = "-- <<< CONTENIDO ROM %s <<<" % name
    i = text.find(start)
    j = text.find(end)
    if i < 0 or j < 0 or j < i:
        raise SystemExit("no se encuentran los marcadores de %s" % name)
    header = text[:i + len(start)]
    footer = text[j:]
    middle = "\n" + body + "\n"
    return header + middle + "  " + footer


def gen_simple(bin_name, vhd_name, data_bits, addr_bits, rom_name):
    data = read_bytes(bin_name, 1 << data_bits)
    # Array constante: es el unico patron que Gowin infiere como BRAM.
    # Una funcion con case acaba en LUT (2.112 LUT por ROM de 4 KB).
    vals = ['    %d => x"%02X"' % (i, b) for i, b in enumerate(data)]
    body = ("  constant ROM_CONTENT : rom_t := (\n"
            + ",\n".join(vals) + "\n    );")

    vhd_path = os.path.join(SRC_DIR, vhd_name)
    with open(vhd_path, "r", encoding="utf-8") as f:
        text = f.read()
    text = replace_block(text, rom_name, body)
    with open(vhd_path, "w", encoding="utf-8") as f:
        f.write(text)
    print("  %-22s %5d bytes -> %s" % (bin_name, len(data), vhd_name))


def gen_func(bin_name, vhd_name, size, addr_bits, rom_name):
    data = read_bytes(bin_name, size)
    entries = table_entries(data, addr_bits)
    nl = chr(10)
    head = [
        "  function rom_data (addr : std_logic_vector(%d downto 0))" % (addr_bits - 1),
        "    return std_logic_vector is",
        "    variable d : std_logic_vector(7 downto 0);",
        "  begin",
        "    case addr is",
    ]
    tail = [
        "      when others => d := (others => '0');",
        "    end case;",
        "    return d;",
        "  end function;",
    ]
    body = nl.join(head + entries + tail)
    vhd_path = os.path.join(SRC_DIR, vhd_name)
    with open(vhd_path, "r", encoding="utf-8") as f:
        text = f.read()
    text = replace_block(text, rom_name, body)
    with open(vhd_path, "w", encoding="utf-8") as f:
        f.write(text)
    print("  %-22s %5d bytes -> %s" % (bin_name, len(data), vhd_name))


def gen_program():
    prog = b""
    for name in PROG_ROMS:
        prog += read_bytes(name, 4096)
    entries = table_entries(prog, 14)
    body = ("  function pacman_rom_data (addr : std_logic_vector(13 downto 0))\n"
            "    return std_logic_vector is\n"
            "    variable d : std_logic_vector(7 downto 0);\n"
            "  begin\n"
            "    case addr is\n" + "\n".join(entries) +
            "\n      when others => d := (others => '0');\n"
            "    end case;\n"
            "    return d;\n  end function;")

    vhd_path = os.path.join(SRC_DIR, PROG_VHD)
    with open(vhd_path, "r", encoding="utf-8") as f:
        text = f.read()
    text = replace_block(text, PROG_NAME, body)
    with open(vhd_path, "w", encoding="utf-8") as f:
        f.write(text)
    print("  %-22s %5d bytes -> %s" % ("prog 6E..6J", len(prog), PROG_VHD))


def validate_program(prog):
    """Comprueba que la ROM de programa parece codigo de Pac-Man.

    Con las ROMs de relleno (el Pong de ejemplo del repo de MikeJ) el
    core arranca pero no dibuja nada. Esto lo detecta antes de compilar.
    """
    errors = []
    zeros = sum(1 for b in prog if b == 0)
    if zeros > len(prog) * 0.9:
        errors.append("la ROM de programa esta casi vacia (%d/%d ceros)"
                      % (zeros, len(prog)))
    # Arranque habitual del Z80 de Pac-Man: DI; LD A,nn
    if prog[0] != 0xF3:
        errors.append("no empieza por DI (F3), empieza por %02X" % prog[0])
    return errors


def validate_rom(bin_name, addr_bits):
    data = read_bytes(bin_name, 1 << addr_bits)
    zeros = sum(1 for b in data if b == 0)
    if zeros == len(data):
        return ["%s esta entera a cero" % bin_name]
    return []


def main():
    if "--check" in sys.argv:
        print("roms en %s" % ROM_DIR)
        errs = []
        for r in ROMS:
            errs += validate_rom(r[0], r[2])
            print("  %-14s %5d bytes" % (r[0], 1 << r[2]))
        prog = b"".join(read_bytes(n, 4096) for n in PROG_ROMS)
        for n in PROG_ROMS:
            print("  %-14s %5d bytes" % (n, 4096))
        errs += validate_program(prog)
        if errs:
            for e in errs:
                print("  ERROR: %s" % e)
            return 1
        print("  OK: ROMs validas")
        return 0

    prog = b"".join(read_bytes(n, 4096) for n in PROG_ROMS)
    errs = validate_program(prog)
    for r in ROMS:
        errs += validate_rom(r[0], r[2])
    if errs:
        for e in errs:
            print("  ERROR: %s" % e)
        raise SystemExit("las ROMs no son validas; no se generan los VHDL")

    for r in ROMS:
        gen_simple(*r)
    for r in FUNC_ROMS:
        gen_func(*r)
    gen_program()
    print("Listo.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
