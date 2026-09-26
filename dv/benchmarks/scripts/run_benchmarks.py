import csv
import os
import re
import subprocess
import sys


BENCH_SRC_DIR = "dv/benchmarks/src"
BENCH_BIN_DIR = "dv/benchmarks/bin"
RESULT_DIR = "dv/benchmarks/results"

PROGRAM_HEX = "sw/program.hex"
SIM_EXE = "./obj_dir/Vsoc_top"

BENCHMARKS = [
    "branch_loop",
    "arithmetic",
    "memory",
    "muldiv",
    "mixed",
]


PERF_RE = re.compile(
    r"\[AETHER PERF\]\s+"
    r"cycles=(\d+)\s+"
    r"instructions=(\d+)\s+"
    r"cpi=([0-9.]+)\s+"
    r"branches=(\d+)\s+"
    r"taken=(\d+)\s+"
    r"redirects=(\d+)\s+"
    r"loads=(\d+)\s+"
    r"stores=(\d+)\s+"
    r"muldiv=(\d+)\s+"
    r"ex_stall=(\d+)\s+"
    r"mem_stall=(\d+)"
)


def compile_benchmark(name):
    src = os.path.join(BENCH_SRC_DIR, name + ".c")
    elf = os.path.join(BENCH_BIN_DIR, name + ".elf")
    binary = os.path.join(BENCH_BIN_DIR, name + ".bin")

    gcc_cmd = [
        "riscv64-unknown-elf-gcc",

        "-O1",

        "-mcmodel=medany",
        "-march=rv64im",
        "-mabi=lp64",

        "-nostdlib",

        "-T",
        "sw/link.ld",

        "-o",
        elf,

        "sw/crt0.s",
        src,
    ]

    result = subprocess.run(gcc_cmd)

    if result.returncode != 0:
        return False

    objcopy_cmd = [
        "riscv64-unknown-elf-objcopy",
        "-O",
        "binary",
        elf,
        binary,
    ]

    result = subprocess.run(objcopy_cmd)

    if result.returncode != 0:
        return False

    with open(PROGRAM_HEX, "w") as hex_file:
        result = subprocess.run(
            [
                "hexdump",
                "-v",
                "-e",
                '1/4 "%08x\\n"',
                binary,
            ],
            stdout=hex_file,
        )

    return result.returncode == 0


def run_benchmark():
    result = subprocess.run(
        [SIM_EXE],
        capture_output=True,
        text=True,
    )

    output = result.stdout + result.stderr

    if result.returncode != 0:
        return None, output

    if "[SIM] TEST PASSED!" not in output:
        return None, output

    match = PERF_RE.search(output)

    if not match:
        return None, output

    metrics = {
        "cycles": int(match.group(1)),
        "instructions": int(match.group(2)),
        "cpi": float(match.group(3)),
        "branches": int(match.group(4)),
        "taken": int(match.group(5)),
        "redirects": int(match.group(6)),
        "loads": int(match.group(7)),
        "stores": int(match.group(8)),
        "muldiv": int(match.group(9)),
        "ex_stall": int(match.group(10)),
        "mem_stall": int(match.group(11)),
    }

    return metrics, output


def main():
    os.makedirs(BENCH_BIN_DIR, exist_ok=True)
    os.makedirs(RESULT_DIR, exist_ok=True)

    rows = []

    print()
    print(
        f"{'BENCHMARK':<16}"
        f"{'CYCLES':>12}"
        f"{'INSTR':>12}"
        f"{'CPI':>10}"
        f"{'BRANCH':>10}"
        f"{'TAKEN':>10}"
        f"{'EXSTALL':>12}"
        f"{'MEMSTALL':>12}"
    )

    print("-" * 94)

    failures = 0

    for benchmark in BENCHMARKS:

        if not compile_benchmark(benchmark):
            print(f"{benchmark:<16} COMPILE FAILED")
            failures += 1
            continue

        metrics, log = run_benchmark()

        if metrics is None:
            print(f"{benchmark:<16} SIMULATION FAILED")
            print(log)
            failures += 1
            continue

        row = {
            "benchmark": benchmark,
            **metrics,
        }

        rows.append(row)

        print(
            f"{benchmark:<16}"
            f"{metrics['cycles']:>12}"
            f"{metrics['instructions']:>12}"
            f"{metrics['cpi']:>10.4f}"
            f"{metrics['branches']:>10}"
            f"{metrics['taken']:>10}"
            f"{metrics['ex_stall']:>12}"
            f"{metrics['mem_stall']:>12}"
        )

    output_csv = os.path.join(
        RESULT_DIR,
        "baseline.csv",
    )

    fieldnames = [
        "benchmark",
        "cycles",
        "instructions",
        "cpi",
        "branches",
        "taken",
        "redirects",
        "loads",
        "stores",
        "muldiv",
        "ex_stall",
        "mem_stall",
    ]

    with open(
        output_csv,
        "w",
        newline="",
        encoding="utf-8",
    ) as csv_file:

        writer = csv.DictWriter(
            csv_file,
            fieldnames=fieldnames,
        )

        writer.writeheader()
        writer.writerows(rows)

    print()
    print(f"Results written to: {output_csv}")

    if failures:
        print(f"{failures} benchmark(s) failed.")
        sys.exit(1)

    print("All benchmarks passed.")


if __name__ == "__main__":
    main()