cmake_minimum_required(VERSION 3.10)

project(sample_app LANGUAGES C ASM)

set(CMAKE_C_COMPILER riscv64-unknown-elf-gcc)
set(CMAKE_ASM_COMPILER riscv64-unknown-elf-gcc)

add_subdirectory(
    ${CMAKE_SOURCE_DIR}/../arx_hal
    ${CMAKE_BINARY_DIR}/arx_hal
)

function(add_app src)
    get_filename_component(name ${src} NAME_WE)
    set(target ${CMAKE_PROJECT_NAME}_${name}.elf)

    add_executable(${target}
        ${src}
        $<TARGET_OBJECTS:arx_hal>
    )
    
    target_link_libraries(${target} m)

    target_compile_options(${target} PRIVATE ${HAL_FLAGS})

    target_link_options(${target} PRIVATE
        -T ${HAL_LINKER_SCRIPT}
        -nostartfiles
        -Wl,-Map=output.map,--gc-sections
        -march=${HAL_ARCH}
        -mabi=${HAL_ABI}
    )
endfunction()

add_app(main.c)
add_app(donut.c)
add_app(mem_throughput.c)
add_app(pipeline_bug.c)