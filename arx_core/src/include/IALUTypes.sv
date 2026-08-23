package IALUTypes;

  parameter int IALU_OP_WIDTH = 5;
  parameter int IMDU_OP_WIDTH = 3;

  typedef enum logic [IALU_OP_WIDTH-1:0] {
    IALU_ADD,
    IALU_SUB,
    IALU_XOR,
    IALU_OR,
    IALU_AND,

    IALU_EQ,
    IALU_NEQ,
    IALU_LT,
    IALU_LTU,
    IALU_GE,
    IALU_GEU,

    IALU_SLT,
    IALU_SLTU,

    IALU_SLL,
    IALU_SRL,
    IALU_SRA,

    IALU_ARG2
  } alu_op_e;

  typedef enum logic [IMDU_OP_WIDTH-1:0] {
    IMDU_MUL,
    IMDU_MULH,
    IMDU_MULHSU,
    IMDU_MULHU,
    IMDU_DIV,
    IMDU_DIVU,
    IMDU_REM,
    IMDU_REMU
  } mdu_op_e;

  typedef enum logic [1:0] {
    OP_SRC_RS1  = 2'b00,
    OP_SRC_ZERO = 2'b01,
    OP_SRC_PC   = 2'b10
  } alu_src1_e;

  typedef enum logic [1:0] {
    OP_SRC_RS2  = 2'b00,
    OP_SRC_FOUR = 2'b01,
    OP_SRC_IMM  = 2'b10
  } alu_src2_e;

endpackage
