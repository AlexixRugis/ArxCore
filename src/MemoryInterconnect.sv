module MemoryInterconnect(
    input   logic           clk,
    input   logic           arstn,
    input   logic           clk_en,

    input   logic [31:0]    master1_addr,
    input   logic [31:0]    master1_write_data,
    input   logic           master1_wr_en,
    input   logic [3:0]     master1_wr_mask,
    input   logic           master1_req,
    output  logic [31:0]    master1_data,
    output  logic           master1_ack,

    input   logic [31:0]    master2_addr,
    input   logic [31:0]    master2_write_data,
    input   logic           master2_wr_en,
    input   logic [3:0]     master2_wr_mask,
    input   logic           master2_req,
    output  logic [31:0]    master2_data,
    output  logic           master2_ack,

    output  logic [31:0]    rom_addr,
    input   logic [31:0]    rom_data,

    output  logic [31:0]    ram_addr,
    output  logic [31:0]    ram_write_data,
    output  logic           ram_wr_en,
    output  logic [3:0]     ram_wr_mask,
    input   logic [31:0]    ram_data,

    output  logic [31:0]    periph_addr,
    output  logic [31:0]    periph_write_data,
    output  logic           periph_wr_en,
    output  logic [3:0]     periph_wr_mask,
    input   logic [31:0]    periph_data
);

localparam logic [31:0] ROM_ADDR_MASK       = 32'b1110_0000_0000_0000_0000_0000_0000_0000;
localparam logic [31:0] ROM_ADDR            = 32'b0000_0000_0000_0000_0000_0000_0000_0000;

localparam logic [31:0] RAM_ADDR_MASK       = 32'b1110_0000_0000_0000_0000_0000_0000_0000;
localparam logic [31:0] RAM_ADDR            = 32'b0010_0000_0000_0000_0000_0000_0000_0000;

localparam logic [31:0] PERIPH_ADDR_MASK    = 32'b1110_0000_0000_0000_0000_0000_0000_0000;
localparam logic [31:0] PERIPH_ADDR         = 32'b0100_0000_0000_0000_0000_0000_0000_0000;

logic               master1_rom_req;
assign master1_rom_req = ((ROM_ADDR_MASK & master1_addr) == ROM_ADDR) & master1_req;
logic               master1_ram_req;
assign master1_ram_req = ((RAM_ADDR_MASK & master1_addr) == RAM_ADDR) & master1_req;
logic               master1_periph_req;
assign master1_periph_req = ((PERIPH_ADDR_MASK & master1_addr) == PERIPH_ADDR) & master1_req;
logic               master1_bad_req;
assign master1_bad_req = master1_req 
                        & ((RAM_ADDR_MASK & master1_addr) != RAM_ADDR) 
                        & ((ROM_ADDR_MASK & master1_addr) != ROM_ADDR)
                        & ((PERIPH_ADDR_MASK & master1_addr) != PERIPH_ADDR);

logic               master2_rom_req;
assign master2_rom_req = ((ROM_ADDR_MASK & master2_addr) == ROM_ADDR) & master2_req;
logic               master2_ram_req;
assign master2_ram_req = ((RAM_ADDR_MASK & master2_addr) == RAM_ADDR) & master2_req;
logic               master2_periph_req;
assign master2_periph_req = ((PERIPH_ADDR_MASK & master2_addr) == PERIPH_ADDR) & master2_req;
logic               master2_bad_req;
assign master2_bad_req = master2_req 
                        & ((RAM_ADDR_MASK & master2_addr) != RAM_ADDR)
                        & ((ROM_ADDR_MASK & master2_addr) != ROM_ADDR)
                        & ((PERIPH_ADDR_MASK & master2_addr) != PERIPH_ADDR);

logic [31:0]        rom_arb_master1_data;
logic               rom_arb_master1_ack;
logic [31:0]        rom_arb_master2_data;
logic               rom_arb_master2_ack;

logic [31:0]        rom_arb_addr;
logic [31:0]        rom_arb_data;
logic               rom_arb_req;
logic               rom_arb_ack;

RomPort rom_port_inst(.clk(clk), .arstn(arstn), .clk_en(clk_en),
    .addr(rom_arb_addr), .req(rom_arb_req), .data(rom_arb_data), .ack(rom_arb_ack), 
    .rom_addr(rom_addr), .rom_data(rom_data));

RamArbiter2to1 rom_arbiter(.clk(clk), .arstn(arstn), .clk_en(clk_en),
    .master1_addr(master1_addr & ~ROM_ADDR_MASK),
    .master1_write_data('0), .master1_wr_en(1'b0), .master1_wr_mask(4'b0000),
    .master1_req(master1_rom_req), .master1_data(rom_arb_master1_data), .master1_ack(rom_arb_master1_ack),
    .master2_addr(master2_addr & ~ROM_ADDR_MASK),
    .master2_write_data('0), .master2_wr_en(1'b0), .master2_wr_mask(4'b0000),
    .master2_req(master2_rom_req), .master2_data(rom_arb_master2_data), .master2_ack(rom_arb_master2_ack),
    .slave_addr(rom_arb_addr), .slave_req(rom_arb_req), .slave_ack(rom_arb_ack), .slave_data(rom_arb_data));

logic [31:0]        ram_arb_master1_data;
logic               ram_arb_master1_ack;
logic [31:0]        ram_arb_master2_data;
logic               ram_arb_master2_ack;

logic [31:0]        ram_arb_addr;
logic [31:0]        ram_arb_data;
logic [31:0]        ram_arb_write_data;
logic [3:0]         ram_arb_wr_mask;
logic               ram_arb_wr_en;
logic               ram_arb_req;
logic               ram_arb_ack;

RamPort ram_port_inst(.clk(clk), .arstn(arstn), .clk_en(clk_en),
    .addr(ram_arb_addr), .write_data(ram_arb_write_data), .wr_en(ram_arb_wr_en), .wr_mask(ram_arb_wr_mask),
    .req(ram_arb_req), .data(ram_arb_data), .ack(ram_arb_ack),
    .ram_addr(ram_addr), .ram_write_data(ram_write_data), .ram_wr_en(ram_wr_en), .ram_byte_en(ram_wr_mask), .ram_data(ram_data));

RamArbiter2to1 ram_arbiter(.clk(clk), .arstn(arstn), .clk_en(clk_en),
    .master1_addr(master1_addr & ~RAM_ADDR_MASK),
    .master1_write_data(master1_write_data), .master1_wr_en(master1_wr_en), .master1_wr_mask(master1_wr_mask),
    .master1_req(master1_ram_req), .master1_data(ram_arb_master1_data), .master1_ack(ram_arb_master1_ack),
    .master2_addr(master2_addr & ~RAM_ADDR_MASK),
    .master2_write_data(master2_write_data), .master2_wr_en(master2_wr_en), .master2_wr_mask(master2_wr_mask),
    .master2_req(master2_ram_req), .master2_data(ram_arb_master2_data), .master2_ack(ram_arb_master2_ack),
    .slave_addr(ram_arb_addr), .slave_req(ram_arb_req), .slave_ack(ram_arb_ack), .slave_data(ram_arb_data),
    .slave_wr_en(ram_arb_wr_en), .slave_wr_mask(ram_arb_wr_mask), .slave_write_data(ram_arb_write_data));

logic [31:0]        periph_arb_master1_data;
logic               periph_arb_master1_ack;
logic [31:0]        periph_arb_master2_data;
logic               periph_arb_master2_ack;

logic [31:0]        periph_arb_addr;
logic [31:0]        periph_arb_data;
logic [31:0]        periph_arb_write_data;
logic [3:0]         periph_arb_wr_mask;
logic               periph_arb_wr_en;
logic               periph_arb_req;
logic               periph_arb_ack;

RamPort periph_port_inst(.clk(clk), .arstn(arstn), .clk_en(clk_en),
    .addr(periph_arb_addr), .write_data(periph_arb_write_data), .wr_en(periph_arb_wr_en), .wr_mask(periph_arb_wr_mask),
    .req(periph_arb_req), .data(periph_arb_data), .ack(periph_arb_ack),
    .ram_addr(periph_addr), .ram_write_data(periph_write_data), .ram_wr_en(periph_wr_en), .ram_byte_en(periph_wr_mask), .ram_data(periph_data));

RamArbiter2to1 periph_arbiter(.clk(clk), .arstn(arstn), .clk_en(clk_en),
    .master1_addr(master1_addr & ~PERIPH_ADDR_MASK),
    .master1_write_data(master1_write_data), .master1_wr_en(master1_wr_en), .master1_wr_mask(master1_wr_mask),
    .master1_req(master1_periph_req), .master1_data(periph_arb_master1_data), .master1_ack(periph_arb_master1_ack),
    .master2_addr(master2_addr & ~PERIPH_ADDR_MASK),
    .master2_write_data(master2_write_data), .master2_wr_en(master2_wr_en), .master2_wr_mask(master2_wr_mask),
    .master2_req(master2_periph_req), .master2_data(periph_arb_master2_data), .master2_ack(periph_arb_master2_ack),
    .slave_addr(periph_arb_addr), .slave_req(periph_arb_req), .slave_ack(periph_arb_ack), .slave_data(periph_arb_data),
    .slave_wr_en(periph_arb_wr_en), .slave_wr_mask(periph_arb_wr_mask), .slave_write_data(periph_arb_write_data));

logic               master1_rom_req_delay;
logic               master1_ram_req_delay;
logic               master1_periph_req_delay;
logic               master1_bad_req_delay;
logic               master2_rom_req_delay;
logic               master2_ram_req_delay;
logic               master2_periph_req_delay;
logic               master2_bad_req_delay;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        master1_rom_req_delay <= 1'b0;
        master1_ram_req_delay <= 1'b0;
        master1_periph_req_delay <= 1'b0;
        master1_bad_req_delay <= 1'b0;
        master2_rom_req_delay <= 1'b0;
        master2_ram_req_delay <= 1'b0;
        master2_periph_req_delay <= 1'b0;
        master2_bad_req_delay <= 1'b0;
    end
    else begin
        master1_rom_req_delay <= master1_rom_req;
        master1_ram_req_delay <= master1_ram_req;
        master1_periph_req_delay <= master1_periph_req;
        master1_bad_req_delay <= master1_bad_req;
        master2_rom_req_delay <= master2_rom_req;
        master2_ram_req_delay <= master2_ram_req;
        master2_periph_req_delay <= master2_periph_req;
        master2_bad_req_delay <= master2_bad_req;
    end
end

always_comb begin
     master1_data = '0;
     master1_ack = '0;
     master2_data = '0;
     master2_ack = '0;

     if (master1_rom_req_delay) begin
        master1_data = rom_arb_master1_data;
        master1_ack = rom_arb_master1_ack;
     end
     else if (master1_ram_req_delay) begin
        master1_data = ram_arb_master1_data;
        master1_ack = ram_arb_master1_ack;
     end
     else if (master1_periph_req_delay) begin
        master1_data = periph_arb_master1_data;
        master1_ack = periph_arb_master1_ack;
     end
     else if (master1_bad_req_delay) begin
        master1_data = '1;
        master1_ack = 1'b1;
     end

     if (master2_rom_req_delay) begin
        master2_data = rom_arb_master2_data;
        master2_ack = rom_arb_master2_ack;
     end
     else if (master2_ram_req_delay) begin
        master2_data = ram_arb_master2_data;
        master2_ack = ram_arb_master2_ack;
     end
     else if (master2_periph_req_delay) begin
        master2_data = periph_arb_master2_data;
        master2_ack = periph_arb_master2_ack;
     end
     else if (master2_bad_req_delay) begin
        master2_data = '1;
        master2_ack = 1'b1;
     end
end

endmodule