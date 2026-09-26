#define SIZE 64
#define ITERATIONS 5000

volatile unsigned long data[SIZE];
volatile unsigned long benchmark_result;

int main(void)
{
    unsigned long acc = 1;

    for (unsigned long i = 0; i < SIZE; i++) {
        data[i] = i + 1;
    }

    for (unsigned long i = 1; i <= ITERATIONS; i++) {
        unsigned long index = i & (SIZE - 1);
        unsigned long value = data[index];

        if (value & 1UL)
            acc += value * 3UL;
        else
            acc ^= value + i;

        data[index] = acc ^ i;

        if ((i & 7UL) == 0)
            acc += i;
    }

    benchmark_result = acc;

    volatile unsigned long *tohost =
        (volatile unsigned long *)0xF0000000UL;

    *tohost = 1;

    while (1) {}

    return 0;
}