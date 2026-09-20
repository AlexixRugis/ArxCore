#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

// ========================== FIXED-POINT SETUP ==========================
#define FIXED_SHIFT 16
#define FIXED_SCALE  (1 << FIXED_SHIFT)
#define FIXED_ONE    FIXED_SCALE

typedef int32_t fixed;

// Преобразование float -> fixed (используется только для инициализации)
#define FLOAT_TO_FIXED(f) ((fixed)((f) * FIXED_SCALE))

// Умножение двух fixed чисел (результат снова fixed)
#define FIXED_MUL(a, b) ((fixed)(((int64_t)(a) * (b)) >> FIXED_SHIFT))

// Деление двух fixed чисел: a / b (b != 0)
#define FIXED_DIV(a, b) ((fixed)(((int64_t)(a) * FIXED_SCALE) / (b)))

// Преобразование fixed -> int (отбрасываем дробную часть)
#define FIXED_TO_INT(f) ((f) >> FIXED_SHIFT)

// ========================== ТАЙМЕР (как в оригинале) ====================
#define TICKS_PER_MS 1000
volatile int* timer = (volatile int*) 0x40000004;

uint32_t get_time(void) {
    return *timer;
}

void delay(uint32_t milliseconds) {
    uint32_t start = get_time();
    uint32_t delta = TICKS_PER_MS * milliseconds;
    while (get_time() - start < delta);
}

// ========================== ОСНОВНАЯ ПРОГРАММА =========================
int main(void) {
    // A и B храним в fixed, но обновляем их с помощью констант
    fixed A = 0;
    fixed B = 0;
    const fixed A_step = FLOAT_TO_FIXED(0.1f);
    const fixed B_step = FLOAT_TO_FIXED(0.08f);

    // Таблицы sin/cos для i (шаг 0.02, 314 точек)
    #define I_STEP  0.02f
    #define I_COUNT 314   // 6.28 / 0.02 ≈ 314
    fixed sini[I_COUNT];
    fixed cosi[I_COUNT];
    for (int idx = 0; idx < I_COUNT; idx++) {
        float angle = idx * I_STEP;
        sini[idx] = FLOAT_TO_FIXED(sinf(angle));
        cosi[idx] = FLOAT_TO_FIXED(cosf(angle));
    }

    // Таблицы sin/cos для j (шаг 0.07, 90 точек)
    #define J_STEP  0.07f
    #define J_COUNT 90    // 6.28 / 0.07 ≈ 89.7 → 90
    fixed sinj[J_COUNT];
    fixed cosj[J_COUNT];
    for (int jdx = 0; jdx < J_COUNT; jdx++) {
        float angle = jdx * J_STEP;
        sinj[jdx] = FLOAT_TO_FIXED(sinf(angle));
        cosj[jdx] = FLOAT_TO_FIXED(cosf(angle));
    }

    // Буферы кадра
    char   b[1760];
    fixed  z[1760];

    // Константы в fixed
    const fixed TWO   = FLOAT_TO_FIXED(2.0f);
    const fixed THIRTY = FLOAT_TO_FIXED(30.0f);
    const fixed FIFTEEN = FLOAT_TO_FIXED(15.0f);
    const fixed EIGHT = FLOAT_TO_FIXED(8.0f);
    const fixed FORTY = FLOAT_TO_FIXED(40.0f);
    const fixed TWELVE = FLOAT_TO_FIXED(12.0f);
    const fixed FIVE  = FLOAT_TO_FIXED(5.0f);

    // Строка символов для отображения
    const char* symbols = ".,-~:;=!*#$@";

    for (;;) {
        // Очистка буферов
        memset(b, 32, 1760);
        memset(z, 0, sizeof(z));

        // e = sin(A), g = cos(A), m = cos(B), n = sin(B)
        // Здесь мы всё ещё используем библиотечные sin/cos для A и B,
        // так как они вычисляются всего раз за кадр — это допустимо.
        fixed e = FLOAT_TO_FIXED(sinf(A / (float)FIXED_SCALE));
        fixed g = FLOAT_TO_FIXED(cosf(A / (float)FIXED_SCALE));
        fixed m = FLOAT_TO_FIXED(cosf(B / (float)FIXED_SCALE));
        fixed n = FLOAT_TO_FIXED(sinf(B / (float)FIXED_SCALE));

        // Внешний цикл по j
        for (int jdx = 0; jdx < J_COUNT; jdx++) {
            fixed d = cosj[jdx];
            fixed f = sinj[jdx];

            fixed h  = d + TWO;               // h = d + 2
            fixed hm30 = FIXED_MUL(FIXED_MUL(h, m), THIRTY); // 30 * h * m
            fixed n30  = FIXED_MUL(n, THIRTY);               // 30 * n
            fixed hn15 = FIXED_MUL(FIXED_MUL(h, n), FIFTEEN); // 15 * h * n
            fixed m15  = FIXED_MUL(m, FIFTEEN);              // 15 * m

            fixed fe  = FIXED_MUL(f, e);
            fixed fem = FIXED_MUL(fe, m);
            fixed fg  = FIXED_MUL(f, g);
            fixed fg5 = fg + FIVE;           // fg + 5

            fixed he = FIXED_MUL(h, e);
            fixed hg = FIXED_MUL(h, g);
            fixed de = FIXED_MUL(d, e);
            fixed dn8 = FIXED_MUL(FIXED_MUL(d, n), EIGHT);  // 8 * d * n
            fixed dg = FIXED_MUL(d, g);
            fixed dgm = FIXED_MUL(dg, m);

            // Выражения, не зависящие от i
            fixed femfg8  = FIXED_MUL((fem - fg), EIGHT);   // 8*(fem - fg)
            fixed dgmde8  = FIXED_MUL((dgm + de), EIGHT);   // 8*(dgm + de)

            // Внутренний цикл по i
            for (int idx = 0; idx < I_COUNT; idx++) {
                fixed c = sini[idx];
                fixed l = cosi[idx];

                // den = c*he + fg5
                fixed den = FIXED_MUL(c, he) + fg5;
                // D = 1 / den  (в формате fixed)
                fixed D = FIXED_DIV(FIXED_ONE, den);

                // t = c*hg - fe
                fixed t = FIXED_MUL(c, hg) - fe;

                // Вычисляем x и y
                fixed x_fixed = FORTY + FIXED_MUL(D, FIXED_MUL(l, hm30) - FIXED_MUL(t, n30));
                fixed y_fixed = TWELVE + FIXED_MUL(D, FIXED_MUL(l, hn15) + FIXED_MUL(t, m15));

                int x = FIXED_TO_INT(x_fixed);
                int y = FIXED_TO_INT(y_fixed);

                int o = x + 80 * y;

                // N = 8*(fem - fg) - c*(8*(dgm + de)) - l*(8*d*n)
                fixed N_fixed = femfg8 - FIXED_MUL(c, dgmde8) - FIXED_MUL(l, dn8);
                int N = FIXED_TO_INT(N_fixed);
                if (N < 0) N = 0;
                if (N > 11) N = 11;  // индекс в строке символов

                // Проверка границ и глубины
                if (22 > y && y > 0 && x > 0 && 80 > x && D > z[o]) {
                    z[o] = D;
                    b[o] = symbols[N];
                }
            }
        }

        // Вывод кадра
        for (int k = 0; k < 50; k++) putchar('\n');
        for (int k = 0; k < 1761; k++) {
            putchar(k % 80 ? b[k] : 10);
        }

        // Обновление углов
        A += A_step;
        B += B_step;

        delay(30);
    }

    return 0;
}