volatile unsigned long benchmark_result;

int main(void)
{
    unsigned long a = 1;
    unsigned long b = 3;
    unsigned long c = 7;

    for (unsigned long i = 0; i < 10000; i++) {
        a = a + b;
        b = b ^ c;
        c = c + i;
        a = a ^ (c << 1);
        b = b + (a >> 2);
    }

    benchmark_result = a ^ b ^ c;

    volatile unsigned long *tohost =
        (volatile unsigned long *)0xF0000000UL;

    *tohost = 1;

    while (1) {}

    return 0;
}