vlib work
vlog -hazards -lint -sv -work work \
../../src/Timer.sv \
../../src/Peripherals.sv \
../../src/RomPort.sv \
../../src/RamPort.sv \
../../src/RamArbiter2to1.sv \
../../src/MemoryInterconnect.sv \
../src/include/LoadStoreTypes.sv \
../src/include/BranchTypes.sv \
../src/include/IALUTypes.sv \
../src/ExecStage.sv \
../src/IALU.sv \
../src/IMUL.sv \
../src/IDIV.sv \
../src/IMDU.sv \
../src/InsnDecoder.sv \
../src/InsnDecodeStage.sv \
../src/InsnFetch.sv \
../src/LoadStoreUnit.sv \
../src/MemStage.sv \
../src/RegisterFile.sv \
../src/WriteBackStage.sv \
../src/ArxCore.sv \
./ArxCore_tb.sv
vsim -voptargs=+acc -L work ArxCore_tb
add wave -r /IMDU_tb/*       

vcd file ArxCore_tb.vcd
vcd add -r /ArxCore_tb/*

run -all
quit