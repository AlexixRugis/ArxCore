
Includes="-I./coremark/barebones/ -I./coremark/"
Flags="-march=rv32im -mabi=ilp32 -ffreestanding -O2"
Flags="$Flags -DITERATIONS=1000 -DPERFORMANCE_RUN=1 -DVALIDATION_RUN=0"

riscv32-unknown-elf-gcc -c start.S \
  -march=rv32i -mabi=ilp32 \
  -o ./build/start.o
riscv32-unknown-elf-gcc $Includes -c ./coremark/core_list_join.c \
  $Flags -DFLAGS_STR="\"$Flags\"" \
  -o ./build/core_list_join.o
riscv32-unknown-elf-gcc $Includes -c ./coremark/core_main.c \
  $Flags -DFLAGS_STR="\"$Flags\"" \
  -o ./build/core_main.o
riscv32-unknown-elf-gcc $Includes -c ./coremark/core_matrix.c \
  $Flags \
  -o ./build/core_matrix.o
riscv32-unknown-elf-gcc $Includes -c ./coremark/core_state.c \
  $Flags -DFLAGS_STR="\"$Flags\"" \
  -o ./build/core_state.o
riscv32-unknown-elf-gcc $Includes -c ./coremark/core_util.c \
  $Flags -DFLAGS_STR="\"$Flags\"" \
  -o ./build/core_util.o
riscv32-unknown-elf-gcc $Includes -c ./coremark/barebones/core_portme.c \
  $Flags -DFLAGS_STR="\"$Flags\"" \
  -o ./build/core_portme.o
riscv32-unknown-elf-gcc -c syscalls.c \
  $Flags -DFLAGS_STR="\"$Flags\"" \
  -o ./build/syscalls.o
riscv32-unknown-elf-gcc \
  ./build/start.o ./build/core_list_join.o ./build/core_main.o \
  ./build/core_matrix.o ./build/core_state.o ./build/core_util.o \
  ./build/core_portme.o ./build/syscalls.o \
  -T linker.ld \
  -ffreestanding \
  -nostartfiles \
  -Wl,-Map=output.map,--gc-sections \
  -march=rv32i -mabi=ilp32 \
  -o ./build/firmware.elf


#riscv32-unknown-elf-objdump -h ./build/firmware.elf
riscv32-unknown-elf-objdump -d ./build/firmware.elf
#riscv32-unknown-elf-readelf -a ./build/firmware.elf
#riscv32-unknown-elf-size ./build/firmware.elf
riscv32-unknown-elf-objcopy -O binary ./build/firmware.elf ./build/firmware.bin

xxd -p -c1 ./build/firmware.bin | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/' > ./build/firmware.hex
xxd -p -c4 ./build/firmware.bin | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/' > ./build/firmware1.hex