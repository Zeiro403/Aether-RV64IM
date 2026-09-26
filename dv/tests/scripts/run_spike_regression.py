import os
import subprocess
import sys


TEST_SRC_DIR = "dv/tests/src"
TEST_BIN_DIR = "dv/tests/bin"

PROG_HEX = "sw/program.hex"
SIM_EXE = "./obj_dir/Vsoc_top"

RTL_LOG = "rtl.log"
SPIKE_LOG = "spike.log"

COMPARE_SCRIPT = "dv/tests/scripts/spike_cmp.py"

SPIKE = os.environ.get("SPIKE", "spike")


# Tests that are intentionally Aether-specific or whose architectural
# environment differs from the simple Spike comparison environment.
#
# Keep exclusions explicit. A test should never silently disappear from
# differential verification.
EXCLUDED_TESTS = {
    "csr_test",
    "csr_ro_test",
    "ebreak_test",
    "illegal_test",
    "misaligned_test",
    "trap_test",
}


def fail(message):
    print(f"ERROR: {message}")
    sys.exit(1)


def get_tests():
    """
    Differentially test every compiled regression program except tests whose
    trap/environment semantics intentionally differ from the simple Spike run.
    """

    tests = []

    for filename in sorted(os.listdir(TEST_SRC_DIR)):
        if not (filename.endswith(".c") or filename.endswith(".S")):
            continue

        name, _ = os.path.splitext(filename)

        if name in EXCLUDED_TESTS:
            continue

        elf_file = os.path.join(TEST_BIN_DIR, name + ".elf")
        bin_file = os.path.join(TEST_BIN_DIR, name + ".bin")

        if os.path.isfile(elf_file) and os.path.isfile(bin_file):
            tests.append(name)

    return tests


def make_program_hex(bin_file):
    """
    Convert the regression binary into the 32-bit-word format expected by
    axi_ram_sim.sv.
    """

    command = (
        "hexdump -v -e '1/4 \"%08x\\n\"' "
        f"{bin_file} > {PROG_HEX}"
    )

    result = subprocess.run(
        command,
        shell=True,
    )

    return result.returncode == 0


def run_rtl():
    """
    Run the already-built RTL simulator.

    Hardware is owned by the Makefile. This script must never rebuild it.
    """

    with open(RTL_LOG, "w", encoding="utf-8") as log:
        result = subprocess.run(
            [SIM_EXE],
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
        )

    return result.returncode


def count_rtl_retirements():
    count = 0

    with open(RTL_LOG, "r", encoding="utf-8") as log:
        for line in log:
            if line.startswith("core") and ":" in line:
                count += 1

    return count


def run_spike(elf_file, rtl_retirements):
    """
    Run Spike long enough to cover the complete RTL retirement trace.

    Spike emits multiple textual lines per instruction, so use a generous
    trace-line allowance derived from the RTL retirement count.
    """

    max_lines = rtl_retirements * 4 + 500

    spike_cmd = [
        SPIKE,
        "--isa=rv64im",
        "-m0x80000000:0x100000,0xf0000000:0x1000",
        "-l",
        "--log-commits",
        elf_file,
    ]

    try:
        spike = subprocess.Popen(
            spike_cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError:
        return False, f"Spike executable not found: {SPIKE}"

    lines = []

    assert spike.stderr is not None

    try:
        for line in spike.stderr:
            lines.append(line)

            if len(lines) >= max_lines:
                break
    finally:
        # Spike may continue forever after the test reaches its terminal loop.
        spike.terminate()

        try:
            spike.wait(timeout=2)
        except subprocess.TimeoutExpired:
            spike.kill()
            spike.wait()

    with open(SPIKE_LOG, "w", encoding="utf-8") as log:
        log.writelines(lines)

    return True, max_lines


def compare():
    result = subprocess.run(
        [
            sys.executable,
            COMPARE_SCRIPT,
            RTL_LOG,
            SPIKE_LOG,
        ],
        capture_output=True,
        text=True,
    )

    output = result.stdout

    if result.stderr:
        output += result.stderr

    return result.returncode == 0, output


def main():
    if not os.path.isfile(SIM_EXE):
        fail(
            f"Simulator not found: {SIM_EXE}\n"
            "Build hardware before running Spike regression."
        )

    if not os.path.isdir(TEST_BIN_DIR):
        fail(
            f"{TEST_BIN_DIR} does not exist.\n"
            "Run the architectural regression first."
        )

    tests = get_tests()

    if not tests:
        fail(
            "No compiled differential tests were found.\n"
            "Run 'make regression' first."
        )

    print()
    print("Aether Spike Differential Regression")
    print("=" * 68)
    print(f"Tests selected : {len(tests)}")
    print(f"Tests excluded : {len(EXCLUDED_TESTS)}")
    print()

    passed = 0
    failed = 0

    failures = []

    print(f"{'TEST':<30} | {'RTL INSTR':>10} | STATUS")
    print("-" * 68)

    for test_name in tests:
        elf_file = os.path.join(TEST_BIN_DIR, test_name + ".elf")
        bin_file = os.path.join(TEST_BIN_DIR, test_name + ".bin")

        if not make_program_hex(bin_file):
            print(
                f"{test_name:<30} | {'-':>10} | FAIL (hex)"
            )
            failures.append((test_name, "program.hex generation failed"))
            failed += 1
            continue

        rtl_rc = run_rtl()

        if rtl_rc != 0:
            print(
                f"{test_name:<30} | {'-':>10} | FAIL (RTL)"
            )
            failures.append(
                (
                    test_name,
                    f"RTL simulation returned {rtl_rc}",
                )
            )
            failed += 1
            continue

        retirements = count_rtl_retirements()

        if retirements == 0:
            print(
                f"{test_name:<30} | {0:>10} | FAIL (no trace)"
            )
            failures.append(
                (
                    test_name,
                    "RTL produced no retirement trace",
                )
            )
            failed += 1
            continue

        spike_ok, spike_info = run_spike(
            elf_file,
            retirements,
        )

        if not spike_ok:
            print(
                f"{test_name:<30} | "
                f"{retirements:>10} | FAIL (Spike)"
            )
            failures.append(
                (
                    test_name,
                    str(spike_info),
                )
            )
            failed += 1
            continue

        success, comparison_output = compare()

        if success:
            print(
                f"{test_name:<30} | "
                f"{retirements:>10} | PASS"
            )
            passed += 1
        else:
            print(
                f"{test_name:<30} | "
                f"{retirements:>10} | FAIL (mismatch)"
            )

            failures.append(
                (
                    test_name,
                    comparison_output,
                )
            )

            failed += 1

    print("-" * 68)
    print(
        f"SUMMARY: {passed} Passed, "
        f"{failed} Failed, "
        f"{len(EXCLUDED_TESTS)} Excluded"
    )

    if failures:
        print()
        print("Failures")
        print("=" * 68)

        for name, reason in failures:
            print()
            print(f"[{name}]")
            print(reason.rstrip())

    if failed:
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()