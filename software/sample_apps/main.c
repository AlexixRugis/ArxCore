#include <stdio.h>
#include <stdint.h>

#define TICKS_PER_MS 1000

volatile int* out = (volatile int*) 0x40000000;
volatile int* timer = (volatile int*) 0x40000004;

extern volatile uint32_t* jtag_uart_status;

volatile int* pio = (volatile int*)0x60000010;

uint32_t get_time() {
    return *timer;
}

void delay(uint32_t milliseconds) {
    uint32_t start = get_time();
    uint32_t delta = TICKS_PER_MS * milliseconds;
    while (get_time() - start < delta);
}

int main() {
    delay(500);
    *out = ((*jtag_uart_status) >> 16);
    printf("Hello from ArxCore!\n");
    printf("Designed by AlexixRugis \\(-.-)/");

    *out = ((*jtag_uart_status) >> 16);

    int c = 0;
    while (true) {
        //printf("Out = %d\n", c);
        //*out = c++;
        delay(500);
    }

    return 0;
}