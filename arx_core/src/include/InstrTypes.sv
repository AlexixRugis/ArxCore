package InstrTypes;

typedef struct packed {
    logic [6:0] opcode;
    logic [4:0] rs_1;
    logic [4:0] rs_2;
    logic [4:0] rd;

    logic [2:0] funct_3;
    logic [6:0] funct_7;

    logic [31:0] imm_i;
    logic [31:0] imm_s;
    logic [31:0] imm_b;
    logic [31:0] imm_u;
    logic [31:0] imm_j;
} instr_fields_t;

typedef enum logic [1:0] {
    WB_NONE,
    WB_EX_RES,
    WB_MEM_RES
} wb_type_e;

endpackage
