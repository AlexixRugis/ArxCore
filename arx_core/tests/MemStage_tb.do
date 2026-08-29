vlib work
vlog -sv -work work ../src/include/LoadStoreTypes.sv ../src/LoadStoreUnit.sv ../src/MemStage.sv ./MemStage_tb.sv
vsim -voptargs=+acc -L work MemStage_tb
add wave -r /MemStage_tb/*       

vcd file MemStage_tb.vcd
vcd add -r /MemStage_tb/*

run -all
quit