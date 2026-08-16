`timescale 1ns/1ps

module IALU_tb;
    import IALUTypes::*;
    
    parameter XLEN = 32;
    
    logic [XLEN-1:0] arg_1, arg_2;
    ALU_op_t         opcode;
    logic [XLEN-1:0] res;
    logic            branch_en;
    
    IALU #(.XLEN(XLEN)) dut (
        .arg_1(arg_1),
        .arg_2(arg_2),
        .opcode(opcode),
        .res(res),
        .branch_en(branch_en)
    );
    
    task check_result(input string test_name, 
                      input logic [XLEN-1:0] expected_res,
                      input logic expected_branch);
        bit status;
        status = 1;
        if (res !== expected_res) begin
            $error("%s FAILED: expected res=%h, got %h", test_name, expected_res, res);
            status = 0;
        end
        if (branch_en !== expected_branch) begin
            $error("%s FAILED: expected branch_en=%b, got %b", test_name, expected_branch, branch_en);
            status = 0;
        end

        if (status === 1) begin
            $display("%s PASSED", test_name);
        end
    endtask
    
    initial begin
        $dumpvars;

        $display("Testing IALU Module");
        $display("===================\n");
        
        // Test ADD
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_ADD;
        #10;
        check_result("ADD", 32'h00000008, 1'b0);
        
        // Test SUB
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_SUB;
        #10;
        check_result("SUB", 32'h00000002, 1'b0);
        
        // Test AND
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_AND;
        #10;
        check_result("AND", 32'h00000001, 1'b0);
        
        // Test OR
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_OR;
        #10;
        check_result("OR", 32'h00000007, 1'b0);
        
        // Test XOR
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_XOR;
        #10;
        check_result("XOR", 32'h00000006, 1'b0);
        
        // Test SLL
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000002;
        opcode = IALU_SLL;
        #10;
        check_result("SLL", 32'h00000014, 1'b0);
        
        // Test SRL
        arg_1 = 32'h00000014;
        arg_2 = 32'h00000002;
        opcode = IALU_SRL;
        #10;
        check_result("SRL", 32'h00000005, 1'b0);
        
        // Test SRA (positive)
        arg_1 = 32'h00000014;
        arg_2 = 32'h00000002;
        opcode = IALU_SRA;
        #10;
        check_result("SRA positive", 32'h00000005, 1'b0);
        
        // Test SRA (negative)
        arg_1 = 32'hFFFFFFF0;  // -16
        arg_2 = 32'h00000002;
        opcode = IALU_SRA;
        #10;
        check_result("SRA negative", 32'hFFFFFFFC, 1'b0);  // -4
        
        // Test SLT (false)
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_SLT;
        #10;
        check_result("SLT false", 32'h00000000, 1'b0);

        arg_1 = 32'h00000003;
        arg_2 = 32'h00000003;
        opcode = IALU_SLT;
        #10;
        check_result("SLT false (equal)", 32'h00000000, 1'b0);
        
        // Test SLT (positive)
        arg_1 = 32'h00000003;
        arg_2 = 32'h00000005;
        opcode = IALU_SLT;
        #10;
        check_result("SLT true", 32'h00000001, 1'b0);
        
        // Test SLT with negative
        arg_1 = 32'hFFFFFFFF;  // -1
        arg_2 = 32'h00000001;  // 1
        opcode = IALU_SLT;
        #10;
        check_result("SLT negative < positive", 32'h00000001, 1'b0);

        arg_1 = 32'hFFFFFFFE;  // -2
        arg_2 = 32'hFFFFFFFE;  // -2
        opcode = IALU_SLT;
        #10;
        check_result("SLT true (eq negative)", 32'h00000000, 1'b0);
        
        // Test SLTU
        arg_1 = 32'hFFFFFFFF;  // -1 as unsigned = INT32_MAX
        arg_2 = 32'h00000001;
        opcode = IALU_SLTU;
        #10;
        check_result("SLTU false", 32'h00000000, 1'b0);

        arg_1 = 32'hFFFFFFFE; // -2
        arg_2 = 32'hFFFFFFFE;
        opcode = IALU_SLTU;
        #10;
        check_result("SLTU false (equal)", 32'h00000000, 1'b0);

        // Test SLTU
        arg_1 = 32'h00000001;  // -1 as unsigned = INT32_MAX
        arg_2 = 32'hFFFFFFFF;
        opcode = IALU_SLTU;
        #10;
        check_result("SLTU true", 32'h00000001, 1'b0);
        
        // Test EQ (branch)
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000005;
        opcode = IALU_EQ;
        #10;
        check_result("EQ true", 32'h00000005, 1'b1);
        
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_EQ;
        #10;
        check_result("EQ false", 32'h00000003, 1'b0);
        
        // Test NEQ
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_NEQ;
        #10;
        check_result("NEQ true", 32'h00000003, 1'b1);

        arg_1 = 32'h00000005;
        arg_2 = 32'h00000005;
        opcode = IALU_NEQ;
        #10;
        check_result("EQ true", 32'h00000005, 1'b0);
        
        // Test LT (signed less than)
        arg_1 = 32'h00000003;
        arg_2 = 32'h00000005;
        opcode = IALU_LT;
        #10;
        check_result("LT true (3 < 5)", 32'h00000005, 1'b1);

        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_LT;
        #10;
        check_result("LT false (5 < 3)", 32'h00000003, 1'b0);

        arg_1 = 32'h00000005;
        arg_2 = 32'h00000005;
        opcode = IALU_LT;
        #10;
        check_result("LT false (equal)", 32'h00000005, 1'b0);
        
        // Test LT with negative numbers
        arg_1 = 32'hFFFFFFFF;  // -1
        arg_2 = 32'h00000001;  // 1
        opcode = IALU_LT;
        #10;
        check_result("LT true (-1 < 1)", 32'h00000001, 1'b1);
        
        arg_1 = 32'h00000001;
        arg_2 = 32'hFFFFFFFF;  // -1
        opcode = IALU_LT;
        #10;
        check_result("LT false (1 < -1)", 32'hFFFFFFFF, 1'b0);
        
        arg_1 = 32'h80000000;  // -2147483648 (most negative)
        arg_2 = 32'h7FFFFFFF;  // 2147483647 (most positive)
        opcode = IALU_LT;
        #10;
        check_result("LT true (min < max)", 32'h7FFFFFFF, 1'b1);
        
        // Test GE (signed greater or equal)
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_GE;
        #10;
        check_result("GE true (5 >= 3)", 32'h00000003, 1'b1);

        arg_1 = 32'h00000003;
        arg_2 = 32'h00000005;
        opcode = IALU_GE;
        #10;
        check_result("GE false (3 >= 5)", 32'h00000005, 1'b0);

        arg_1 = 32'h00000003;
        arg_2 = 32'h00000003;
        opcode = IALU_GE;
        #10;
        check_result("GE true (equal)", 32'h00000003, 1'b1);
        
        // Test GE with negative numbers
        arg_1 = 32'h00000001;
        arg_2 = 32'hFFFFFFFF;  // -1
        opcode = IALU_GE;
        #10;
        check_result("GE true (1 >= -1)", 32'hFFFFFFFF, 1'b1);
        
        arg_1 = 32'hFFFFFFFF;  // -1
        arg_2 = 32'h00000001;
        opcode = IALU_GE;
        #10;
        check_result("GE false (-1 >= 1)", 32'h00000001, 1'b0);
        
        // Test LTU (unsigned less than)
        arg_1 = 32'h00000003;
        arg_2 = 32'h00000005;
        opcode = IALU_LTU;
        #10;
        check_result("LTU true (3 < 5)", 32'h00000005, 1'b1);

        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_LTU;
        #10;
        check_result("LTU false (5 < 3)", 32'h00000003, 1'b0);

        arg_1 = 32'h00000005;
        arg_2 = 32'h00000005;
        opcode = IALU_LTU;
        #10;
        check_result("LTU false (equal)", 32'h00000005, 1'b0);
        
        // Test LTU with large unsigned values
        arg_1 = 32'hFFFFFFFF;  // 4294967295
        arg_2 = 32'h00000005;
        opcode = IALU_LTU;
        #10;
        check_result("LTU false (max < 5)", 32'h00000005, 1'b0);
        
        arg_1 = 32'h00000005;
        arg_2 = 32'hFFFFFFFF;
        opcode = IALU_LTU;
        #10;
        check_result("LTU true (5 < max)", 32'hFFFFFFFF, 1'b1);
        
        arg_1 = 32'h80000000;  // 2147483648
        arg_2 = 32'h7FFFFFFF;  // 2147483647
        opcode = IALU_LTU;
        #10;
        check_result("LTU false (0x80000000 < 0x7FFFFFFF)", 32'h7FFFFFFF, 1'b0);
        
        arg_1 = 32'h7FFFFFFF;
        arg_2 = 32'h80000000;
        opcode = IALU_LTU;
        #10;
        check_result("LTU true (0x7FFFFFFF < 0x80000000)", 32'h80000000, 1'b1);
        
        // Test GEU (unsigned greater or equal)
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000003;
        opcode = IALU_GEU;
        #10;
        check_result("GEU true (5 >= 3)", 32'h00000003, 1'b1);

        arg_1 = 32'h00000003;
        arg_2 = 32'h00000005;
        opcode = IALU_GEU;
        #10;
        check_result("GEU false (3 >= 5)", 32'h00000005, 1'b0);

        arg_1 = 32'h00000003;
        arg_2 = 32'h00000003;
        opcode = IALU_GEU;
        #10;
        check_result("GEU true (equal)", 32'h00000003, 1'b1);
        
        // Test GEU with large unsigned values
        arg_1 = 32'hFFFFFFFF;
        arg_2 = 32'h00000005;
        opcode = IALU_GEU;
        #10;
        check_result("GEU true (max >= 5)", 32'h00000005, 1'b1);
        
        arg_1 = 32'h00000005;
        arg_2 = 32'hFFFFFFFF;
        opcode = IALU_GEU;
        #10;
        check_result("GEU false (5 >= max)", 32'hFFFFFFFF, 1'b0);
        
        arg_1 = 32'h80000000;
        arg_2 = 32'h7FFFFFFF;
        opcode = IALU_GEU;
        #10;
        check_result("GEU true (0x80000000 >= 0x7FFFFFFF)", 32'h7FFFFFFF, 1'b1);
        
        arg_1 = 32'h7FFFFFFF;
        arg_2 = 32'h80000000;
        opcode = IALU_GEU;
        #10;
        check_result("GEU false (0x7FFFFFFF >= 0x80000000)", 32'h80000000, 1'b0);
        
        // Test GEU with zero
        arg_1 = 32'h00000000;
        arg_2 = 32'h00000005;
        opcode = IALU_GEU;
        #10;
        check_result("GEU false (0 >= 5)", 32'h00000005, 1'b0);
        
        arg_1 = 32'h00000005;
        arg_2 = 32'h00000000;
        opcode = IALU_GEU;
        #10;
        check_result("GEU true (5 >= 0)", 32'h00000000, 1'b1);
        
        // Test IALU_ARG2
        arg_1 = 32'hDEADBEEF;
        arg_2 = 32'hCAFEBABE;
        opcode = IALU_ARG2;
        #10;
        check_result("ARG2", 32'hCAFEBABE, 1'b0);
        
        $display("\n===================");
        $display("All tests completed");
        $finish;
    end
    
endmodule