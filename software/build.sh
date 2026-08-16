riscv32-unknown-elf-gcc -c start.S \
  -march=rv32i -mabi=ilp32 \
  -o ./build/start.o
riscv32-unknown-elf-gcc -c main.c \
  -march=rv32im -mabi=ilp32 -ffreestanding -O0 \
  -o ./build/main.o
riscv32-unknown-elf-gcc -c syscalls.c \
  -march=rv32i -mabi=ilp32 \
  -ffreestanding \
  -o ./build/syscalls.o
riscv32-unknown-elf-gcc \
  ./build/start.o ./build/main.o ./build/syscalls.o \
  -T linker.ld \
  -ffreestanding \
  -nostartfiles \
  -Wl,-Map=output.map,--gc-sections \
  -march=rv32im -mabi=ilp32 \
  -o ./build/firmware.elf
#riscv32-unknown-elf-objdump -h ./build/firmware.elf
riscv32-unknown-elf-objdump -d ./build/firmware.elf
#riscv32-unknown-elf-readelf -a ./build/firmware.elf
#riscv32-unknown-elf-size ./build/firmware.elf
riscv32-unknown-elf-objcopy -O binary ./build/firmware.elf ./build/firmware.bin

xxd -p -c1 ./build/firmware.bin | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/' > ./build/firmware.hex
xxd -p -c4 ./build/firmware.bin | sed 's/\(..\)\(..\)\(..\)\(..\)/\4\3\2\1/' > ./build/firmware1.hex
