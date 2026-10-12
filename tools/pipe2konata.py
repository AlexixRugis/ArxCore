#!/usr/bin/env python3
"""
Конвертер дампа конвейера (IF1 IF2 ID EX MEM WB) в формат Konata (Kanata 0004).

Использование:
    python pipe2konata.py pipeline.txt out.kanata
    python pipe2konata.py pipeline.txt out.kanata --stages IF1 IF2 ID EX MEM WB
"""
import argparse
import re
import sys

LINE_RE = re.compile(r"^\s*(\d+)\s*:\s*(.*)$")


def parse_pc(tok):
    if tok.lower() == "x":
        return None
    try:
        return int(tok, 0)      # 12, 0xC
    except ValueError:
        return int(tok)


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
                print(f"[warn] строка {ln}: ожидалось {n_stages} столбцов, "
                      f"найдено {len(toks)}", file=sys.stderr)
                toks = (toks + ["x"] * n_stages)[:n_stages]
            rows.append((cycle, [parse_pc(t) for t in toks]))
    rows.sort(key=lambda r: r[0])
    return rows


def convert(rows, stages):
    n = len(stages)
    events = []          # (cycle, text)
    active = []          # активные экземпляры инструкций
    next_id = 0
    retire_id = 0
    orphans = 0

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

        # Сначала самые старые (дальние стадии), чтобы они первыми занимали ячейки
        for ins in sorted(active, key=lambda i: -i["stage"]):
            s, pc = ins["stage"], ins["pc"]
            if s == n - 1:
                # WB длится один такт: инструкция завершена
                leave(ins, cycle, flushed=False)
            elif cells[s + 1] == pc and not claimed[s + 1]:
                claimed[s + 1] = True
                ev(cycle, f"E\t{ins['id']}\t0\t{stages[s]}")
                ev(cycle, f"S\t{ins['id']}\t0\t{stages[s + 1]}")
                ins["stage"] = s + 1
                survivors.append(ins)
            elif cells[s] == pc and not claimed[s]:
                claimed[s] = True            # стол — остаётся на месте
                survivors.append(ins)
            else:
                leave(ins, cycle, flushed=True)   # flush

        active = survivors

        # Новая инструкция может появиться только в первой стадии
        if cells[0] is not None and not claimed[0]:
            pc = cells[0]
            ins = {"id": next_id, "pc": pc, "stage": 0}
            next_id += 1
            ev(cycle, f"I\t{ins['id']}\t{ins['id']}\t0")
            ev(cycle, f"L\t{ins['id']}\t0\tPC={pc:#x} ({pc})")
            ev(cycle, f"L\t{ins['id']}\t1\tfetched at cycle {cycle}")
            ev(cycle, f"S\t{ins['id']}\t0\t{stages[0]}")
            active.append(ins)
            claimed[0] = True

        orphans += sum(1 for s in range(1, n)
                       if cells[s] is not None and not claimed[s])

    # Завершение: всё, что осталось
    end = rows[-1][0] + 1 if rows else 0
    for ins in sorted(active, key=lambda i: i["id"]):
        leave(ins, end, flushed=(ins["stage"] != n - 1))

    if orphans:
        print(f"[warn] {orphans} ячеек не удалось сопоставить с инструкциями "
              f"(проигнорированы)", file=sys.stderr)
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


def main():
    ap = argparse.ArgumentParser(description="Дамп конвейера -> Konata (Kanata 0004)")
    ap.add_argument("input")
    ap.add_argument("output")
    ap.add_argument("--stages", nargs="+",
                    default=["IF1", "IF2", "ID", "EX", "MEM", "WB"],
                    help="имена стадий слева направо")
    args = ap.parse_args()

    rows = read_rows(args.input, len(args.stages))
    if not rows:
        sys.exit("Во входном файле нет строк вида 'N: ...'")
    events, count = convert(rows, args.stages)
    write_kanata(events, args.output)
    print(f"Готово: {count} инструкций, {len(rows)} тактов -> {args.output}")


if __name__ == "__main__":
    main()