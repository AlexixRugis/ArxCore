vlib work
vlog -sv -work work ../src/include/LoadStoreTypes.sv ../src/include/BranchTypes.sv ../src/include/IALUTypes.sv ../src/RegisterFile.sv ../src/InsnDecoder.sv ../src/InsnDecodeStage.sv ./DecodeStage_tb.sv
vsim -voptargs=+acc -L work DecodeStage_tb
add wave -r /IMDU_tb/*       

vcd file DecodeStage_tb.vcd
vcd add -r /DecodeStage_tb/*

run -all
quit