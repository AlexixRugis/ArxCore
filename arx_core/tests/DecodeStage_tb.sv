`timescale 1ns/100ps

module DecodeStage_tb;

import BranchTypes::*;
import IALUTypes::*;
import LoadStoreTypes::*;

// Parameters
parameter XLEN = 32;
parameter ADDR_WIDTH = 32;
parameter INSN_WIDTH = 32;
parameter CLK_PERIOD = 10; // ns
parameter TIMEOUT = 100000;

`include "instruction_generators.svh"

// CLOCK AND RESET
logic                           clk;
logic                           arstn;

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

initial begin
    #(TIMEOUT);
    $error("TIMEOUT");
    $stop();
end


// DUT

logic                                   halt_req_in;
logic                                   halt_ack_out;

logic                                   flush_in;                                 

logic                                   valid_in;
logic                                   ready_in;

logic [ADDR_WIDTH-1:0]                  pc_in;
logic [INSN_WIDTH-1:0]                  insn_in;

logic                                   valid_out;
logic                                   ready_out;

logic [XLEN-1:0]                        rs1_out;
logic [XLEN-1:0]                        rs2_out;
logic [XLEN-1:0]                        imm_out;

logic [4:0]                             rd_out;
logic [ADDR_WIDTH-1:0]                  pc_out;
branch_type_t                           pc_addr_type_out;
logic                                   pc_jump_en_out;

logic                                   reg_write_out;
logic                                   mem_to_reg_out;
logic                                   mem_op_out;
ls_type_t                               mem_op_type_out;
    
ALU_op_t                                alu_op_out;
ALU_src1_t                              alu_src_1_out;
ALU_src2_t                              alu_src_2_out;

logic [4:0]                             rd_in;
logic [XLEN-1:0]                        rd_val_in;
logic                                   rd_we_in;

logic [31:0]                            dbg_used_regs_out;

InsnDecodeStage #(
    .INSN_WIDTH(INSN_WIDTH),
    .XLEN(XLEN),
    .ADDR_WIDTH(ADDR_WIDTH)
) dut(.*);

// -----------

// EMUL WRITEBACK

logic                                   m_pending_wb;
logic [4:0]                             m_pending_rd;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        rd_in <= '0;
        rd_val_in <= '0;
        rd_we_in <= 1'b0;
        m_pending_wb <= 1'b0;
        m_pending_rd <= 5'h0;
    end
    else begin
        if (ready_out & valid_out & reg_write_out) begin
            m_pending_wb <= 1'b1;
            m_pending_rd <= rd_out;
        end

        if (m_pending_wb) begin
            rd_in <= m_pending_rd;
            rd_val_in <= $urandom();
            rd_we_in <= 1'b1;

            m_pending_wb <= ready_out & valid_out & reg_write_out;
        end
        else begin
            rd_we_in <= 1'b0;
        end
    end
end


// -----------

parameter TRANSACTION_COUNT = 1000;

typedef struct packed {
    logic [INSN_WIDTH-1:0] insn;
    logic [ADDR_WIDTH-1:0] pc;

    insn_class_t insn_class;

    logic [XLEN-1:0] exp_rs1;
    logic [XLEN-1:0] exp_rs2;
    logic [XLEN-1:0] exp_imm;
    logic [4:0] exp_rd;

    branch_type_t exp_pc_addr_type;
    logic exp_pc_jump_en;

    logic exp_reg_write;
    logic exp_mem_to_reg;

    logic exp_mem_op;
    ls_type_t exp_mem_op_type;

    ALU_op_t exp_alu_op;
    ALU_src1_t exp_alu_op1;
    ALU_src2_t exp_alu_op2;
} in_data_t;

typedef struct packed {
    logic [XLEN-1:0] rs1;
    logic [XLEN-1:0] rs2;
    logic [XLEN-1:0] imm;
    logic [4:0] rd;
    logic [ADDR_WIDTH-1:0] pc;
    branch_type_t pc_addr_type;
    logic pc_jump_en;
    logic reg_write;
    logic mem_to_reg;
    logic mem_op;
    ls_type_t mem_op_type;
    ALU_op_t alu_op;
    ALU_src1_t alu_src_1;
    ALU_src2_t alu_src_2;
} out_data_t;

mailbox #(in_data_t) mb_in = new();
mailbox #(out_data_t) mb_out = new();

task send_transaction();
    in_data_t in_data;
    insn_class_t insn_class;
    logic [4:0] rd, rs1, rs2;
    int imm;
    
    in_data.insn = gen_random_instruction(insn_class, rd, rs1, rs2, imm);
    in_data.pc = {30'($urandom()), 2'b00};

    in_data.insn_class = insn_class;
    
    in_data.exp_rd = rd;
    in_data.exp_imm = imm;

    in_data.exp_rs1 = rs1;
    in_data.exp_rs2 = rs2;

    in_data.exp_pc_jump_en = 1'b0;
    in_data.exp_reg_write = 1'b0;
    in_data.exp_mem_to_reg = 1'b0;
    in_data.exp_mem_op = 1'b0;
    
    case (insn_class)
        INSN_R_TYPE: begin
            in_data.exp_reg_write = 1'b1;
        end
        INSN_I_TYPE: begin
            in_data.exp_reg_write = 1'b1;
        end
        INSN_LOAD: begin
            in_data.exp_reg_write = 1'b1;
            in_data.exp_mem_to_reg = 1'b1;
            in_data.exp_mem_op = 1'b1;
        end
        INSN_STORE: begin
            in_data.exp_mem_op = 1'b1;
        end
        INSN_BRANCH: begin
        end
        INSN_JAL: begin
            in_data.exp_reg_write = 1'b1;
        end
        INSN_JALR: begin
            in_data.exp_reg_write = 1'b1;
        end
        INSN_LUI: begin
            in_data.exp_reg_write = 1'b1;
        end
        INSN_AUIPC: begin
            in_data.exp_reg_write = 1'b1;
        end
        INSN_NOP: begin
            in_data.exp_reg_write = 1'b1;
        end
    endcase
    
    @(posedge clk);
    valid_in <= 1'b1;
    pc_in <= in_data.pc;
    insn_in <= in_data.insn;
    
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
        
        out_data.rs1 = rs1_out;
        out_data.rs2 = rs2_out;
        out_data.imm = imm_out;
        out_data.rd = rd_out;
        out_data.pc = pc_out;
        out_data.pc_addr_type = pc_addr_type_out;
        out_data.pc_jump_en = pc_jump_en_out;
        out_data.reg_write = reg_write_out;
        out_data.mem_to_reg = mem_to_reg_out;
        out_data.mem_op = mem_op_out;
        out_data.mem_op_type = mem_op_type_out;
        out_data.alu_op = alu_op_out;
        out_data.alu_src_1 = alu_src_1_out;
        out_data.alu_src_2 = alu_src_2_out;

        mb_out.put(out_data);
    end
endtask

task check_output();
    in_data_t in_data;
    out_data_t out_data;
    
    for (int i = 0; i < TRANSACTION_COUNT; i++) begin
        mb_in.get(in_data);
        mb_out.get(out_data);

        $display("INSN: %s opcode: %b funct3: %b funct7: %b", in_data.insn_class.name(), in_data.insn[6:0], in_data.insn[14:12], in_data.insn[31:25]);

        if (in_data.pc !== out_data.pc) begin
            $error("PC mismatch! Expected: %h, Actual: %h", in_data.pc, out_data.pc);
        end

        if (in_data.exp_reg_write !== out_data.reg_write) begin
            $error("reg_write mismatch! Expected: %h, Actual: %h", in_data.exp_reg_write, out_data.reg_write);

            if (in_data.exp_rd !== out_data.rd) begin
                $error("rd mismatch! Expected: %h, Actual: %h", in_data.exp_rd, out_data.rd);
            end
        end

        if (in_data.exp_mem_to_reg !== out_data.mem_to_reg) begin
            $error("mem_to_reg mismatch! Expected: %h, Actual: %h", in_data.exp_mem_to_reg, out_data.mem_to_reg);
        end

        if (in_data.exp_mem_op !== out_data.mem_op) begin
            $error("mem_op mismatch! Expected: %h, Actual: %h", in_data.exp_mem_op, out_data.mem_op);
        end

        if (in_data.exp_imm !== out_data.imm) begin
            $error("Imm mismatch! Expected: %b, Actual: %b", in_data.exp_imm, out_data.imm);
        end

    end
endtask

initial begin
    valid_in <= 1'b0;
    ready_out <= 1'b0;
    pc_in <= '0;
    insn_in <= '0;
    flush_in <= 1'b0;
    halt_req_in <= 1'b0;
    
    wait(arstn);
    repeat(5) @(posedge clk);
    
    fork
        begin
            wait(arstn);
            for (int i = 0; i < TRANSACTION_COUNT; i++) begin
                send_transaction();
                repeat($urandom_range(0, 5)) @(posedge clk);
            end
        end
        
        read_output();
        check_output();
    join
    
    #100;
    $finish;
end

endmodule