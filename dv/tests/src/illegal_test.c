#include "test_macros.h"

volatile unsigned long illegal_seen = 0;

__attribute__((naked, aligned(4)))
void trap_handler(void)
{
    asm volatile (
        "csrr t0, mcause\n"
        "li   t1, 2\n"
        "bne  t0, t1, 1f\n"

        // Deliberately illegal instruction is 0x00000000.
        "csrr t0, mtval\n"
        "bnez t0, 1f\n"

        "la   t0, illegal_seen\n"
        "li   t1, 1\n"
        "sd   t1, 0(t0)\n"

        // Skip illegal instruction.
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

    asm volatile (".word 0x00000000");

    if (illegal_seen != 1)
        TEST_FAIL_CODE(2);

    TEST_PASS();

    return 0;
}