module MemStage 
    import LoadStoreTypes::*;
#(
    parameter XLEN = 32,
    parameter ADDR_WIDTH = 32
) (
    input   logic                       clk,
    input   logic                       arstn,

// HALT REQ
    input   logic                       halt_req_in,
    output  logic                       halt_ack_out,
// -----------

// FROM EXEC STAGE
    input  logic                       valid_in,
    output logic                       ready_in,

    input   logic [XLEN-1:0]            alu_in,
    input   logic [XLEN-1:0]            rs2_in,
    input   logic [4:0]                 rd_in,

    input   logic [ADDR_WIDTH-1:0]      pc_in,

    input   logic                       reg_write_in,
    input   logic                       mem_to_reg_in,
    input   logic                       mem_op_in,
    input   ls_type_t                   mem_op_type_in,

// -----------

// TO WRITE BACK STAGE
    output  logic                       valid_out,
    input   logic                       ready_out,

    output  logic                       reg_write_out,
    output  logic                       mem_to_reg_out,

    output  logic [XLEN-1:0]            alu_res_out,
    output  logic [XLEN-1:0]            mem_val_out,

    output  logic [4:0]                 rd_out,
    output  logic [ADDR_WIDTH-1:0]      pc_out,
// -----------

// TO DATA MEM
    output  logic                       mem_req_out,
    input   logic                       mem_ack_in,

    output  logic [ADDR_WIDTH-1:0]      mem_addr_out,
    output  logic [XLEN-1:0]            mem_write_data_out,
    output  logic                       mem_write_en_out,
    output  logic [3:0]                 mem_write_mask_out,
    input   logic [XLEN-1:0]            mem_data_in
// -----------
);

// LOAD STORE UNIT

// TO CPU
logic                       cpu_req;
logic                       cpu_ack;

logic [ADDR_WIDTH-1:0]      cpu_addr;
ls_type_t                   cpu_mem_op_type;
logic [XLEN-1:0]            cpu_write_data;
logic [XLEN-1:0]            cpu_read_data;
// -----------

LoadStoreUnit #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .XLEN(XLEN)
) lsu (
    .clk(clk),
    .arstn(arstn),

    .cpu_req_in(cpu_req),
    .cpu_ack_out(cpu_ack),

    .cpu_addr_in(cpu_addr),
    .cpu_mem_op_type_in(cpu_mem_op_type),
    .cpu_write_data_in(cpu_write_data),
    .cpu_read_data_out(cpu_read_data),

    .mem_req_out(mem_req_out),
    .mem_ack_in(mem_ack_in),

    .mem_addr_out(mem_addr_out),
    .mem_write_data_out(mem_write_data_out),
    .mem_write_en_out(mem_write_en_out),
    .mem_write_mask_out(mem_write_mask_out),
    .mem_data_in(mem_data_in)
);

// -----------

// STAGE REGISTERS

logic                                   valid_in_internal;

logic [ADDR_WIDTH-1:0]                  pc_in_internal;

logic [XLEN-1:0]                        alu_in_internal;
logic [XLEN-1:0]                        rs2_in_internal;
logic [4:0]                             rd_in_internal;

logic                                   reg_write_in_internal;
logic                                   mem_to_reg_in_internal;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        valid_in_internal <= 1'b0;
    end
    else begin
        if (valid_in & ready_in) begin
            valid_in_internal <= 1'b1;
            
            pc_in_internal <= pc_in;

            alu_in_internal <= alu_in;
            rs2_in_internal <= rs2_in;
            rd_in_internal <= rd_in;

            reg_write_in_internal <= reg_write_in;
            mem_to_reg_in_internal <= mem_to_reg_in;
        end
        else if (valid_out & ready_out) begin
            valid_in_internal <= 1'b0;
        end
    end
end

// -----------

// MEM CONTROL

logic                                   mem_data_valid;
logic [XLEN-1:0]                        mem_data_internal;
logic                                   mem_request;
ls_type_t                               mem_op_type_in_internal;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        mem_data_valid <= 1'b0;
        mem_data_internal <= '0;
        mem_request <= 1'b0;
    end
    else begin
        if (valid_in & ready_in) begin
            mem_data_valid <= ~mem_op_in;
            mem_request <= mem_op_in;
            mem_op_type_in_internal <= mem_op_type_in;
        end

        if (mem_request & cpu_ack) begin
            mem_data_valid <= 1'b1;
            mem_data_internal <= cpu_read_data;
            mem_request <= 1'b0;
        end
    end
end

always_comb begin
    cpu_req = mem_request & ~cpu_ack;
    cpu_addr = alu_in_internal;
    cpu_write_data = rs2_in_internal;
    cpu_mem_op_type = mem_op_type_in_internal;
end

// -----------

// OUT ASSIGNMENTS

always_comb begin
    halt_ack_out = halt_req_in & (mem_data_valid | ~valid_in_internal);

    reg_write_out = reg_write_in_internal;
    mem_to_reg_out = mem_to_reg_in_internal;
    alu_res_out = alu_in_internal;
    mem_val_out = mem_data_internal;
    rd_out = rd_in_internal;
    pc_out = pc_in_internal;
end

always_comb begin
    if (~halt_req_in) begin
        valid_out = valid_in_internal & mem_data_valid;
        ready_in = ~valid_in_internal | (valid_out & ready_out);
    end
    else begin
        valid_out = 1'b0;
        ready_in = 1'b0;
    end
end

// -----------

endmodule