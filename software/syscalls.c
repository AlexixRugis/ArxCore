// syscalls.c - реализация системных вызовов для newlib
#include <sys/stat.h>
#include <errno.h>
#include <stdint.h>

// Внешние ссылки на ваши устройства
extern volatile int* out;
extern volatile int* timer;

char out_buf[2048];
unsigned int out_ind = 0;

// Указатель на вершину кучи (должен быть определён в linker script)
extern char _end;
static char* heap_ptr = &_end;

// ============================================
// Обязательные системные вызовы для newlib
// ============================================

// Вывод символов (для printf, puts и т.д.)
int _write(int file, char *ptr, int len) {
    for (int i = 0; i < len; i++) {
        out_buf[out_ind++] = ptr[i];
    }
    return len;
}

// Чтение символов (опционально)
int _read(int file, char *ptr, int len) {
    return 0;  // Нет ввода
}

// Управление памятью (для malloc)
void *_sbrk(int incr) {
    char* prev = heap_ptr;
    // Определите конец RAM (0x20004000 для вашего случая)
    char* heap_end = (char*)0x20004000;
    
    if (heap_ptr + incr > heap_end) {
        errno = ENOMEM;
        return (void*)-1;
    }
    heap_ptr += incr;
    return prev;
}

// ============================================
// Пустые реализации (для совместимости)
// ============================================
int _close(int file) { return -1; }
int _fstat(int file, struct stat *st) { 
    st->st_mode = S_IFCHR;
    return 0;
}
int _isatty(int file) { return 1; }
int _lseek(int file, int ptr, int dir) { return 0; }
void _exit(int status) { while (1); }

// ============================================
// Для поддержки C++
// ============================================
void __attribute__((weak)) _init(void) {}
void __attribute__((weak)) _fini(void) {}