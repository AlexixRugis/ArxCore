import arx_core_config_pkg::*;
import PipelineTypes::*;
import IALUTypes::*;
import LoadStoreTypes::*;
import BranchTypes::*;
import InstrTypes::*;

module ExecStage (
    input logic clk,
    input logic arstn,

    // FROM ID STAGE
    input  logic valid_in,
    output logic ready_in,

    input id2ex_t data_in,
    // -----------

    // TO MEM STAGE
    output logic valid_out,
    input  logic ready_out,

    output ex2mem_t data_out,

    // -----------
    output logic redir_o,
    output logic [XLEN-1:0] redir_pc_o,

    output logic busy_o
);

  wire m_in_handshake;
  assign m_in_handshake = ready_in & valid_in;

  logic   m_valid_in;

  logic   m_alu_valid_in;
  logic   m_alu_ready_in;
  logic   m_alu_valid_out;
  logic   m_alu_ready_out;

  logic   m_mdu_valid_in;
  logic   m_mdu_ready_in;
  logic   m_mdu_valid_out;
  logic   m_mdu_ready_out;

  // STAGE REGISTERS

  id2ex_t data_ff;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      m_valid_in <= 1'b0;
    end else begin
      if (ready_in) begin
        m_valid_in <= valid_in;
      end
    end
  end

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
    end else begin
      if (m_in_handshake) begin
        data_ff <= data_in;
      end
    end
  end

  // -----------

  // INTEGER ALU

  logic [         XLEN-1:0] ialu_arg_1;
  logic [         XLEN-1:0] ialu_arg_2;
  logic [IALU_OP_WIDTH-1:0] ialu_opcode;
  logic [         XLEN-1:0] ialu_res;
  logic                     ialu_branch_en;

  IALU #(
      .XLEN(XLEN)
  ) ialu (
      .clk  (clk),
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

  logic [XLEN-1:0] imdu_res;

  IMDU #(
      .XLEN(XLEN)
  ) imdu (
      .clk  (clk),
      .arstn(arstn),

      .valid_in(m_mdu_valid_in),
      .ready_in(m_mdu_ready_in),

      .arg_1_in (ialu_arg_1),
      .arg_2_in (ialu_arg_2),
      .opcode_in(data_in.mdu_op),

      .res_out  (imdu_res),
      .valid_out(m_mdu_valid_out),
      .ready_out(m_mdu_ready_out)
  );

  // -----------

  always_comb begin

    unique case (data_in.arg_src_1)
      OP_SRC_RS1:  ialu_arg_1 = data_in.rs1;
      OP_SRC_ZERO: ialu_arg_1 = '0;
      OP_SRC_PC:   ialu_arg_1 = data_in.pc;
    endcase

    unique case (data_in.arg_src_2)
      OP_SRC_RS2:  ialu_arg_2 = data_in.rs2;
      OP_SRC_FOUR: ialu_arg_2 = XLEN'(4);
      OP_SRC_IMM:  ialu_arg_2 = data_in.imm;
    endcase

    ialu_opcode = data_in.alu_op;
  end

  // OUT ASSIGNMENTS

  always_comb begin
    data_out.alu_res = data_ff.alu_en ? ialu_res : (data_ff.mdu_en ? imdu_res : '0);

    data_out.rs2 = data_ff.rs2;
    data_out.rd = data_ff.rd;
    data_out.pc = data_ff.pc;

    redir_pc_o = (data_ff.pc_addr_type === BRANCH_REG_IMM ? data_ff.rs1 : data_ff.pc) + data_ff.imm;
    redir_o = (data_ff.alu_en & ialu_branch_en | data_ff.pc_jump_en) & valid_out & ready_out;

    data_out.wb_type = data_ff.wb_type;
    data_out.mem_op = data_ff.mem_op;
    data_out.mem_op_type = data_ff.mem_op_type;
  end

  always_comb begin
    ready_in = m_alu_ready_in & m_mdu_ready_in;
    valid_out = data_ff.alu_en & m_alu_valid_out | data_ff.mdu_en & m_mdu_valid_out;

    m_alu_valid_in = valid_in & ready_in & data_in.alu_en;
    m_alu_ready_out = ready_out;

    m_mdu_valid_in = valid_in & ready_in & data_in.mdu_en;
    m_mdu_ready_out = ready_out;
  end

  assign busy_o = m_valid_in;

  // -----------

endmodule
