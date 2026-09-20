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

static void t_llb_diff(void) {
    // Тестируется правильность конвейеризации операций с памятью.

    uint32_t a0 = (uint32_t)out + 0;
    uint32_t a1 = (uint32_t)out + 1;
    uint32_t a2 = (uint32_t)out + 2;
    uint32_t a3 = (uint32_t)out + 3;
    uint32_t v0,v1,v2,v3;
    *out = 0x03020100;
    asm volatile (
        "lbu %0, 0(%4)\n\t"
        "lbu %1, 0(%5)\n\t"
        "lbu %2, 0(%6)\n\t"
        "lbu %3, 0(%7)\n\t"
        : "=&r"(v0),"=&r"(v1),"=&r"(v2),"=&r"(v3)
        : "r"(a0),"r"(a1),"r"(a2),"r"(a3)
        : "memory"
    );
    //*out = 2;
    *out = 0xff; delay(1000);
    *out = v0; delay(1000);
    *out = 0xff; delay(500);
    *out = v1; delay(1000);
    *out = 0xff; delay(500);
    *out = v2; delay(1000);
    *out = 0xff; delay(500);
    *out = v3; delay(1000);
}

int main() {

    t_llb_diff();

    // for (int i = 0; i < 10; i++) {
    //     *out = i;
    // }

    // delay(500);
    // *out = ((*jtag_uart_status) >> 16);
    // printf("Hello from ArxCore!\n");
    // printf("Designed by AlexixRugis \\(-.-)/\n");

    // *out = ((*jtag_uart_status) >> 16);

    // int c = 0;
    // while (true) {
    //     printf("Out = %d\n", c);
    //     *out = c++;
    //     delay(500);
    // }

    return 0;
}