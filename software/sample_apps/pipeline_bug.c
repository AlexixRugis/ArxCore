#include <stdint.h>
#include <string.h>

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
    int32_t a = 5;
    int32_t b = 3;
    int32_t i = 1;
    int32_t result = 0;
    
    __asm__ volatile (
        "    add  %3, zero, zero\n"   // result = 0
        "    li   %4, 1\n"            // i = 1
        "loop:\n"
        "    beqz %4, end\n"          // if (i == 0) goto end
        "    j    end\n"              // безусловный переход
        "    mul  %0, %1, %2\n"       // mul после j (3 инструкции после beqz)
        "end:\n"
        "    add  %3, %0, zero\n"     // result = mul_result
        : "=r"(result), "=r"(a), "=r"(b), "=r"(result), "=r"(i)
        : "0"(a), "1"(b), "2"(result), "3"(i)
        : 
    );
    
    *out = result;
    
    return 0;
}