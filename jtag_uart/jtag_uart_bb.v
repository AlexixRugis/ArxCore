
module jtag_uart (
	bridge_address,
	bridge_byte_enable,
	bridge_read,
	bridge_write,
	bridge_write_data,
	bridge_acknowledge,
	bridge_read_data,
	clk_clk,
	reset_reset_n,
	pio_export);	

	input	[29:0]	bridge_address;
	input	[3:0]	bridge_byte_enable;
	input		bridge_read;
	input		bridge_write;
	input	[31:0]	bridge_write_data;
	output		bridge_acknowledge;
	output	[31:0]	bridge_read_data;
	input		clk_clk;
	input		reset_reset_n;
	output	[7:0]	pio_export;
endmodule
