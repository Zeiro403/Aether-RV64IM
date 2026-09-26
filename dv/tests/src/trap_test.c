#include "test_macros.h"

static inline unsigned long csr_read_mcause(void)
{
    unsigned long value;
    asm volatile ("csrr %0, mcause" : "=r"(value));
    return value;
}

static inline unsigned long csr_read_mepc(void)
{
    unsigned long value;
    asm volatile ("csrr %0, mepc" : "=r"(value));
    return value;
}

static inline unsigned long csr_read_mtval(void)
{
    unsigned long value;
    asm volatile ("csrr %0, mtval" : "=r"(value));
    return value;
}

__attribute__((naked, aligned(4)))
void trap_handler(void)
{
    asm volatile (
        "csrr t0, mcause\n"
        "li   t1, 11\n"
        "bne  t0, t1, 1f\n"

        // ECALL requires mtval = 0.
        "csrr t0, mtval\n"
        "bnez t0, 1f\n"

        // Resume after ECALL.
        "csrr t0, mepc\n"
        "addi t0, t0, 4\n"
        "csrw mepc, t0\n"

        "mret\n"

        // Failure path.
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

    asm volatile ("ecall");

    // Reaching here proves MRET returned successfully.
    if (csr_read_mcause() != 11)
        TEST_FAIL_CODE(2);

    if (csr_read_mtval() != 0)
        TEST_FAIL_CODE(3);

    if (csr_read_mepc() == 0)
        TEST_FAIL_CODE(4);

    TEST_PASS();

    return 0;
}