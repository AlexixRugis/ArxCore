cmake_minimum_required(VERSION 3.10)

project(coremark LANGUAGES C ASM)

set(CMAKE_C_COMPILER riscv64-unknown-elf-gcc)
set(CMAKE_ASM_COMPILER riscv64-unknown-elf-gcc)

add_subdirectory(
    ${CMAKE_SOURCE_DIR}/../arx_hal
    ${CMAKE_BINARY_DIR}/arx_hal
)

add_executable(${CMAKE_PROJECT_NAME}.elf
    ${CMAKE_CURRENT_SOURCE_DIR}/core_list_join.c
    ${CMAKE_CURRENT_SOURCE_DIR}/core_main.c
    ${CMAKE_CURRENT_SOURCE_DIR}/core_matrix.c
    ${CMAKE_CURRENT_SOURCE_DIR}/core_state.c
    ${CMAKE_CURRENT_SOURCE_DIR}/core_util.c
    ${CMAKE_CURRENT_SOURCE_DIR}/barebones/core_portme.c
    $<TARGET_OBJECTS:arx_hal>
)

target_include_directories(${CMAKE_PROJECT_NAME}.elf
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/barebones
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}
)

string(REPLACE ";" " " HAL_FLAGS_STR "${HAL_FLAGS}")
target_compile_definitions(${CMAKE_PROJECT_NAME}.elf PRIVATE
    ITERATIONS=1000
    PERFORMANCE_RUN=1
    VALIDATION_RUN=0
    FLAGS_STR="${HAL_FLAGS_STR}"
)

target_compile_options(${CMAKE_PROJECT_NAME}.elf PRIVATE ${HAL_FLAGS})

target_link_options(${CMAKE_PROJECT_NAME}.elf PRIVATE
    -T ${HAL_LINKER_SCRIPT}
    -nostartfiles
    -Wl,-Map=output.map,--gc-sections
    -march=${HAL_ARCH}
    -mabi=${HAL_ABI}
)