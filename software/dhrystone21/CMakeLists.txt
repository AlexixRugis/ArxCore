cmake_minimum_required(VERSION 3.10)

project(dhrystone LANGUAGES C ASM)

set(CMAKE_C_COMPILER riscv64-unknown-elf-gcc)
set(CMAKE_ASM_COMPILER riscv64-unknown-elf-gcc)

add_subdirectory(
    ${CMAKE_SOURCE_DIR}/../arx_hal
    ${CMAKE_BINARY_DIR}/arx_hal
)

add_executable(${CMAKE_PROJECT_NAME}.elf
    dhrystone_main.c
    dhrystone.c
    $<TARGET_OBJECTS:arx_hal>
)

target_include_directories(${CMAKE_PROJECT_NAME}.elf
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}
)

target_compile_options(${CMAKE_PROJECT_NAME}.elf PRIVATE ${HAL_FLAGS})

target_link_options(${CMAKE_PROJECT_NAME}.elf PRIVATE
    -T ${HAL_LINKER_SCRIPT}
    -nostartfiles
    -Wl,-Map=output.map,--gc-sections
    -march=${HAL_ARCH}
    -mabi=${HAL_ABI}
)