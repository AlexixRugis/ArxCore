module InsnDecoder
  import InstrTypes::*;
(
    input logic [31:0] insn_i,
    output instr_fields_t fields_o
);
  assign fields_o.opcode  = insn_i[6:0];
  assign fields_o.rs_1    = insn_i[19:15];
  assign fields_o.rs_2    = insn_i[24:20];
  assign fields_o.rd      = insn_i[11:7];
  assign fields_o.funct_3 = insn_i[14:12];
  assign fields_o.funct_7 = insn_i[31:25];

  assign fields_o.imm_i   = {{21{insn_i[31]}}, insn_i[30:20]};
  assign fields_o.imm_s   = {{21{insn_i[31]}}, insn_i[30:25], insn_i[11:7]};
  assign fields_o.imm_b   = {{20{insn_i[31]}}, insn_i[7], insn_i[30:25], insn_i[11:8], 1'b0};
  assign fields_o.imm_u   = {insn_i[31:12], 12'b0};
  assign fields_o.imm_j   = {{12{insn_i[31]}}, insn_i[19:12], insn_i[20], insn_i[30:21], 1'b0};
endmodule
