	component jtag_uart is
		port (
			bridge_address     : in  std_logic_vector(29 downto 0) := (others => 'X'); -- address
			bridge_byte_enable : in  std_logic_vector(3 downto 0)  := (others => 'X'); -- byte_enable
			bridge_read        : in  std_logic                     := 'X';             -- read
			bridge_write       : in  std_logic                     := 'X';             -- write
			bridge_write_data  : in  std_logic_vector(31 downto 0) := (others => 'X'); -- write_data
			bridge_acknowledge : out std_logic;                                        -- acknowledge
			bridge_read_data   : out std_logic_vector(31 downto 0);                    -- read_data
			clk_clk            : in  std_logic                     := 'X';             -- clk
			reset_reset_n      : in  std_logic                     := 'X';             -- reset_n
			pio_export         : out std_logic_vector(7 downto 0)                      -- export
		);
	end component jtag_uart;

	u0 : component jtag_uart
		port map (
			bridge_address     => CONNECTED_TO_bridge_address,     -- bridge.address
			bridge_byte_enable => CONNECTED_TO_bridge_byte_enable, --       .byte_enable
			bridge_read        => CONNECTED_TO_bridge_read,        --       .read
			bridge_write       => CONNECTED_TO_bridge_write,       --       .write
			bridge_write_data  => CONNECTED_TO_bridge_write_data,  --       .write_data
			bridge_acknowledge => CONNECTED_TO_bridge_acknowledge, --       .acknowledge
			bridge_read_data   => CONNECTED_TO_bridge_read_data,   --       .read_data
			clk_clk            => CONNECTED_TO_clk_clk,            --    clk.clk
			reset_reset_n      => CONNECTED_TO_reset_reset_n,      --  reset.reset_n
			pio_export         => CONNECTED_TO_pio_export          --    pio.export
		);

