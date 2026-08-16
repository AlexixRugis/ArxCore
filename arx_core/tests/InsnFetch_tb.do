vlib work
vlog -sv -work work ../src/InsnFetch.sv ./InsnFetch_tb.sv
vsim -voptargs=+acc -L work InsnFetch_tb
add wave -r /IMDU_tb/*       

vcd file InsnFetch_tb.vcd
vcd add -r /InsnFetch_tb/*

run -all
quit