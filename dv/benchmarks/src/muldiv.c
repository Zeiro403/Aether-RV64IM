volatile unsigned long benchmark_result;

volatile unsigned long seed_a = 0x12345678UL;
volatile unsigned long seed_b = 17UL;

int main(void)
{
    unsigned long a = seed_a;
    unsigned long b = seed_b;
    unsigned long result = 0;

    for (unsigned long i = 1; i <= 1000; i++) {

        a = a * b + i;

        result += a * b;
        result ^= a / b;
        result += a % b;

        // Prevent b from becoming a compile-time constant.
        b = (b ^ i) | 1UL;
    }

    benchmark_result = result;

    volatile unsigned long *tohost =
        (volatile unsigned long *)0xF0000000UL;

    *tohost = 1;

    while (1) {}

    return 0;
}