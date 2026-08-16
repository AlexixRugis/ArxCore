module WriteBackStage #(
    parameter XLEN = 32,
    parameter ADDR_WIDTH = 32
) (
    input   logic                       clk,
    input   logic                       arstn,

// FROM MEM STAGE
    input   logic                       valid_in,
    output  logic                       ready_in,

    input   logic                       reg_write_in,
    input   logic                       mem_to_reg_in,

    input   logic [XLEN-1:0]            alu_res_in,
    input   logic [XLEN-1:0]            mem_val_in,

    input   logic [4:0]                 rd_in,
    input   logic [ADDR_WIDTH-1:0]      pc_in,

// -----------

// TO REG FILE
    output  logic                       reg_write_out,
    output  logic [4:0]                 rd_out,
    output  logic [XLEN-1:0]            res_out,

// -----------
    output  logic [ADDR_WIDTH-1:0]      pc_out
);

// STAGE REGISTERS

logic                                   valid_in_internal;
logic                                   reg_write_in_internal;
logic                                   mem_to_reg_in_internal;
logic [XLEN-1:0]                        alu_res_in_internal;
logic [XLEN-1:0]                        mem_val_in_internal;
logic [4:0]                             rd_in_internal;
logic [ADDR_WIDTH-1:0]                  pc_in_internal;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        valid_in_internal <= 1'b0;
    end
    else begin
        if (valid_in) begin
            valid_in_internal <= 1'b1;
            reg_write_in_internal <= reg_write_in;
            mem_to_reg_in_internal <= mem_to_reg_in;
            alu_res_in_internal <= alu_res_in;
            mem_val_in_internal <= mem_val_in;
            rd_in_internal <= rd_in;
            pc_in_internal <= pc_in;
        end
        else begin
            valid_in_internal <= 1'b0;
        end
    end
end

// -----------

// OUT ASSIGNMENTS

always_comb begin
    pc_out = pc_in_internal;

    if (valid_in_internal) begin
        reg_write_out = reg_write_in_internal;
        rd_out = rd_in_internal;
        res_out = mem_to_reg_in_internal ? mem_val_in_internal : alu_res_in_internal;
    end
    else begin
        reg_write_out = 1'b0;
        rd_out = '0;
        res_out = '0;
    end
end

assign ready_in = 1'b1;

// -----------

endmodule
