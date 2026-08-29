#include <stdio.h>
#include <stdint.h>

#define TICKS_PER_MS 50000

volatile int* out = (volatile int*) 0x40000000;
volatile int* timer = (volatile int*) 0x40000004;

uint32_t get_time() {
    return *timer;
}

void delay(uint32_t milliseconds) {
    uint32_t start = get_time();
    uint32_t delta = TICKS_PER_MS * milliseconds;
    while (get_time() - start < delta);
}

int main() {

    int cur = 0;
    while (true) {
        *out = cur++;
        //delay(1000);
    }

    return 0;
}