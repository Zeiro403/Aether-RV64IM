#include "test_macros.h"

volatile unsigned long saw_breakpoint = 0;

__attribute__((naked, aligned(4)))
void trap_handler(void)
{
    asm volatile (
        "csrr t0, mcause\n"
        "li   t1, 3\n"
        "bne  t0, t1, 1f\n"

        // mtval should contain the EBREAK instruction.
        "csrr t0, mtval\n"
        "li   t1, 0x00100073\n"
        "bne  t0, t1, 1f\n"

        "la   t0, saw_breakpoint\n"
        "li   t1, 1\n"
        "sd   t1, 0(t0)\n"

        // Skip EBREAK.
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

    asm volatile ("ebreak");

    if (saw_breakpoint != 1)
        TEST_FAIL_CODE(2);

    TEST_PASS();

    return 0;
}