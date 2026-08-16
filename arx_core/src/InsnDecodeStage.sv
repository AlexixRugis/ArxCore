import IALUTypes::*;
import LoadStoreTypes::*;
import BranchTypes::*;

module InsnDecodeStage
#(
    parameter INSN_WIDTH = 32,
    parameter XLEN = 32,
    parameter ADDR_WIDTH = 32
) (
    input   logic                       clk,
    input   logic                       arstn,

// HALT REQ
    input   logic                       halt_req_in,
    output  logic                       halt_ack_out,
// -----------

    input   logic                       flush_in,

// FROM FETCH STAGE
    input  logic                        valid_in,
    output logic                        ready_in,

    input  logic [ADDR_WIDTH-1:0]       pc_in,
    input  logic [INSN_WIDTH-1:0]       insn_in,
// -----------

// TO EXEC STAGE
    output  logic                       valid_out,
    input   logic                       ready_out,

    output  logic [XLEN-1:0]            rs1_out,
    output  logic [XLEN-1:0]            rs2_out,
    output  logic [XLEN-1:0]            imm_out,

    output  logic [4:0]                 rd_out,
    output  logic [ADDR_WIDTH-1:0]      pc_out,
    output  branch_type_t               pc_addr_type_out,
    output  logic                       pc_jump_en_out,

    output  logic                       reg_write_out,
    output  logic                       mem_to_reg_out,
    output  logic                       mem_op_out,
    output  ls_type_t                   mem_op_type_out,
    
    output  ALU_op_t                    alu_op_out,
    output  ALU_src1_t                  alu_src_1_out,
    output  ALU_src2_t                  alu_src_2_out,

    output  MDU_op_t                    mdu_op_out,
    
    output  logic                       alu_en_out,
    output  logic                       mdu_en_out,
// -----------

// FROM WRITE BACK
    input   logic [4:0]                 rd_in,
    input   logic [XLEN-1:0]            rd_val_in,
    input   logic                       rd_we_in,
// -----------
    output  logic [2:0]                 dbg_used_regs_out [0:31],

    output  logic [XLEN-1:0]            dbg_x0,
    output  logic [XLEN-1:0]            dbg_x1,
    output  logic [XLEN-1:0]            dbg_x2,
    output  logic [XLEN-1:0]            dbg_x3,
    output  logic [XLEN-1:0]            dbg_x4,
    output  logic [XLEN-1:0]            dbg_x5,
    output  logic [XLEN-1:0]            dbg_x6,
    output  logic [XLEN-1:0]            dbg_x7,
    output  logic [XLEN-1:0]            dbg_x10,
    output  logic [XLEN-1:0]            dbg_x11,
    output  logic [XLEN-1:0]            dbg_x12,
    output  logic [XLEN-1:0]            dbg_x13,
    output  logic [XLEN-1:0]            dbg_x14,
    output  logic [XLEN-1:0]            dbg_x15,
    output  logic [XLEN-1:0]            dbg_x16,
    output  logic [XLEN-1:0]            dbg_x17
);

// STAGE REGISTERS

logic                                   m_valid;
logic [ADDR_WIDTH-1:0]                  m_pc;
logic [INSN_WIDTH-1:0]                  m_insn;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        m_valid <= 1'b0;
    end
    else begin
        if (valid_in & ready_in) begin
            m_valid <= 1'b1;
            m_pc <= pc_in;
            m_insn <= insn_in;
        end
        else if (flush_in | valid_out & ready_out) begin
            m_valid <= 1'b0;
        end
    end
end

// -----------

// INSN DECODER

logic [6:0]                             m_opcode;
logic [4:0]                             m_rs_1;
logic [4:0]                             m_rs_2;
logic [4:0]                             m_rd;

logic [2:0]                             m_funct_3;
logic [6:0]                             m_funct_7;

logic [XLEN-1:0]                        m_imm_i;
logic [XLEN-1:0]                        m_imm_s;
logic [XLEN-1:0]                        m_imm_b;
logic [XLEN-1:0]                        m_imm_u;
logic [XLEN-1:0]                        m_imm_j;

InsnDecoder insnDecoder(
    .insn(m_insn),

    .opcode(m_opcode),
    .rs_1(m_rs_1),
    .rs_2(m_rs_2),
    .rd(m_rd),
    
    .funct_3(m_funct_3),
    .funct_7(m_funct_7),
    
    .imm_i(m_imm_i),
    .imm_s(m_imm_s),
    .imm_b(m_imm_b),
    .imm_u(m_imm_u),
    .imm_j(m_imm_j)
);

// -----------

// REGISTER FILE

RegisterFile #(
    .XLEN(XLEN)
) regFile (
    .clk(clk),
    .arstn(arstn),
    
    .rs_1(m_rs_1),
    .out_1(rs1_out),
    .rs_2(m_rs_2),
    .out_2(rs2_out),

    .rd(rd_in),
    .write_en(rd_we_in),
    .write_data(rd_val_in),

    .dbg_x0(dbg_x0),
    .dbg_x1(dbg_x1),
    .dbg_x2(dbg_x2),
    .dbg_x3(dbg_x3),
    .dbg_x4(dbg_x4),
    .dbg_x5(dbg_x5),
    .dbg_x6(dbg_x6),
    .dbg_x7(dbg_x7),
    .dbg_x10(dbg_x10),
    .dbg_x11(dbg_x11),
    .dbg_x12(dbg_x12),
    .dbg_x13(dbg_x13),
    .dbg_x14(dbg_x14),
    .dbg_x15(dbg_x15),
    .dbg_x16(dbg_x16),
    .dbg_x17(dbg_x17)
);

logic [1:0]                             m_used_reg [0:31];

logic                                   reg_write_sync;
assign reg_write_sync = valid_out & ready_out & reg_write_out;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        for (int i = 0; i < 32; i = i + 1) begin
            m_used_reg[i] <= '0;
        end
    end
    else begin
        if (rd_in != rd_out | ~rd_we_in | ~reg_write_sync) begin
            if (rd_we_in) begin
                m_used_reg[rd_in] <= m_used_reg[rd_in] - 1'b1;
            end

            if (reg_write_sync) begin
                m_used_reg[rd_out] <= m_used_reg[rd_out] + 1'b1;
            end
        end
    end
end

// -----------

// OUT ASSIGNMENTS

logic [XLEN-1:0]                        m_imm;
logic                                   m_reg_write;
logic                                   m_mem_to_reg;

logic                                   m_mem_op;
ls_type_t                               m_mem_op_type;

logic                                   m_pc_jump_en;
branch_type_t                           m_pc_addr_type;

ALU_op_t                                m_alu_op;
ALU_src1_t                              m_alu_src_1;
ALU_src2_t                              m_alu_src_2;

MDU_op_t                                m_mdu_op;

logic                                   m_alu_en;
logic                                   m_mdu_en;

always_comb begin
    imm_out = m_imm;
    rd_out = m_rd;
    pc_out = m_pc;

    reg_write_out = m_reg_write;
    mem_to_reg_out = m_mem_to_reg;

    mem_op_out = m_mem_op;
    mem_op_type_out = m_mem_op_type;

    pc_jump_en_out = m_pc_jump_en;
    pc_addr_type_out = m_pc_addr_type;

    alu_op_out = m_alu_op;
    alu_src_1_out = m_alu_src_1;
    alu_src_2_out = m_alu_src_2;

    mdu_op_out = m_mdu_op;
    
    alu_en_out = m_alu_en;
    mdu_en_out = m_mdu_en;

    halt_ack_out = halt_req_in;
end

always_comb begin
    if (~flush_in & ~halt_req_in) begin
        valid_out = m_valid & (m_used_reg[m_rs_1] == 2'b00 & m_used_reg[m_rs_2] == 2'b00);
        ready_in = ~m_valid | (valid_out & ready_out);
    end
    else begin
        valid_out = 1'b0;
        ready_in = 1'b0;
    end
end

// -----------

// DECODING

always_comb begin
    m_imm = '0;
    m_reg_write = 1'b0;
    m_mem_to_reg = 1'b0;

    m_mem_op = 1'b0;
    m_mem_op_type = LOAD_WORD;

    m_pc_jump_en = 1'b0;
    m_pc_addr_type = BRANCH_PC_IMM;

    m_alu_op = IALU_ADD;
    m_alu_src_1 = OP_SRC_RS1;
    m_alu_src_2 = OP_SRC_RS2;

    m_mdu_op = IMDU_MUL;

    m_alu_en = 1'b0;
    m_mdu_en = 1'b0;

    case (m_opcode)
    7'b0110011: begin
        m_reg_write = 1'b1;
        m_alu_src_1 = OP_SRC_RS1;
        m_alu_src_2 = OP_SRC_RS2;

        if (m_funct_7 == 7'h01) begin
            m_alu_en = 1'b0;
            m_mdu_en = 1'b1;
        end
        else begin
            m_alu_en = 1'b1;
            m_mdu_en = 1'b0;
        end

        case ({m_funct_3, m_funct_7})
        {3'h0, 7'h00}: m_alu_op = IALU_ADD;
        {3'h0, 7'h20}: m_alu_op = IALU_SUB;
        {3'h4, 7'h00}: m_alu_op = IALU_XOR;
        {3'h6, 7'h00}: m_alu_op = IALU_OR;
        {3'h7, 7'h00}: m_alu_op = IALU_AND;
        {3'h1, 7'h00}: m_alu_op = IALU_SLL;
        {3'h5, 7'h00}: m_alu_op = IALU_SRL;
        {3'h5, 7'h20}: m_alu_op = IALU_SRA;
        {3'h2, 7'h00}: m_alu_op = IALU_SLT;
        {3'h3, 7'h00}: m_alu_op = IALU_SLTU;

        {3'h0, 7'h01}: m_mdu_op = IMDU_MUL;
        {3'h1, 7'h01}: m_mdu_op = IMDU_MULH;
        {3'h2, 7'h01}: m_mdu_op = IMDU_MULHSU;
        {3'h3, 7'h01}: m_mdu_op = IMDU_MULHU;
        {3'h4, 7'h01}: m_mdu_op = IMDU_DIV;
        {3'h5, 7'h01}: m_mdu_op = IMDU_DIVU;
        {3'h6, 7'h01}: m_mdu_op = IMDU_REM;
        {3'h7, 7'h01}: m_mdu_op = IMDU_REMU;
        endcase
    end
    7'b0010011: begin
        m_reg_write = 1'b1;
        m_alu_en = 1'b1;
        m_alu_src_1 = OP_SRC_RS1;
        m_alu_src_2 = OP_SRC_IMM;
        m_imm = m_imm_i;

        case (m_funct_3)
        3'h0: m_alu_op = IALU_ADD;
        3'h4: m_alu_op = IALU_XOR;
        3'h6: m_alu_op = IALU_OR;
        3'h7: m_alu_op = IALU_AND;
        3'h1: begin
            m_imm = { 27'b0, m_imm_i[4:0] };
            m_alu_op = IALU_SLL;
        end
        3'h5: begin
            m_imm = { 27'b0, m_imm_i[4:0] };
            m_alu_op = m_funct_7 === 7'h00 ? IALU_SRL : IALU_SRA;
        end
        3'h2: m_alu_op = IALU_SLT;
        3'h3: m_alu_op = IALU_SLTU;
        endcase
    end
    7'b0000011: begin
        m_reg_write = 1'b1;
        m_mem_to_reg = 1'b1;

        m_alu_en = 1'b1;
        m_alu_src_1 = OP_SRC_RS1;
        m_alu_src_2 = OP_SRC_IMM;
        m_alu_op = IALU_ADD;
        m_imm = m_imm_i;

        m_mem_op = 1'b1;
        case(m_funct_3)
        3'h0: m_mem_op_type = LOAD_BYTE;
        3'h1: m_mem_op_type = LOAD_HALFWORD;
        3'h2: m_mem_op_type = LOAD_WORD;
        3'h4: m_mem_op_type = LOAD_BYTE_UNSIGNED;
        3'h5: m_mem_op_type = LOAD_HALFWORD_UNSIGNED;
        endcase
    end
    7'b0100011: begin
        m_alu_en = 1'b1;
        m_alu_src_1 = OP_SRC_RS1;
        m_alu_src_2 = OP_SRC_IMM;
        m_alu_op = IALU_ADD;
        m_imm = m_imm_s;

        m_mem_op = 1'b1;
        case (m_funct_3)
        3'h0: m_mem_op_type = STORE_BYTE;
        3'h1: m_mem_op_type = STORE_HALFWORD;
        3'h2: m_mem_op_type = STORE_WORD;
        endcase
    end
    7'b1100011: begin
        m_pc_addr_type = BRANCH_PC_IMM;

        m_alu_en = 1'b1;
        m_alu_src_1 = OP_SRC_RS1;
        m_alu_src_2 = OP_SRC_RS2;
        m_imm = m_imm_b;

        case (m_funct_3)
        3'h0: m_alu_op = IALU_EQ;
        3'h1: m_alu_op = IALU_NEQ;
        3'h4: m_alu_op = IALU_LT;
        3'h5: m_alu_op = IALU_GE;
        3'h6: m_alu_op = IALU_LTU;
        3'h7: m_alu_op = IALU_GEU;
        endcase
    end
    7'b1101111: begin
        m_alu_en = 1'b1;
        m_pc_jump_en = 1'b1;
        m_pc_addr_type = BRANCH_PC_IMM;
        m_imm = m_imm_j;
        
        m_reg_write = 1'b1;
        m_alu_src_1 = OP_SRC_PC;
        m_alu_src_2 = OP_SRC_FOUR;
        m_alu_op = IALU_ADD;
    end
    7'b1100111: begin
        m_pc_jump_en = 1'b1;
        m_pc_addr_type = BRANCH_REG_IMM;
        m_imm = m_imm_i;

        m_reg_write = 1'b1;
        m_alu_en = 1'b1;
        m_alu_src_1 = OP_SRC_PC;
        m_alu_src_2 = OP_SRC_FOUR;
        m_alu_op = IALU_ADD;
    end
    7'b0110111: begin
        m_reg_write = 1'b1;
        m_alu_en = 1'b1;
        m_alu_src_1 = OP_SRC_ZERO;
        m_alu_src_2 = OP_SRC_IMM;
        m_alu_op = IALU_ADD;
        m_imm = m_imm_u;
    end
    7'b0010111: begin
        m_reg_write = 1'b1;
        m_alu_en = 1'b1;
        m_alu_src_1 = OP_SRC_PC;
        m_alu_src_2 = OP_SRC_IMM;
        m_alu_op = IALU_ADD;
        m_imm = m_imm_u;
    end
    default: begin
        m_alu_en = 1'b1;
    end
    endcase
end

// -----------

// DEBUG

always_comb begin
    for (int i = 0; i < 32; i = i + 1) begin
        dbg_used_regs_out[i] = m_used_reg[i];
    end
end

// -----------

endmodule