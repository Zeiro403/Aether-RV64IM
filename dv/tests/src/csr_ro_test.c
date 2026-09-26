#include "test_macros.h"

volatile unsigned long illegal_seen = 0;

__attribute__((naked, aligned(4)))
void trap_handler(void)
{
    asm volatile (
        "csrr t0, mcause\n"
        "li   t1, 2\n"
        "bne  t0, t1, 1f\n"

        "la   t0, illegal_seen\n"
        "li   t1, 1\n"
        "sd   t1, 0(t0)\n"

        // Skip illegal CSR instruction.
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
    unsigned long misa;

    asm volatile (
        "la t0, trap_handler\n"
        "csrw mtvec, t0\n"
        :
        :
        : "t0"
    );

    // Reading read-only misa is legal.
    asm volatile (
        "csrrs %0, misa, x0"
        : "=r"(misa)
    );

    if (misa == 0)
        TEST_FAIL_CODE(2);

    // Writing read-only misa must trap.
    asm volatile (
        "li t0, 1\n"
        "csrrw x0, misa, t0\n"
        :
        :
        : "t0"
    );

    if (illegal_seen != 1)
        TEST_FAIL_CODE(3);

    TEST_PASS();

    return 0;
}