cmake_minimum_required(VERSION 3.10)

set(HAL_ARCH "rv32im" CACHE STRING "RISC-V architecture")
set(HAL_ABI  "ilp32"  CACHE STRING "RISC-V ABI")

get_filename_component(HAL_LINKER_SCRIPT
    "${CMAKE_CURRENT_SOURCE_DIR}/linker.ld" ABSOLUTE
)

set(HAL_FLAGS
    -march=${HAL_ARCH}
    -mabi=${HAL_ABI}
    -ffreestanding
    -O3
)

add_library(arx_hal OBJECT
    start.S
    syscalls.c
)

target_compile_options(arx_hal PRIVATE ${HAL_FLAGS})

set(HAL_ARCH          ${HAL_ARCH}          PARENT_SCOPE)
set(HAL_ABI           ${HAL_ABI}           PARENT_SCOPE)
set(HAL_LINKER_SCRIPT ${HAL_LINKER_SCRIPT} PARENT_SCOPE)
set(HAL_FLAGS         ${HAL_FLAGS}         PARENT_SCOPE)