import IALUTypes::*;
import LoadStoreTypes::*;
import BranchTypes::*;

module ExecStage
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

// FROM ID STAGE
    input   logic                       valid_in,
    output  logic                       ready_in,

    input   logic [XLEN-1:0]            rs1_in,
    input   logic [XLEN-1:0]            rs2_in,
    input   logic [XLEN-1:0]            imm_in,

    input   logic [4:0]                 rd_in,
    input   logic [ADDR_WIDTH-1:0]      pc_in,
    input   branch_type_t               pc_branch_type_in,
    input   logic                       pc_jump_en_in,

    input   logic                       reg_write_in,
    input   logic                       mem_to_reg_in,
    input   logic                       mem_op_in,
    input   ls_type_t                   mem_op_type_in,

    input   logic [IALU_OP_WIDTH-1:0]   alu_op_in,
    input   ALU_src1_t                  alu_src_1_in,
    input   ALU_src2_t                  alu_src_2_in,

    input   MDU_op_t                    mdu_op_in,
    
    input   logic                       alu_en_in,
    input   logic                       mdu_en_in,

// -----------

// TO MEM STAGE
    output  logic                       valid_out,
    input   logic                       ready_out,

    output  logic [XLEN-1:0]            alu_out,
    output  logic [XLEN-1:0]            rs2_out,
    output  logic [4:0]                 rd_out,

    output  logic [ADDR_WIDTH-1:0]      pc_out,

    output  logic                       reg_write_out,
    output  logic                       mem_to_reg_out,
    output  logic                       mem_op_out,
    output  ls_type_t                   mem_op_type_out,

// -----------
    output  logic [XLEN-1:0]            pc_branch_out,
    output  logic                       pc_we_out
);

wire                                    m_in_handshake;
assign m_in_handshake                   = ready_in & valid_in;

logic                                   m_alu_valid_in;
logic                                   m_alu_ready_in;
logic                                   m_alu_valid_out;
logic                                   m_alu_ready_out;

logic                                   m_mdu_valid_in;
logic                                   m_mdu_ready_in;
logic                                   m_mdu_valid_out;
logic                                   m_mdu_ready_out;

// STAGE REGISTERS

logic [XLEN-1:0]                        m_rs1_in;
logic [XLEN-1:0]                        m_rs2_in;
logic [XLEN-1:0]                        m_imm_in;

logic [4:0]                             m_rd_in;
logic [ADDR_WIDTH-1:0]                  m_pc_in;
branch_type_t                           m_pc_branch_type;

logic                                   m_reg_write_in;
logic                                   m_mem_to_reg_in;
logic                                   m_mem_op;
ls_type_t                               m_mem_op_type;

logic                                   m_pc_jump_en_in;

logic                                   m_alu_en_in;
logic                                   m_mdu_en_in;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
    end
    else begin
        if (m_in_handshake) begin
            m_rs1_in <= rs1_in;
            m_rs2_in <= rs2_in;
            m_imm_in <= imm_in;

            m_rd_in <= rd_in;
            m_pc_in <= pc_in;
            m_pc_branch_type <= pc_branch_type_in;

            m_reg_write_in <= reg_write_in;
            m_mem_to_reg_in <= mem_to_reg_in;
            m_mem_op <= mem_op_in;
            m_mem_op_type <= mem_op_type_in;

            m_pc_jump_en_in <= pc_jump_en_in;

            m_alu_en_in <= alu_en_in;
            m_mdu_en_in <= mdu_en_in;
        end
    end
end

// -----------

// INTEGER ALU

logic [XLEN-1:0]                        ialu_arg_1;
logic [XLEN-1:0]                        ialu_arg_2;
logic [IALU_OP_WIDTH-1:0]               ialu_opcode;
logic [XLEN-1:0]                        ialu_res;
logic                                   ialu_branch_en;

IALU #(
    .XLEN(XLEN)
) ialu (
    .clk(clk),
    .arstn(arstn),

    .valid_in(m_alu_valid_in),
    .ready_in(m_alu_ready_in),

    .arg_1(ialu_arg_1),
    .arg_2(ialu_arg_2),
    .opcode(ialu_opcode),
    .res(ialu_res),
    .branch_en(ialu_branch_en),

    .valid_out(m_alu_valid_out),
    .ready_out(m_alu_ready_out)
);

// -----------

// MULDIV UNIT

logic [XLEN-1:0]                        imdu_res;

IMDU #(
    .XLEN(XLEN)
) imdu (
    .clk(clk),
    .arstn(arstn),

    .valid_in(m_mdu_valid_in),
    .ready_in(m_mdu_ready_in),

    .arg_1_in(ialu_arg_1),
    .arg_2_in(ialu_arg_2),
    .opcode_in(mdu_op_in),

    .res_out(imdu_res),
    .valid_out(m_mdu_valid_out),
    .ready_out(m_mdu_ready_out)
);

// -----------

always_comb begin

    case(alu_src_1_in)
    OP_SRC_RS1: ialu_arg_1 = rs1_in;
    OP_SRC_ZERO: ialu_arg_1 = '0;
    OP_SRC_PC: ialu_arg_1 = pc_in;
    endcase

    case(alu_src_2_in)
    OP_SRC_RS2: ialu_arg_2 = rs2_in;
    OP_SRC_FOUR: ialu_arg_2 = XLEN'(4);
    OP_SRC_IMM: ialu_arg_2 = imm_in;
    endcase

    ialu_opcode = alu_op_in;
end

// OUT ASSIGNMENTS

always_comb begin
    alu_out = m_alu_en_in ? ialu_res :
        (m_mdu_en_in ? imdu_res : '0);

    rs2_out = m_rs2_in;
    rd_out = m_rd_in;
    pc_out = m_pc_in;

    pc_branch_out = (m_pc_branch_type === BRANCH_REG_IMM ? m_rs1_in : m_pc_in)
                + m_imm_in;
    pc_we_out = (m_alu_en_in & ialu_branch_en | m_pc_jump_en_in) & valid_out & ready_out;

    reg_write_out = m_reg_write_in;
    mem_to_reg_out = m_mem_to_reg_in;
    mem_op_out = m_mem_op;
    mem_op_type_out = m_mem_op_type;

    halt_ack_out = halt_req_in;
end

always_comb begin
    if (~halt_req_in) begin
        ready_in = m_alu_ready_in & m_mdu_ready_in;
        valid_out = m_alu_en_in & m_alu_valid_out | m_mdu_en_in & m_mdu_valid_out;

        m_alu_valid_in = valid_in & ready_in & alu_en_in;
        m_alu_ready_out = ready_out;

        m_mdu_valid_in = valid_in & ready_in & mdu_en_in;
        m_mdu_ready_out = ready_out;
    end
    else begin
        ready_in = 1'b0;
        valid_out = 1'b0;

        m_alu_valid_in = 1'b0;
        m_alu_ready_out = 1'b0;
        m_mdu_valid_in = 1'b0;
        m_mdu_ready_out = 1'b0;
    end
end

// -----------

endmodule