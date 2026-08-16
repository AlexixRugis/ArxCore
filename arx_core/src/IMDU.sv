module IMDU 
    import IALUTypes::*;
#(
    parameter XLEN = 32
) (
    input   logic                       clk,
    input   logic                       arstn,

    input   logic                       valid_in,
    output  logic                       ready_in,

    input   logic [XLEN-1:0]            arg_1_in,
    input   logic [XLEN-1:0]            arg_2_in,
    input   MDU_op_t                    opcode_in,

    output  logic [XLEN-1:0]            res_out,
    output  logic                       valid_out,
    input   logic                       ready_out
);

logic                                   mul_op;

always_comb begin
    case (opcode_in)
    IMDU_MUL, 
    IMDU_MULH, 
    IMDU_MULHU, 
    IMDU_MULHSU: begin
        mul_op = 1'b1;
    end
    IMDU_DIV, 
    IMDU_DIVU, 
    IMDU_REM, 
    IMDU_REMU: begin
        mul_op = 1'b0;
    end
    default: begin
        mul_op = 1'b0;
    end
    endcase
end

logic                                   mul_valid_in;
logic                                   mul_ready_in;
logic                                   mul_valid_out;
logic [XLEN-1:0]                        mul_res_out;

IMUL #(XLEN) mul_inst (
    .clk(clk),
    .arstn(arstn),

    .valid_in(mul_valid_in),
    .ready_in(mul_ready_in),

    .arg_1_in(arg_1_in),
    .arg_2_in(arg_2_in),
    .opcode_in(opcode_in),

    .res_out(mul_res_out),
    .valid_out(mul_valid_out),
    .ready_out(ready_out)
);

logic                                   div_valid_in;
logic                                   div_ready_in;
logic                                   div_valid_out;
logic [XLEN-1:0]                        div_res_out;

IDIV #(XLEN) div_inst (
    .clk(clk),
    .arstn(arstn),

    .valid_in(div_valid_in),
    .ready_in(div_ready_in),

    .arg_1_in(arg_1_in),
    .arg_2_in(arg_2_in),
    .opcode_in(opcode_in),

    .res_out(div_res_out),
    .valid_out(div_valid_out),
    .ready_out(ready_out)
);

assign mul_valid_in = valid_in & ready_in & mul_op;
assign div_valid_in = valid_in & ready_in & ~mul_op;

assign ready_in = mul_ready_in & div_ready_in;
assign valid_out = mul_valid_out | div_valid_out;

assign res_out = mul_valid_out ? mul_res_out :
                 (div_valid_out ? div_res_out : '0);

endmodule