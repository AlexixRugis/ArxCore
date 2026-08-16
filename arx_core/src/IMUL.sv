module IMUL 
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

logic                                   handshake_in;
logic                                   handshake_out;
assign handshake_in = valid_in & ready_in;
assign handshake_out = valid_out & ready_out;

logic                                   sign_arg_1;
logic                                   sign_arg_2;
logic                                   msb_arg_1;
logic                                   msb_arg_2;

logic signed [XLEN:0]                   mul_op_a;
logic signed [XLEN:0]                   mul_op_b;
logic signed [2*XLEN+1:0]               mul_result_wide;
logic        [XLEN-1:0]                 mul_result;

assign sign_arg_1 = arg_1_in[XLEN-1];
assign sign_arg_2 = arg_2_in[XLEN-1];

always_comb begin
    case (opcode_in)
    IMDU_MUL, IMDU_MULH: begin
        msb_arg_1 = sign_arg_1;
        msb_arg_2 = sign_arg_2;
    end
    IMDU_MULHU: begin
        msb_arg_1 = 1'b0;
        msb_arg_2 = 1'b0;
    end
    IMDU_MULHSU:begin
        msb_arg_1 = sign_arg_1;
        msb_arg_2 = 1'b0;
    end
    default: begin
        msb_arg_1 = 1'b0;
        msb_arg_2 = 1'b0;
    end
    endcase
end

assign mul_op_a = { msb_arg_1, arg_1_in };
assign mul_op_b = { msb_arg_2, arg_2_in };

assign mul_result_wide = mul_op_a * mul_op_b;

always_comb begin
    case(opcode_in)
    IMDU_MUL: begin
        mul_result = mul_result_wide[XLEN-1:0];
    end
    IMDU_MULH,
    IMDU_MULHU,
    IMDU_MULHSU: begin
        mul_result = mul_result_wide[2*XLEN-1:XLEN];
    end
    default: begin
        mul_result = mul_result_wide[XLEN-1:0];
    end
    endcase
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        valid_out <= 1'b0;
        res_out <= '0;
    end
    else begin
        if (handshake_in) begin
            valid_out <= 1'b1;
            res_out <= mul_result;
        end
        else if (handshake_out) begin
            valid_out <= 1'b0;
        end
    end
end

assign ready_in = ~valid_out | ready_out;

endmodule