module IDIV 
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

logic [XLEN-1:0]                        abs_arg_1;
logic [XLEN-1:0]                        abs_arg_2;

logic                                   sign_arg_1;
logic                                   sign_arg_2;
logic                                   sign_res;
logic                                   sign_res_reg;

always_comb begin
    case(opcode_in)
    IMDU_DIVU, IMDU_REMU: begin
        sign_arg_1 = 1'b0;
        sign_arg_2 = 1'b0;
    end
    IMDU_DIV, IMDU_REM: begin
        sign_arg_1 = arg_1_in[XLEN-1];
        sign_arg_2 = arg_2_in[XLEN-1];
        
    end
    default: begin
        sign_arg_1 = 1'b0;
        sign_arg_2 = 1'b0;
    end
    endcase
end

always_comb begin
    case(opcode_in)
    IMDU_DIV: begin
        sign_res = arg_1_in[XLEN-1] ^ arg_2_in[XLEN-1];
    end
    IMDU_REM: begin
        sign_res = arg_1_in[XLEN-1];
    end
    IMDU_DIVU, IMDU_REMU: begin
        sign_res = 1'b0;
    end
    default: begin
        sign_res = 1'b0;
    end
    endcase
end

assign abs_arg_1 = sign_arg_1 ? -arg_1_in : arg_1_in;
assign abs_arg_2 = sign_arg_2 ? -arg_2_in : arg_2_in;

logic                                   is_res_quotient;
logic                                   is_res_quotient_reg;

always_comb begin
    case (opcode_in)
    IMDU_DIV, IMDU_DIVU: begin
        is_res_quotient = 1'b1;
    end
    IMDU_REM, IMDU_REMU: begin
        is_res_quotient = 1'b0;
    end
    default: begin
        is_res_quotient = 1'b0;
    end
    endcase
end

logic [5:0]                             cnt;
logic [2*XLEN-1:0]                      dividend_wide;
logic [2*XLEN-1:0]                      divisor_wide;
logic [XLEN-1:0]                        quotient;
logic [XLEN-1:0]                        remainder;
assign remainder = dividend_wide[XLEN-1:0];

logic [XLEN-1:0]                        abs_result;
logic [XLEN-1:0]                        result;
assign abs_result = is_res_quotient_reg ? quotient : remainder;
assign result = sign_res_reg ? -abs_result : abs_result;

logic [2*XLEN-1:0]                      diff_wide;
assign diff_wide = dividend_wide - divisor_wide;

logic                                   busy;
assign busy = |cnt;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        cnt <= '0;
        valid_out <= 1'b0;
        res_out <= '0;
    end
    else begin
        if (handshake_in) begin
            cnt <= 6'd33;
            quotient <= '0;
            dividend_wide <= { {XLEN{1'b0}}, abs_arg_1 };
            divisor_wide <= { 1'b0, abs_arg_2, {XLEN-1{1'b0}} };
            sign_res_reg <= sign_res;
            is_res_quotient_reg <= is_res_quotient;
            valid_out <= 1'b0;
        end
        else if (handshake_out) begin
            valid_out <= 1'b0;
        end
        
        if (busy) begin
            cnt <= cnt - 1'b1;
            divisor_wide <= divisor_wide >> 1;
            if (diff_wide[2*XLEN-1]) begin
                quotient <= { quotient[XLEN-2:0], 1'b0 };
            end
            else begin
                dividend_wide <= diff_wide;
                quotient <= { quotient[XLEN-2:0], 1'b1 }; 
            end

            if (cnt == XLEN'(1)) begin
                valid_out <= 1'b1;
                res_out <= result;
            end
        end
    end
end

assign ready_in = ~busy & (~valid_out | ready_out);

endmodule