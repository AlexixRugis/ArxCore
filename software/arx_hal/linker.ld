ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 256K
    RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 128K
}

SECTIONS
{
    .text :
    {
        . = ALIGN(4);

        KEEP(*(.text.boot))
        KEEP(*(.text.entry))

        *(.text*)
        *(.rodata*)
        *(.srodata*)

        . = ALIGN(4);
        _text_end = .;
    } > ROM

    .sdata : AT(_text_end)
    {
        . = ALIGN(4);
        _sdata_start = .;
        
        *(.sdata*)
        
        . = ALIGN(4);
        _sdata_end = .;
    } > RAM
    
    /* Обычные данные */
    .data : AT(_text_end + SIZEOF(.sdata))
    {
        . = ALIGN(4);
        _data_start = .;
        
        *(.data*)
        
        . = ALIGN(4);
        _data_end = .;
    } > RAM

    _sdata_load = LOADADDR(.sdata);
    _data_load = LOADADDR(.data);

     /* Неинициализированные маленькие данные */
    .sbss :
    {
        . = ALIGN(4);
        _sbss_start = .;
        
        *(.sbss*)
        
        . = ALIGN(4);
        _sbss_end = .;
    } > RAM
    
    /* Обычный BSS */
    .bss :
    {
        . = ALIGN(64);
        _bss_start = .;
        
        *(.bss*)
        *(COMMON)
        
        . = ALIGN(4);
        _bss_end = .;
    } > RAM


    .heap : {
        . = ALIGN(8);
        _end = .;
        . += 32K;
        _heap_end = .;
    } > RAM

    /* Стек */
    .stack : {
        . = ALIGN(16);
        _stack_start = .;
        . += 32K;
        _stack_top = .;
    } > RAM
}