#include "test_macros.h"

volatile unsigned long expected_cause = 0;
volatile unsigned long expected_addr  = 0;
volatile unsigned long trap_count     = 0;

__attribute__((naked, aligned(4)))
void trap_handler(void)
{
    asm volatile (
        // Check mcause.
        "csrr t0, mcause\n"
        "la   t1, expected_cause\n"
        "ld   t1, 0(t1)\n"
        "bne  t0, t1, 1f\n"

        // Check mtval.
        "csrr t0, mtval\n"
        "la   t1, expected_addr\n"
        "ld   t1, 0(t1)\n"
        "bne  t0, t1, 1f\n"

        // Count successful trap.
        "la   t0, trap_count\n"
        "ld   t1, 0(t0)\n"
        "addi t1, t1, 1\n"
        "sd   t1, 0(t0)\n"

        // Skip faulting instruction.
        "csrr t0, mepc\n"
        "addi t0, t0, 4\n"
        "csrw mepc, t0\n"

        "mret\n"

        "1:\n"
        "li t0, 4\n"
        "li t1, 0xF0000000\n"
        "sd t0, 0(t1)\n"

        "2:\n"
        "j 2b\n"
    );
}

int main(void)
{
    asm volatile (
        "la t0, trap_handler\n"
        "csrw mtvec, t0\n"
        :
        :
        : "t0"
    );

    // ------------------------------------------------------------
    // Misaligned LD
    // ------------------------------------------------------------

    expected_cause = 4;
    expected_addr  = 0x80001003UL;

    asm volatile (
        "li t0, 0x80001003\n"
        "ld t1, 0(t0)\n"
        :
        :
        : "t0", "t1"
    );

    if (trap_count != 1)
        TEST_FAIL_CODE(2);

    // ------------------------------------------------------------
    // Misaligned SD
    // ------------------------------------------------------------

    expected_cause = 6;
    expected_addr  = 0x80001005UL;

    asm volatile (
        "li t0, 0x80001005\n"
        "li t1, 0x1234\n"
        "sd t1, 0(t0)\n"
        :
        :
        : "t0", "t1"
    );

    if (trap_count != 2)
        TEST_FAIL_CODE(3);

    TEST_PASS();

    return 0;
}