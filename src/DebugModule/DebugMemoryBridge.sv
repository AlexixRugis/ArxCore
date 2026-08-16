module DebugMemoryBridge(
    input   logic [31:0]        debug_addr,
    input   logic [31:0]        debug_write_data,
    input   logic               debug_wr_en,
    input   logic [3:0]         debug_wr_mask,
    input   logic               debug_req,
    output  logic [31:0]        debug_data,
    output  logic               debug_ack,

    input   logic               mem_clk_en,
    output  logic [31:0]        mem_addr,
    output  logic [31:0]        mem_write_data,
    output  logic               mem_wr_en,
    output  logic [3:0]         mem_wr_mask,
    output  logic               mem_req,
    input   logic [31:0]        mem_data,
    input   logic               mem_ack
);

always_comb begin
    mem_addr = debug_addr;
    mem_write_data = debug_write_data;
    mem_wr_en = debug_wr_en;
    mem_wr_mask = debug_wr_mask;
    mem_req = debug_req;
    
    debug_data = mem_data;
    debug_ack = mem_clk_en & mem_ack;
end

endmodule