#!/usr/bin/env python3
"""Prueba varias configuraciones de sintesis/colocacion y reporta el
timing de cada una, para quedarse con la mejor.

Uso:  python tools/try_placements.py
"""

import json
import os
import re
import shutil
import subprocess
import sys

GWSH = r"C:/Gowin/Gowin_V1.9.12.03_x64/IDE/bin/gw_sh.exe"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.join(ROOT, "impl", "PACMAN_process_config.json")

# (nombre, Map_Option, Place_Option, Route_Option, Max_Fanout, Optimization_Goal)
VARIANTS = [
    ("A base",        2, 2, 2, 50,  "Timing"),
    ("B fanout 20",   2, 2, 2, 20,  "Timing"),
    ("C fanout 100",  2, 2, 2, 100, "Timing"),
    ("D area",        2, 1, 1, 50,  "Area"),
    ("E map1",        1, 2, 2, 50,  "Timing"),
    ("F place1",      2, 1, 2, 50,  "Timing"),
    ("G fanout 10",   2, 2, 2, 10,  "Timing"),
]


def set_cfg(map_o, place_o, route_o, fanout, goal):
    with open(CFG, encoding="utf-8") as f:
        d = json.load(f)
    d["Map_Option"] = map_o
    d["Place_Option"] = place_o
    d["Route_Option"] = route_o
    d["Max_Fanout"] = fanout
    d["Optimization_Goal"] = goal
    d["Run_Timing_Driven"] = True
    with open(CFG, "w", encoding="utf-8") as f:
        json.dump(d, f, indent=4)


def force_rmtree(path):
    """Borra un arbol quitando antes el atributo de solo lectura."""
    for root, dirs, files in os.walk(path):
        for f in files:
            try:
                os.chmod(os.path.join(root, f), 0o666)
            except OSError:
                pass
    shutil.rmtree(path, ignore_errors=True)


def run_build():
    for sub in ("gwsynthesis", "pnr"):
        p = os.path.join(ROOT, "impl", sub)
        if os.path.isdir(p):
            force_rmtree(p)
    log = os.path.join(ROOT, "gprj_check.log")
    with open(log, "w") as f:
        r = subprocess.run([GWSH, "tools/check_gprj.tcl"],
                           cwd=ROOT, stdout=f, stderr=subprocess.STDOUT)
    return r.returncode, log


def read_result(log):
    txt = open(log, encoding="utf-8", errors="ignore").read()
    m = re.search(r"number\(\s*(\d+)\s*\((\d+) LUTs", txt)
    lut = int(m.group(2)) if m else -1
    if "exceeds the resource limit" in txt:
        return {"ok": False, "lut": lut, "fmax": 0.0, "viol": -1,
                "err": "recursos"}

    path = os.path.join(ROOT, "impl", "pnr", "PACMAN_tr_content.html")
    if not os.path.exists(path):
        return {"ok": False, "lut": lut, "fmax": 0.0, "viol": -1,
                "err": "sin informe"}
    t = re.sub(r"\s+", " ", re.sub(r"<[^>]+>", " ", open(path, encoding="utf-8",
                                                       errors="ignore").read()))
    fm = 0.0
    for mm in re.finditer(r"clk_core 24\.975\(MHz\) ([\d.]+)\(MHz\)", t):
        fm = float(mm.group(1))
    vm = re.search(r"Setup Violated Endpoints (\d+)", t)
    viol = int(vm.group(1)) if vm else -1
    return {"ok": viol == 0, "lut": lut, "fmax": fm, "viol": viol, "err": ""}


def main():
    results = []
    for name, mo, po, ro, fo, goal in VARIANTS:
        print("== %-14s map=%d place=%d route=%d fan=%d %s"
              % (name, mo, po, ro, fo, goal), flush=True)
        set_cfg(mo, po, ro, fo, goal)
        rc, log = run_build()
        res = read_result(log)
        print("   LUT=%d  Fmax=%.3f MHz  violaciones=%d %s"
              % (res["lut"], res["fmax"], res["viol"], res["err"]), flush=True)
        results.append((name, res))

    print("\n==== RESUMEN ====")
    for name, r in results:
        mark = "OK " if r["ok"] else "   "
        print("%s %-14s LUT=%5d  Fmax=%.3f  viol=%d %s"
              % (mark, name, r["lut"], r["fmax"], r["viol"], r["err"]))

    best = None
    for name, r in results:
        if r["ok"] and (best is None or r["fmax"] > best[1]["fmax"]):
            best = (name, r)
    if best:
        print("\nMejor: %s (Fmax %.3f MHz)" % (best[0], best[1]["fmax"]))
    else:
        print("\nNinguna variante cierra timing.")


if __name__ == "__main__":
    main()
