module InsnDecoder(
    input   logic [31:0]            insn,

    output  logic [6:0]             opcode,
    output  logic [4:0]             rs_1,
    output  logic [4:0]             rs_2,
    output  logic [4:0]             rd,

    output  logic [2:0]             funct_3,
    output  logic [6:0]             funct_7,

    output  logic [31:0]            imm_i,
    output  logic [31:0]            imm_s,
    output  logic [31:0]            imm_b,
    output  logic [31:0]            imm_u,
    output  logic [31:0]            imm_j
);

assign opcode   = insn[6:0];
assign rs_1     = insn[19:15];
assign rs_2     = insn[24:20];
assign rd       = insn[11:7];
assign funct_3  = insn[14:12];
assign funct_7  = insn[31:25];

assign imm_i = { {21{insn[31]}}, insn[30:20] };
assign imm_s = { {21{insn[31]}}, insn[30:25], insn[11:7] };
assign imm_b = { {20{insn[31]}}, insn[7], insn[30:25], insn[11:8], 1'b0 };
assign imm_u = { insn[31:12], 12'b0 };
assign imm_j = { {12{insn[31]}}, insn[19:12], insn[20], insn[30:21], 1'b0 };

endmodule