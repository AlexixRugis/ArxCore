function automatic logic [XLEN-1:0] sign_extend(input logic [XLEN-1:0] value, input int bits);
    logic [XLEN-1:0] result;
    int idx;

    result = value;
    for (int idx = bits; idx <= XLEN - 1; idx = idx + 1) begin
        result[idx] = value[bits-1];
    end
    return result;
endfunction

function automatic logic [4:0] random_reg(input logic exclude_zero = 1);
    logic [4:0] regr;
    if (exclude_zero)
        regr = $urandom_range(1, 31);
    else
        regr = $urandom_range(0, 31);
    return regr;
endfunction

// ============== R-type instructions ==============
typedef struct {
    logic [6:0] funct7;
    logic [2:0] funct3;
    string name;
} r_type_t;

const r_type_t R_INSTRUCTIONS[] = '{
    '{7'h00, 3'h0, "ADD"},
    '{7'h02, 3'h0, "SUB"},
    '{7'h00, 3'h4, "XOR"},
    '{7'h00, 3'h6, "OR"},
    '{7'h00, 3'h7, "AND"},
    '{7'h00, 3'h1, "SLL"},
    '{7'h00, 3'h5, "SRL"},
    '{7'h20, 3'h5, "SRA"},
    '{7'h00, 3'h2, "SLT"},
    '{7'h00, 3'h3, "SLTU"}
};

function automatic logic [31:0] gen_r_type(
    input logic [4:0] rd,
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input int op_idx
);
    return {R_INSTRUCTIONS[op_idx].funct7, rs2, rs1, 
            R_INSTRUCTIONS[op_idx].funct3, rd, 7'b0110011};
endfunction

// ============== I-type (arithmetics) ==============
typedef struct {
    logic [2:0] funct3;
    string name;
    logic uses_funct7;
} i_type_t;

const i_type_t I_INSTRUCTIONS[] = '{
    '{3'b000, "ADDI", 0},
    '{3'b001, "SLLI", 1},
    '{3'b010, "SLTI", 0},
    '{3'b011, "SLTIU", 0},
    '{3'b100, "XORI", 0},
    '{3'b101, "SRLI", 1},
    '{3'b110, "ORI", 0},
    '{3'b111, "ANDI", 0}
};

function automatic logic [31:0] gen_i_type_arith(
    input logic [4:0] rd,
    input logic [4:0] rs1,
    input int imm,
    input int op_idx
);
    logic [11:0] imm12 = imm[11:0];
    logic [6:0] funct7 = 7'b0000000;
    
    if (I_INSTRUCTIONS[op_idx].uses_funct7) begin
        if (op_idx == 1) begin
            funct7 = {2'b00, imm[4:0]};
        end
        else if (op_idx == 5) begin
            if (imm[5]) begin
                funct7 = 7'b0100000;
            end else begin
                funct7 = 7'b0000000;
            end
        end
    end
    else begin
        funct7 = imm[11:5];
    end
    
    return {funct7, imm12[4:0], rs1, I_INSTRUCTIONS[op_idx].funct3, 
            rd, 7'b0010011};
endfunction

// ============== Load instructions ==============
const ls_type_t LOAD_TYPES[] = '{
    LOAD_BYTE, LOAD_HALFWORD, LOAD_WORD,
    LOAD_BYTE_UNSIGNED, LOAD_HALFWORD_UNSIGNED
};

function automatic logic [31:0] gen_load(
    input logic [4:0] rd,
    input logic [4:0] rs1,
    input int offset,
    input int load_idx
);
    logic [11:0] offset12 = offset[11:0];
    logic [2:0] funct3;
    
    case (load_idx)
        0: funct3 = 3'b000;
        1: funct3 = 3'b001;
        2: funct3 = 3'b010;
        3: funct3 = 3'b100;
        4: funct3 = 3'b101;
        default: funct3 = 3'b010;
    endcase
    
    return {offset12, rs1, funct3, rd, 7'b0000011};
endfunction

// ============== Store instructions ==============
const ls_type_t STORE_TYPES[] = '{
    STORE_BYTE, STORE_HALFWORD, STORE_WORD
};

function automatic logic [31:0] gen_store(
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input int offset,
    input int store_idx
);
    logic [11:0] offset12 = offset[11:0];
    logic [2:0] funct3;
    
    case (store_idx)
        0: funct3 = 3'b000;
        1: funct3 = 3'b001;
        2: funct3 = 3'b010;
        default: funct3 = 3'b010;
    endcase
    
    return {offset12[11:5], rs2, rs1, funct3, offset12[4:0], 7'b0100011};
endfunction

// ============== Branch instructions ==============
typedef struct {
    logic [2:0] funct3;
    string name;
} b_type_t;

const b_type_t BRANCH_INSTRUCTIONS[] = '{
    '{3'b000, "BEQ"},
    '{3'b001, "BNE"},
    '{3'b100, "BLT"},
    '{3'b101, "BGE"},
    '{3'b110, "BLTU"},
    '{3'b111, "BGEU"}
};

function automatic logic [31:0] gen_branch(
    input logic [4:0] rs1,
    input logic [4:0] rs2,
    input int offset,
    input int br_idx
);
    logic [12:0] offset13 = offset[12:0];
    logic [31:0] insn;
    
    insn[31] = offset13[12];
    insn[30:25] = offset13[10:5];
    insn[24:20] = rs2;
    insn[19:15] = rs1;
    insn[14:12] = BRANCH_INSTRUCTIONS[br_idx].funct3;
    insn[11:8] = offset13[4:1];
    insn[7] = offset13[11];
    insn[6:0] = 7'b1100011;
    
    return insn;
endfunction

// ============== JAL (J-type) ==============
function automatic logic [31:0] gen_jal(
    input logic [4:0] rd,
    input int offset
);
    logic [20:0] offset21 = offset[20:0];
    
    return {offset21[20], offset21[10:1], offset21[11], offset21[19:12], rd, 7'b1101111};
endfunction

// ============== JALR (I-type) ==============
function automatic logic [31:0] gen_jalr(
    input logic [4:0] rd,
    input logic [4:0] rs1,
    input int offset
);
    logic [11:0] offset12 = offset[11:0];
    
    return {offset12, rs1, 3'b000, rd, 7'b1100111};
endfunction

// ============== LUI (U-type) ==============
function automatic logic [31:0] gen_lui(
    input logic [4:0] rd,
    input int imm
);
    logic [19:0] imm20 = imm[31:12];
    
    return {imm20, rd, 7'b0110111};
endfunction

// ============== AUIPC (U-type) ==============
function automatic logic [31:0] gen_auipc(
    input logic [4:0] rd,
    input int imm
);
    logic [19:0] imm20 = imm[31:12];
    
    return {imm20, rd, 7'b0010111};
endfunction

// ============== NOP (no operation) ==============
function automatic logic [31:0] gen_nop();
    return 32'h00000013;  // addi x0, x0, 0
endfunction

// ============== High-level instruction gen ==============
typedef enum {
    INSN_R_TYPE = 0,
    INSN_I_TYPE = 1,
    INSN_LOAD = 2,
    INSN_STORE = 3,
    INSN_BRANCH = 4,
    INSN_JAL = 5,
    INSN_JALR = 6,
    INSN_LUI = 7,
    INSN_AUIPC = 8,
    INSN_NOP = 9
} insn_class_t;

function automatic logic [31:0] gen_random_instruction(
    output insn_class_t insn_class,
    output logic [4:0] rd,
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output int imm
);
    int insn_type = $urandom_range(0, 9);
    logic [31:0] insn;
    int r_idx;
    int i_idx;
    int l_idx;
    int s_idx;
    int b_idx;
    
    rd = random_reg(1);
    rs1 = random_reg(0);
    rs2 = random_reg(0);
    imm = $urandom();
    
    case (insn_type)
        0: begin
            insn_class = INSN_R_TYPE;
            r_idx = $urandom_range(0, $size(R_INSTRUCTIONS)-1);
            insn = gen_r_type(rd, rs1, rs2, r_idx);
            imm = '0;
        end
        1: begin
            insn_class = INSN_I_TYPE;
            i_idx = $urandom_range(0, $size(I_INSTRUCTIONS)-1);
            if (I_INSTRUCTIONS[i_idx].uses_funct7)
                imm = $urandom_range(0, 31);  // shamt для сдвигов
            else
                imm = sign_extend($urandom(), 12);
            insn = gen_i_type_arith(rd, rs1, imm, i_idx);
        end
        2: begin
            insn_class = INSN_LOAD;
            l_idx = $urandom_range(0, 4);
            imm = sign_extend($urandom(), 12);
            insn = gen_load(rd, rs1, imm, l_idx);
        end
        3: begin
            insn_class = INSN_STORE;
            s_idx = $urandom_range(0, 2);
            imm = sign_extend($urandom(), 12);
            insn = gen_store(rs1, rs2, imm, s_idx);
            rd = 5'b0;
        end
        4: begin
            insn_class = INSN_BRANCH;
            b_idx = $urandom_range(0, $size(BRANCH_INSTRUCTIONS)-1);
            imm = sign_extend($urandom(), 12) << 1;
            insn = gen_branch(rs1, rs2, imm, b_idx);
            rd = 5'b0;
        end
        5: begin
            insn_class = INSN_JAL;
            imm = sign_extend($urandom(), 20) << 1;
            insn = gen_jal(rd, imm);
            rs1 = 5'b0;
            rs2 = 5'b0;
        end
        6: begin
            insn_class = INSN_JALR;
            imm = sign_extend($urandom(), 12);
            insn = gen_jalr(rd, rs1, imm);
            rs2 = 5'b0;
        end
        7: begin
            insn_class = INSN_LUI;
            imm = {20'($urandom_range(0, 1048575)), 12'b0};
            insn = gen_lui(rd, imm);
            rs1 = 5'b0;
            rs2 = 5'b0;
        end
        8: begin
            insn_class = INSN_AUIPC;
            imm = {20'($urandom_range(0, 1048575)), 12'b0};
            insn = gen_auipc(rd, imm);
            rs1 = 5'b0;
            rs2 = 5'b0;
        end
        default: begin
            insn_class = INSN_NOP;
            insn = gen_nop();
            rd = 5'b0;
            rs1 = 5'b0;
            rs2 = 5'b0;
            imm = 0;
        end
    endcase
    
    return insn;
endfunction