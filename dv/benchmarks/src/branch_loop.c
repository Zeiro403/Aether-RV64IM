volatile unsigned long result;

int main(void)
{
    unsigned long sum = 0;

    for (unsigned long i = 0; i < 10000; i++) {
        if (i & 1)
            sum += i;
        else
            sum += 3;
    }

    result = sum;

    volatile unsigned long *tohost =
        (volatile unsigned long *)0xF0000000UL;

    *tohost = 1;

    while (1) {}

    return 0;
}