import arx_core_config_pkg::*;
import PipelineTypes::*;
import IALUTypes::*;
import LoadStoreTypes::*;
import BranchTypes::*;
import InstrTypes::*;

module InsnDecodeStage (
    input logic clk,
    input logic arstn,

    // HALT REQ
    input  logic halt_req_i,
    output logic halt_ack_o,
    // -----------

    input logic flush_i,

    // FROM FETCH STAGE
    input  logic valid_i,
    output logic ready_i,

    input if2id_t data_i,
    // -----------

    // TO EXEC STAGE
    output logic valid_o,
    input  logic ready_o,

    output id2ex_t data_o,
    // -----------

    // FROM WRITE BACK
    input reg_wb_t reg_wb_i,
    // -----------
    output logic [     2:0] dbg_used_regs_o[32],
    output logic [XLEN-1:0] dbg_x_o        [18]
);

  // STAGE REGISTERS

  logic                     valid_ff;

  if2id_t                   data_ff;

  logic          [     1:0] reg_use_cnt_ff [32];

  logic                     need_stall;
  logic                     reg_write_sync;
  instr_fields_t            instr_fields;

  logic          [XLEN-1:0] imm;

  wb_type_e                 wb_type;

  logic                     mem_op;
  ls_type_e                 mem_op_type;

  logic                     pc_jump_en;
  branch_type_e             m_pc_addr_type;

  logic                     alu_en;
  alu_op_e                  alu_op;


  logic                     mdu_en;
  mdu_op_e                  mdu_op;

  alu_src1_e                arg_src_1;
  alu_src2_e                arg_src_2;

  assign need_stall = (|(reg_use_cnt_ff[instr_fields.rs_1])) || (|(reg_use_cnt_ff[instr_fields.rs_2]));

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      valid_ff <= 1'b0;
    end else begin
      if (ready_i && valid_i) begin
        valid_ff <= 1'b1;
      end else if (flush_i || valid_o && ready_o) begin
        valid_ff <= 1'b0;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (valid_i && ready_i) begin
      data_ff <= data_i;
    end
  end

  always_comb begin
    if (~flush_i & ~halt_req_i) begin
      ready_i = !valid_ff || (~need_stall && ready_o);
      valid_o = valid_ff && !need_stall;
    end else begin
      ready_i = 1'b0;
      valid_o = 1'b0;
    end
  end

  // -----------

  // INSN DECODER

  InsnDecoder insnDecoder (
      .insn_i  (data_ff.insn),
      .fields_o(instr_fields)
  );

  // -----------

  // REGISTER FILE

  RegisterFile #(
      .XLEN(XLEN)
  ) regFile (
      .clk  (clk),
      .arstn(arstn),

      .rs_1 (instr_fields.rs_1),
      .out_1(data_o.rs1),
      .rs_2 (instr_fields.rs_2),
      .out_2(data_o.rs2),

      .rd(reg_wb_i.rd),
      .write_en(reg_wb_i.we),
      .write_data(reg_wb_i.data),

      .dbg_x(dbg_x_o)
  );

  assign reg_write_sync = valid_o & ready_o & (data_o.wb_type != WB_NONE);

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      for (int i = 0; i < 32; i = i + 1) begin
        reg_use_cnt_ff[i] <= '0;
      end
    end else begin
      if (reg_wb_i.rd != data_o.rd | ~reg_wb_i.we | ~reg_write_sync) begin
        if (reg_wb_i.we) begin
          reg_use_cnt_ff[reg_wb_i.rd] <= reg_use_cnt_ff[reg_wb_i.rd] - 1'b1;
        end

        if (reg_write_sync) begin
          reg_use_cnt_ff[data_o.rd] <= reg_use_cnt_ff[data_o.rd] + 1'b1;
        end
      end
    end
  end

  // -----------

  // OUT ASSIGNMENTS

  assign data_o.imm = imm;
  assign data_o.rd = instr_fields.rd;
  assign data_o.pc = data_ff.pc;
  assign data_o.wb_type = wb_type;
  assign data_o.mem_op = mem_op;
  assign data_o.mem_op_type = mem_op_type;
  assign data_o.pc_jump_en = pc_jump_en;
  assign data_o.pc_addr_type = m_pc_addr_type;
  assign data_o.alu_op = alu_op;
  assign data_o.arg_src_1 = arg_src_1;
  assign data_o.arg_src_2 = arg_src_2;
  assign data_o.mdu_op = mdu_op;
  assign data_o.alu_en = alu_en;
  assign data_o.mdu_en = mdu_en;
  assign halt_ack_o = halt_req_i;

  // -----------

  // DECODING

  always_comb begin
    imm = '0;
    wb_type = WB_NONE;

    mem_op = 1'b0;
    mem_op_type = LOAD_WORD;

    pc_jump_en = 1'b0;
    m_pc_addr_type = BRANCH_PC_IMM;

    alu_op = IALU_ADD;
    arg_src_1 = OP_SRC_RS1;
    arg_src_2 = OP_SRC_RS2;

    mdu_op = IMDU_MUL;

    alu_en = 1'b0;
    mdu_en = 1'b0;

    case (instr_fields.opcode)
      7'b0110011: begin
        wb_type   = WB_EX_RES;
        arg_src_1 = OP_SRC_RS1;
        arg_src_2 = OP_SRC_RS2;

        if (instr_fields.funct_7 == 7'h01) begin
          alu_en = 1'b0;
          mdu_en = 1'b1;
        end else begin
          alu_en = 1'b1;
          mdu_en = 1'b0;
        end

        unique case ({
          instr_fields.funct_3, instr_fields.funct_7
        })
          {3'h0, 7'h00} : alu_op = IALU_ADD;
          {3'h0, 7'h20} : alu_op = IALU_SUB;
          {3'h4, 7'h00} : alu_op = IALU_XOR;
          {3'h6, 7'h00} : alu_op = IALU_OR;
          {3'h7, 7'h00} : alu_op = IALU_AND;
          {3'h1, 7'h00} : alu_op = IALU_SLL;
          {3'h5, 7'h00} : alu_op = IALU_SRL;
          {3'h5, 7'h20} : alu_op = IALU_SRA;
          {3'h2, 7'h00} : alu_op = IALU_SLT;
          {3'h3, 7'h00} : alu_op = IALU_SLTU;

          {3'h0, 7'h01} : mdu_op = IMDU_MUL;
          {3'h1, 7'h01} : mdu_op = IMDU_MULH;
          {3'h2, 7'h01} : mdu_op = IMDU_MULHSU;
          {3'h3, 7'h01} : mdu_op = IMDU_MULHU;
          {3'h4, 7'h01} : mdu_op = IMDU_DIV;
          {3'h5, 7'h01} : mdu_op = IMDU_DIVU;
          {3'h6, 7'h01} : mdu_op = IMDU_REM;
          {3'h7, 7'h01} : mdu_op = IMDU_REMU;
        endcase
      end
      7'b0010011: begin
        wb_type = WB_EX_RES;
        alu_en = 1'b1;
        arg_src_1 = OP_SRC_RS1;
        arg_src_2 = OP_SRC_IMM;
        imm = instr_fields.imm_i;

        unique case (instr_fields.funct_3)
          3'h0: alu_op = IALU_ADD;
          3'h4: alu_op = IALU_XOR;
          3'h6: alu_op = IALU_OR;
          3'h7: alu_op = IALU_AND;
          3'h1: begin
            imm = {27'b0, instr_fields.imm_i[4:0]};
            alu_op = IALU_SLL;
          end
          3'h5: begin
            imm = {27'b0, instr_fields.imm_i[4:0]};
            alu_op = instr_fields.funct_7 === 7'h00 ? IALU_SRL : IALU_SRA;
          end
          3'h2: alu_op = IALU_SLT;
          3'h3: alu_op = IALU_SLTU;
        endcase
      end
      7'b0000011: begin
        wb_type = WB_MEM_RES;

        alu_en = 1'b1;
        arg_src_1 = OP_SRC_RS1;
        arg_src_2 = OP_SRC_IMM;
        alu_op = IALU_ADD;
        imm = instr_fields.imm_i;

        mem_op = 1'b1;
        unique case (instr_fields.funct_3)
          3'h0: mem_op_type = LOAD_BYTE;
          3'h1: mem_op_type = LOAD_HALFWORD;
          3'h2: mem_op_type = LOAD_WORD;
          3'h4: mem_op_type = LOAD_BYTE_UNSIGNED;
          3'h5: mem_op_type = LOAD_HALFWORD_UNSIGNED;
        endcase
      end
      7'b0100011: begin
        alu_en = 1'b1;
        arg_src_1 = OP_SRC_RS1;
        arg_src_2 = OP_SRC_IMM;
        alu_op = IALU_ADD;
        imm = instr_fields.imm_s;

        mem_op = 1'b1;
        unique case (instr_fields.funct_3)
          3'h0: mem_op_type = STORE_BYTE;
          3'h1: mem_op_type = STORE_HALFWORD;
          3'h2: mem_op_type = STORE_WORD;
        endcase
      end
      7'b1100011: begin
        m_pc_addr_type = BRANCH_PC_IMM;

        alu_en = 1'b1;
        arg_src_1 = OP_SRC_RS1;
        arg_src_2 = OP_SRC_RS2;
        imm = instr_fields.imm_b;

        unique case (instr_fields.funct_3)
          3'h0: alu_op = IALU_EQ;
          3'h1: alu_op = IALU_NEQ;
          3'h4: alu_op = IALU_LT;
          3'h5: alu_op = IALU_GE;
          3'h6: alu_op = IALU_LTU;
          3'h7: alu_op = IALU_GEU;
        endcase
      end
      7'b1101111: begin
        alu_en = 1'b1;
        pc_jump_en = 1'b1;
        m_pc_addr_type = BRANCH_PC_IMM;
        imm = instr_fields.imm_j;

        wb_type = WB_EX_RES;
        arg_src_1 = OP_SRC_PC;
        arg_src_2 = OP_SRC_FOUR;
        alu_op = IALU_ADD;
      end
      7'b1100111: begin
        pc_jump_en = 1'b1;
        m_pc_addr_type = BRANCH_REG_IMM;
        imm = instr_fields.imm_i;

        wb_type = WB_EX_RES;
        alu_en = 1'b1;
        arg_src_1 = OP_SRC_PC;
        arg_src_2 = OP_SRC_FOUR;
        alu_op = IALU_ADD;
      end
      7'b0110111: begin
        wb_type = WB_EX_RES;
        alu_en = 1'b1;
        arg_src_1 = OP_SRC_ZERO;
        arg_src_2 = OP_SRC_IMM;
        alu_op = IALU_ADD;
        imm = instr_fields.imm_u;
      end
      7'b0010111: begin
        wb_type = WB_EX_RES;
        alu_en = 1'b1;
        arg_src_1 = OP_SRC_PC;
        arg_src_2 = OP_SRC_IMM;
        alu_op = IALU_ADD;
        imm = instr_fields.imm_u;
      end
      default: begin
        alu_en = 1'b1;
      end
    endcase
  end

  // -----------

  // DEBUG

  always_comb begin
    for (int i = 0; i < 32; i = i + 1) begin
      dbg_used_regs_o[i] = reg_use_cnt_ff[i];
    end
  end

  // -----------

endmodule
