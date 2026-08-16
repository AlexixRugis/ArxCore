transcript on
if ![file isdirectory DE1_SOC_golden_top_iputf_libs] {
	file mkdir DE1_SOC_golden_top_iputf_libs
}

if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

###### Libraries for IPUTF cores 
vlib DE1_SOC_golden_top_iputf_libs/rst_controller
vmap rst_controller ./DE1_SOC_golden_top_iputf_libs/rst_controller
vlib DE1_SOC_golden_top_iputf_libs/rs232_0
vmap rs232_0 ./DE1_SOC_golden_top_iputf_libs/rs232_0
###### End libraries for IPUTF cores 
###### MIF file copy and HDL compilation commands for IPUTF cores 


vlog "/home/alexix/Repos/FPGALearning/Calc2/uart/simulation/submodules/altera_reset_controller.v"         -work rst_controller
vlog "/home/alexix/Repos/FPGALearning/Calc2/uart/simulation/submodules/altera_reset_synchronizer.v"       -work rst_controller
vlog "/home/alexix/Repos/FPGALearning/Calc2/uart/simulation/submodules/altera_up_rs232_counters.v"        -work rs232_0       
vlog "/home/alexix/Repos/FPGALearning/Calc2/uart/simulation/submodules/altera_up_rs232_in_deserializer.v" -work rs232_0       
vlog "/home/alexix/Repos/FPGALearning/Calc2/uart/simulation/submodules/altera_up_rs232_out_serializer.v"  -work rs232_0       
vlog "/home/alexix/Repos/FPGALearning/Calc2/uart/simulation/submodules/altera_up_sync_fifo.v"             -work rs232_0       
vlog "/home/alexix/Repos/FPGALearning/Calc2/uart/simulation/submodules/uart_rs232_0.v"                    -work rs232_0       
vlog "/home/alexix/Repos/FPGALearning/Calc2/uart/simulation/uart.v"                                                           

vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2 {/home/alexix/Repos/FPGALearning/Calc2/DE1_SOC_golden_top.v}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2 {/home/alexix/Repos/FPGALearning/Calc2/ram.v}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2 {/home/alexix/Repos/FPGALearning/Calc2/rom.v}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/Timer.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/Peripherals.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/RamArbiter2to1.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/include {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/include/LoadStoreTypes.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/include {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/include/IALUTypes.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/include {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/include/BranchTypes.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/WriteBackStage.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/RegisterFile.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/InsnFetch.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/InsnDecoder.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule {/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule/ResetController.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/ValidReadyDelay.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule {/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule/DebugMemoryBridge.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule {/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule/PacketParser.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule {/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule/PacketBuffer.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule {/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule/DebugModule.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule {/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule/DebugMemoryCopier.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule {/home/alexix/Repos/FPGALearning/Calc2/src/DebugModule/ByteToWordAddrConverter.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/RamPort.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/SevenSegmentInd.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/mmio.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/RomPort.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/IMUL.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/IMDU.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/IDIV.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/MemoryInterconnect.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/MemStage.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/LoadStoreUnit.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/InsnDecodeStage.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/IALU.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/ExecStage.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/arx_core/src {/home/alexix/Repos/FPGALearning/Calc2/arx_core/src/ArxCore.sv}
vlog -sv -work work +incdir+/home/alexix/Repos/FPGALearning/Calc2/src {/home/alexix/Repos/FPGALearning/Calc2/src/top.sv}

