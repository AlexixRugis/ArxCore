#!/usr/bin/env python3
"""
Pipeline dump -> Kanata 0004 converter with disassembly labels.

Usage:
    python pipe2konata.py pipeline.txt out.kanata --elf program.elf
    python pipe2konata.py pipeline.txt out.kanata --stages IF1 IF2 ID EX MEM WB --elf program.elf
"""
import argparse
import re
import subprocess
import sys

LINE_RE = re.compile(r"^\s*(\d+)\s*:\s*(.*)$")


def parse_pc(tok):
    if tok.lower() == "x":
        return None
    try:
        return int(tok, 0)
    except ValueError:
        return int(tok)


def load_disasm(elf_path, objdump_cmd="objdump"):
    """Загружает дизассемблированный код из ELF через objdump.
    Возвращает dict: {pc: "инструкция"}.
    """
    try:
        out = subprocess.check_output(
            [objdump_cmd, "-d", "--no-show-raw-insn", elf_path],
            text=True, stderr=subprocess.PIPE
        )
    except FileNotFoundError:
        sys.exit(f"[error] objdump command not found: {objdump_cmd}")
    except subprocess.CalledProcessError as e:
        sys.exit(f"[error] objdump failed:\n{e.stderr}")

    disasm = {}
    # Строки вида: "   10000:\tauipc\tt0,0x0"
    rx = re.compile(r"^\s*([0-9a-fA-F]+):\s+(.+)$")
    for line in out.splitlines():
        m = rx.match(line)
        if not m:
            continue
        pc = int(m.group(1), 16)
        text = m.group(2).strip().replace("\t", " ")
        disasm[pc] = text
    return disasm


def read_rows(path, n_stages):
    rows = []
    with open(path, encoding="utf-8") as f:
        for ln, line in enumerate(f, 1):
            m = LINE_RE.match(line)
            if not m:
                continue
            cycle = int(m.group(1))
            toks = m.group(2).split()
            if len(toks) != n_stages:
                print(f"[warn] line {ln}: expected {n_stages} columns, "
                      f"found {len(toks)}", file=sys.stderr)
                toks = (toks + ["x"] * n_stages)[:n_stages]
            rows.append((cycle, [parse_pc(t) for t in toks]))
    rows.sort(key=lambda r: r[0])
    return rows


def convert(rows, stages, disasm=None):
    n = len(stages)
    events = []          # (cycle, text)
    active = []          # active instructions
    next_id = 0
    retire_id = 0
    orphans = 0

    if disasm is None:
        disasm = {}

    def ev(cycle, text):
        events.append((cycle, text))

    def leave(ins, cycle, flushed):
        nonlocal retire_id
        ev(cycle, f"E\t{ins['id']}\t0\t{stages[ins['stage']]}")
        if flushed:
            ev(cycle, f"R\t{ins['id']}\t0\t1")
        else:
            ev(cycle, f"R\t{ins['id']}\t{retire_id}\t0")
            retire_id += 1

    for cycle, cells in rows:
        claimed = [False] * n
        survivors = []

        for ins in sorted(active, key=lambda i: -i["stage"]):
            s, pc = ins["stage"], ins["pc"]
            if s == n - 1:
                # TODO! WB can take more than one cycle
                leave(ins, cycle, flushed=False)
            elif cells[s + 1] == pc and not claimed[s + 1]:
                claimed[s + 1] = True
                ev(cycle, f"E\t{ins['id']}\t0\t{stages[s]}")
                ev(cycle, f"S\t{ins['id']}\t0\t{stages[s + 1]}")
                ins["stage"] = s + 1
                survivors.append(ins)
            elif cells[s] == pc and not claimed[s]:
                claimed[s] = True
                survivors.append(ins)
            else:
                leave(ins, cycle, flushed=True)

        active = survivors

        if cells[0] is not None and not claimed[0]:
            pc = cells[0]
            ins = {"id": next_id, "pc": pc, "stage": 0}
            next_id += 1
            ev(cycle, f"I\t{ins['id']}\t{ins['id']}\t0")
            # --- Метки ---
            mnem = disasm.get(pc, "???")
            print(mnem)
            ev(cycle, f"L\t{ins['id']}\t0\tPC={pc:#x} {mnem}")
            ev(cycle, f"L\t{ins['id']}\t1\tfetched at cycle {cycle}")
            # ---------------
            ev(cycle, f"S\t{ins['id']}\t0\t{stages[0]}")
            active.append(ins)
            claimed[0] = True

        orphans += sum(1 for s in range(1, n)
                       if cells[s] is not None and not claimed[s])

    end = rows[-1][0] + 1 if rows else 0
    for ins in sorted(active, key=lambda i: i["id"]):
        leave(ins, end, flushed=(ins["stage"] != n - 1))

    if orphans:
        print(f"[warn] couldn't match {orphans} cells with instructions", file=sys.stderr)
    return events, next_id


def write_kanata(events, path):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("Kanata\t0004\n")
        if not events:
            return
        cur = events[0][0]
        f.write(f"C=\t{cur}\n")
        for cycle, text in events:
            if cycle > cur:
                f.write(f"C\t{cycle - cur}\n")
                cur = cycle
            f.write(text + "\n")


def parse_args():
    ap = argparse.ArgumentParser(description="Pipeline dump -> Konata (Kanata 0004)")
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--stages", nargs="+",
                    default=["IF1", "IF2", "ID", "EX", "MEM", "WB"],
                    help="Pipeline stage names")
    ap.add_argument("--elf", help="ELF file for disassembly")
    ap.add_argument("--objdump", default="riscv64-unknown-elf-objdump",
                    help="objdump command (default: riscv64-unknown-elf-objdump)")
    return ap.parse_args()


def main():
    args = parse_args()

    disasm = {}
    if args.elf:
        disasm = load_disasm(args.elf, args.objdump)

    rows = read_rows(args.input, len(args.stages))
    if not rows:
        sys.exit("There are no rows formatted like 'N: ...'")
    events, count = convert(rows, args.stages, disasm)
    write_kanata(events, args.output)

    print(f"Done: {count} insts, {len(rows)} cycles -> {args.output}")


if __name__ == "__main__":
    main()