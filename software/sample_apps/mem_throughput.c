#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define TICKS_PER_MS 1000

volatile int* out = (volatile int*) 0x40000000;
volatile int* timer = (volatile int*) 0x40000004;

int a[512];
int b[512];

int main() {

    printf("Hello!\n");

    uint32_t start_time = *timer;

    for (uint32_t i = 0; i < 1024; i++) {
        memcpy(b, a, sizeof(a));
    }

    uint32_t end_time = *timer;
    uint32_t result = (end_time - start_time) / TICKS_PER_MS;
    *out = result;

    printf("Copying Time (512 bytes x 1024): %u ms\n", result);

    return 0;
}