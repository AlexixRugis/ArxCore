`timescale 1ns/1ps

module IMDU_tb;
    import IALUTypes::*;
    
    parameter XLEN = 32;
    parameter CLK_PERIOD = 10;

    parameter TIMEOUT = 100000;
    initial begin
        #(TIMEOUT);
        $error("TIMEOUT");
        $stop();
    end
    
    logic                               clk;
    logic                               arstn;

// CLOCK AND RESET
    initial begin
        clk <= 1'b0;
        forever begin
            #(CLK_PERIOD/2) clk <= ~clk;
        end
    end

    initial begin
        arstn <= 1'b0;
        repeat(3) @(posedge clk);
        arstn <= 1'b1;
    end
    
// DUT
    logic                               valid_in;
    logic                               ready_in;
    
    logic [XLEN-1:0]                    arg_1_in;
    logic [XLEN-1:0]                    arg_2_in;
    MDU_op_t                            opcode_in;

    logic [XLEN-1:0]                    res_out;
    logic                               valid_out;
    logic                               ready_out;
    
    IMDU #(.XLEN(XLEN)) dut (.*);

parameter TRANSACTION_COUNT = 1000;

typedef struct packed {
    logic [XLEN-1:0] expected_res;
} in_data_t;

typedef struct packed {
    logic [XLEN-1:0] res;
} out_data_t;

mailbox #(in_data_t) mb_in = new();
mailbox #(out_data_t) mb_out = new();

task send_transaction(
    input logic [XLEN-1:0]              arg_1,
    input logic [XLEN-1:0]              arg_2,
    input MDU_op_t                     opcode,
    input logic [XLEN-1:0]              expected_output
);
    in_data_t in_data;

    in_data.expected_res = expected_output;
    
    @(posedge clk);
    valid_in <= 1'b1;
    
    arg_1_in <= arg_1;
    arg_2_in <= arg_2;
    opcode_in <= opcode;
    
    while (!(valid_in & ready_in)) begin
        @(posedge clk);
    end
    valid_in <= 1'b0;
    
    mb_in.put(in_data);
endtask

task read_output();
    out_data_t out_data;
    
    ready_out <= 1'b0;
    wait(arstn);
    
    for (int i = 0; i < TRANSACTION_COUNT; i++) begin
        
        repeat($urandom_range(0, 4)) @(posedge clk);

        ready_out <= 1'b1;

        do begin
            @(posedge clk);
        end
        while(~(valid_out & ready_out));

        ready_out <= 1'b0;

        out_data.res = res_out;

        mb_out.put(out_data);
    end
endtask

task check_output();
    in_data_t in_data;
    out_data_t out_data;
    
    for (int i = 0; i < TRANSACTION_COUNT; i++) begin
        mb_in.get(in_data);
        mb_out.get(out_data);

        if (in_data.expected_res !== out_data.res) begin
            $error("Res mismatch! Expected: %h, Actual: %h", in_data.expected_res, out_data.res);
        end
    end
endtask

// Helper function for multiplication operations
function logic [63:0] mul_64bit(input logic signed [31:0] a, input logic signed [31:0] b);
    return a * b;
endfunction

// Helper function for division and remainder
function logic [31:0] div_signed(input logic signed [31:0] a, input logic signed [31:0] b);
    if (b == 0)
        return 32'hFFFFFFFF; // Division by zero returns -1
    else if (a == 32'h80000000 && b == -1)
        return 32'h80000000; // Overflow case: -2^31 / -1 = -2^31
    else
        return a / b;
endfunction

function logic [31:0] div_unsigned(input logic [31:0] a, input logic [31:0] b);
    if (b == 0)
        return 32'hFFFFFFFF; // Division by zero returns -1
    else
        return a / b;
endfunction

function logic [31:0] rem_signed(input logic signed [31:0] a, input logic signed [31:0] b);
    if (b == 0)
        return a; // Remainder by zero returns dividend
    else if (a == 32'h80000000 && b == -1)
        return 0; // Overflow case: -2^31 % -1 = 0
    else
        return a % b;
endfunction

function logic [31:0] rem_unsigned(input logic [31:0] a, input logic [31:0] b);
    if (b == 0)
        return a; // Remainder by zero returns dividend
    else
        return a % b;
endfunction

initial begin
    logic signed [31:0] a, b;
    logic [31:0] a_unsigned, b_unsigned;
    logic [63:0] mul_result;
    logic [31:0] mulh_result, mulhsu_result, mulhu_result;

    valid_in <= 1'b0;
    ready_out <= 1'b0;
    arg_1_in <= '0;
    arg_2_in <= '0;
    
    wait(arstn);
    repeat(5) @(posedge clk);
    
    fork
        begin
            wait(arstn);

            // ==================== MUL TESTS ====================
            $display("Testing MUL operations...");
            // Basic positive multiplication
            send_transaction(2, 3, IMDU_MUL, 6);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Negative * Negative = Positive
            send_transaction(32'hFFFFFFFE, 32'hFFFFFFFD, IMDU_MUL, 6); // -2 * -3 = 6
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Negative * Positive = Negative
            send_transaction(32'hFFFFFFFE, 3, IMDU_MUL, 32'hFFFFFFFA); // -2 * 3 = -6
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Positive * Negative = Negative
            send_transaction(2, 32'hFFFFFFFD, IMDU_MUL, 32'hFFFFFFFA); // 2 * -3 = -6
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Edge cases: zero
            send_transaction(0, 5, IMDU_MUL, 0);
            repeat($urandom_range(0, 5)) @(posedge clk);
            send_transaction(5, 0, IMDU_MUL, 0);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Maximum values
            send_transaction(32'h7FFFFFFF, 1, IMDU_MUL, 32'h7FFFFFFF);
            repeat($urandom_range(0, 5)) @(posedge clk);
            send_transaction(32'h80000000, 1, IMDU_MUL, 32'h80000000);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // ==================== MULH TESTS ====================
            $display("Testing MULH operations (signed*signed high bits)...");
            // 2 * 3 = 6, high bits = 0
            send_transaction(2, 3, IMDU_MULH, 0);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Large numbers to get non-zero high bits
            send_transaction(32'h7FFFFFFF, 32'h7FFFFFFF, IMDU_MULH, 32'h3FFFFFFF);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Negative * Positive
            send_transaction(32'h80000000, 2, IMDU_MULH, 32'hFFFFFFFF);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // ==================== MULHSU TESTS ====================
            $display("Testing MULHSU operations (signed*unsigned high bits)...");
            // 2 * 3 = 6, high bits = 0
            send_transaction(2, 3, IMDU_MULHSU, 0);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Negative signed * large unsigned
            send_transaction(32'h80000000, 32'hFFFFFFFF, IMDU_MULHSU, 32'h80000000);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // ==================== MULHU TESTS ====================
            $display("Testing MULHU operations (unsigned*unsigned high bits)...");
            // 2 * 3 = 6, high bits = 0
            send_transaction(2, 3, IMDU_MULHU, 0);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Large unsigned numbers
            send_transaction(32'hFFFFFFFF, 32'hFFFFFFFF, IMDU_MULHU, 32'hFFFFFFFE);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // ==================== DIV TESTS ====================
            $display("Testing DIV operations (signed division)...");
            // Basic division
            send_transaction(10, 2, IMDU_DIV, 5);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Negative division
            send_transaction(-10, 2, IMDU_DIV, -5);
            repeat($urandom_range(0, 5)) @(posedge clk);
            send_transaction(10, -2, IMDU_DIV, -5);
            repeat($urandom_range(0, 5)) @(posedge clk);
            send_transaction(-10, -2, IMDU_DIV, 5);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Division by zero
            send_transaction(10, 0, IMDU_DIV, 32'hFFFFFFFF);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Overflow case: -2^31 / -1 = -2^31
            send_transaction(32'h80000000, 32'hFFFFFFFF, IMDU_DIV, 32'h80000000);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // ==================== DIVU TESTS ====================
            $display("Testing DIVU operations (unsigned division)...");
            // Basic unsigned division
            send_transaction(10, 2, IMDU_DIVU, 5);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Large numbers
            send_transaction(32'hFFFFFFFF, 1, IMDU_DIVU, 32'hFFFFFFFF);
            repeat($urandom_range(0, 5)) @(posedge clk);
            send_transaction(32'hFFFFFFFF, 32'hFFFFFFFF, IMDU_DIVU, 1);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Division by zero
            send_transaction(10, 0, IMDU_DIVU, 32'hFFFFFFFF);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // ==================== REM TESTS ====================
            $display("Testing REM operations (signed remainder)...");
            // Basic remainder
            send_transaction(10, 3, IMDU_REM, 1);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Negative remainders (sign follows dividend)
            send_transaction(-10, 3, IMDU_REM, -1);
            repeat($urandom_range(0, 5)) @(posedge clk);
            send_transaction(10, -3, IMDU_REM, 1);
            repeat($urandom_range(0, 5)) @(posedge clk);
            send_transaction(-10, -3, IMDU_REM, -1);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Remainder by zero returns dividend
            send_transaction(10, 0, IMDU_REM, 10);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Overflow case: -2^31 % -1 = 0
            send_transaction(32'h80000000, 32'hFFFFFFFF, IMDU_REM, 0);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // ==================== REMU TESTS ====================
            $display("Testing REMU operations (unsigned remainder)...");
            // Basic unsigned remainder
            send_transaction(10, 3, IMDU_REMU, 1);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Large numbers
            send_transaction(32'hFFFFFFFF, 2, IMDU_REMU, 1);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // Remainder by zero returns dividend
            send_transaction(10, 0, IMDU_REMU, 10);
            repeat($urandom_range(0, 5)) @(posedge clk);
            
            // ==================== RANDOMIZED TESTS ====================
            $display("Running randomized tests...");
            
            // Generate random test cases
            for (int i = 0; i < 50; i++) begin
                // Random multiplication tests
                a = $signed($urandom());
                b = $signed($urandom());
                mul_result = mul_64bit(a, b);
                send_transaction(a, b, IMDU_MUL, mul_result[31:0]);
                repeat($urandom_range(0, 3)) @(posedge clk);
                
                send_transaction(a, b, IMDU_MULH, mul_result[63:32]);
                repeat($urandom_range(0, 3)) @(posedge clk);
                
                // Random division/remainder tests (avoid division by zero)
                a = $signed($urandom());
                b = $signed($urandom());
                if (b != 0 && !(a == 32'h80000000 && b == -1)) begin
                    send_transaction(a, b, IMDU_DIV, div_signed(a, b));
                    repeat($urandom_range(0, 3)) @(posedge clk);
                    send_transaction(a, b, IMDU_REM, rem_signed(a, b));
                    repeat($urandom_range(0, 3)) @(posedge clk);
                end
                
                // Unsigned tests
                a_unsigned = $urandom();
                b_unsigned = $urandom();
                if (b_unsigned != 0) begin
                    send_transaction(a_unsigned, b_unsigned, IMDU_DIVU, div_unsigned(a_unsigned, b_unsigned));
                    repeat($urandom_range(0, 3)) @(posedge clk);
                    send_transaction(a_unsigned, b_unsigned, IMDU_REMU, rem_unsigned(a_unsigned, b_unsigned));
                    repeat($urandom_range(0, 3)) @(posedge clk);
                end
            end

            #100;
            $finish;
        end
        
        read_output();
        check_output();
    join
end
    
endmodule