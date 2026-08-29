.section .text.boot
.globl _start

_start:
    /* стек */
    la sp, _stack_top

    la a0, _sbss_start
    la a1, _sbss_end
    call zero_loop

    la a0, _bss_start
    la a1, _bss_end
    call zero_loop

    la a0, _data_start
    la a1, _data_load
    la a2, _data_end
    sub a2, a2, a0
    call memcpy_loop

    la a0, _sdata_start
    la a1, _sdata_load
    la a2, _sdata_end
    sub a2, a2, a0
    call memcpy_loop

    call main

5:
    j 5b

# a0 = destination (RAM)
# a1 = source (ROM)
# a2 = size в байтах
memcpy_loop:
    beqz a2, memcpy_done
    
memcpy_byte:
    lb t0, 0(a1)
    sb t0, 0(a0)
    addi a0, a0, 1
    addi a1, a1, 1
    addi a2, a2, -1
    bnez a2, memcpy_byte
    
memcpy_done:
    ret

# a0 = start address
# a1 = end address
zero_loop:
    beq a0, a1, zero_done
    
zero_byte:
    sb zero, 0(a0)
    addi a0, a0, 1
    bne a0, a1, zero_byte
    
zero_done:
    ret