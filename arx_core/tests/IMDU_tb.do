vlib work
vlog -sv -work work ../src/include/IALUTypes.sv ../src/IMUL.sv ../src/IDIV.sv ../src/IMDU.sv ./IMDU_tb.sv
vsim -voptargs=+acc -L work IMDU_tb
add wave -r /IMDU_tb/*       

vcd file IMDU_tb.vcd
vcd add -r /IMDU_tb/*

run -all
quit