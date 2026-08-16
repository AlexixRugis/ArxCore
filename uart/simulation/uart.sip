set_global_assignment -entity "uart" -library "lib_uart" -name IP_TOOL_NAME "Qsys"
set_global_assignment -entity "uart" -library "lib_uart" -name IP_TOOL_VERSION "25.1"
set_global_assignment -entity "uart" -library "lib_uart" -name IP_TOOL_ENV "Qsys"
set_global_assignment -library "lib_uart" -name SPD_FILE [file join $::quartus(sip_path) "../uart.spd"]
set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "../../uart.qsys"]

set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "uart.v"]
set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_reset_controller.v"]
set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_reset_synchronizer.v"]
set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_reset_controller.sdc"]
set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_up_rs232_counters.v"]
set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_up_rs232_in_deserializer.v"]
set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_up_rs232_out_serializer.v"]
set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "submodules/altera_up_sync_fifo.v"]
set_global_assignment -library "lib_uart" -name MISC_FILE [file join $::quartus(sip_path) "submodules/uart_rs232_0.v"]
