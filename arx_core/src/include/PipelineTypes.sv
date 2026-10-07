package PipelineTypes;
  import arx_core_config_pkg::*;
  import IALUTypes::*;
  import LoadStoreTypes::*;
  import BranchTypes::*;
  import InstrTypes::*;

  typedef struct packed {
    logic [EPOCH_WIDTH-1:0] epoch;
    logic [ADDR_WIDTH-1:0]  pc;
    logic [INSN_WIDTH-1:0]  insn;
  } if2id_t;

  typedef struct packed {
    logic [EPOCH_WIDTH-1:0] epoch;

    logic [XLEN-1:0] rs1;
    logic [XLEN-1:0] rs2;
    logic [XLEN-1:0] imm;

    logic [4:0]            rd;
    logic [ADDR_WIDTH-1:0] pc;
    branch_type_e          pc_addr_type;
    logic                  pc_jump_en;

    wb_type_e wb_type;
    logic     mem_op;
    ls_type_e mem_op_type;

    logic alu_en;
    alu_op_e alu_op;
    logic mdu_en;
    mdu_op_e mdu_op;

    alu_src1_e arg_src_1;
    alu_src2_e arg_src_2;
  } id2ex_t;

  typedef struct packed {
    logic [XLEN-1:0] alu_res;
    logic [XLEN-1:0] rs2;
    logic [4:0]      rd;

    logic [ADDR_WIDTH-1:0] pc;

    logic     mem_op;
    ls_type_e mem_op_type;

    wb_type_e wb_type;
  } ex2mem_t;

  typedef struct packed {
    wb_type_e wb_type;
    logic mem_op;

    logic [XLEN-1:0] alu_res;

    logic [4:0]            rd;
    logic [ADDR_WIDTH-1:0] pc;
  } mem2wb_t;

  typedef struct packed {
    logic we;
    logic [4:0] rd;
    logic [XLEN-1:0] data;
  } reg_wb_t;

endpackage
