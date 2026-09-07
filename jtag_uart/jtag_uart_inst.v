	jtag_uart u0 (
		.bridge_address     (<connected-to-bridge_address>),     // bridge.address
		.bridge_byte_enable (<connected-to-bridge_byte_enable>), //       .byte_enable
		.bridge_read        (<connected-to-bridge_read>),        //       .read
		.bridge_write       (<connected-to-bridge_write>),       //       .write
		.bridge_write_data  (<connected-to-bridge_write_data>),  //       .write_data
		.bridge_acknowledge (<connected-to-bridge_acknowledge>), //       .acknowledge
		.bridge_read_data   (<connected-to-bridge_read_data>),   //       .read_data
		.clk_clk            (<connected-to-clk_clk>),            //    clk.clk
		.reset_reset_n      (<connected-to-reset_reset_n>),      //  reset.reset_n
		.pio_export         (<connected-to-pio_export>)          //    pio.export
	);

