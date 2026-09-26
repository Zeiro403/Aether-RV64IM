#define SIZE 256
#define ITERATIONS 10000

volatile unsigned long data[SIZE];
volatile unsigned long benchmark_result;

int main(void)
{
    unsigned long sum = 0;

    for (unsigned long i = 0; i < SIZE; i++) {
        data[i] = i * 3UL + 1UL;
    }

    for (unsigned long i = 0; i < ITERATIONS; i++) {
        unsigned long index = i & (SIZE - 1);

        data[index] += i;
        sum += data[index];
    }

    benchmark_result = sum;

    volatile unsigned long *tohost =
        (volatile unsigned long *)0xF0000000UL;

    *tohost = 1;

    while (1) {}

    return 0;
}