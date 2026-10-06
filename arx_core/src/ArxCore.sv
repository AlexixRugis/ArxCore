import IALUTypes::*;
import LoadStoreTypes::*;
import BranchTypes::*;
import InstrTypes::*;

module ArxCore (
    input clk,
    input arstn,

    output logic [31:0] rom_addr,
    output logic        rom_req,
    input  logic [31:0] rom_data,
    input  logic        rom_ack,

    output logic [31:0] ram_addr,
    output logic [31:0] ram_write_data,
    output logic        ram_we,
    output logic [ 3:0] ram_we_mask,
    output logic        ram_req,
    input  logic [31:0] ram_data,
    input  logic        ram_ack,

    input  logic halt_req,
    input  logic resume_req,
    output logic halted,

    input  logic [31:0] mem_debug_addr,
    input  logic [31:0] mem_debug_write_data,
    input  logic        mem_debug_wr_enable,
    input  logic [ 3:0] mem_debug_wr_mask,
    input  logic        mem_debug_req,
    output logic [31:0] mem_debug_data,
    output logic        mem_debug_ack,


    output logic [31:0] dbg_x0,
    output logic [31:0] dbg_x1,
    output logic [31:0] dbg_x2,
    output logic [31:0] dbg_x3,
    output logic [31:0] dbg_x4,
    output logic [31:0] dbg_x5,
    output logic [31:0] dbg_x6,
    output logic [31:0] dbg_x7,
    output logic [31:0] dbg_x8,
    output logic [31:0] dbg_x9,
    output logic [31:0] dbg_x10,
    output logic [31:0] dbg_x11,
    output logic [31:0] dbg_x12,
    output logic [31:0] dbg_x13,
    output logic [31:0] dbg_x14,
    output logic [31:0] dbg_x15,
    output logic [31:0] dbg_x16,
    output logic [31:0] dbg_x17,

    output logic [31:0] dbg_pc_fs,
    output logic [31:0] dbg_pc_id,
    output logic [31:0] dbg_pc_ex,
    output logic [31:0] dbg_pc_mem,
    output logic [31:0] dbg_pc_wb
);

  localparam int unsigned XLEN = 32;
  localparam int unsigned ADDR_WIDTH = 32;
  localparam int unsigned INSN_WIDTH = 32;
  localparam int unsigned EPOCH_WIDTH = 3;

  logic halt_req_in;
  logic halt_ack_out_fs;
  logic halt_ack_out_id;
  logic halt_ack_out_ex;
  logic halt_ack_out_mem;

  logic m_is_halted;
  assign m_is_halted = halt_ack_out_fs & halt_ack_out_id & halt_ack_out_ex & halt_ack_out_mem;

  // FETCH STAGE

  logic [           31:0] fs_pc_in;
  logic                   fs_pc_we_in;

  logic                   fs_valid_out;
  logic                   fs_ready_out;

  logic [EPOCH_WIDTH-1:0] fs_epoch_out;

  logic [           31:0] fs_pc_out;
  assign dbg_pc_fs = fs_pc_out;
  logic [31:0] fs_insn_out;

  InsnFetch #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .INSN_WIDTH(INSN_WIDTH)
  ) fetch_stage (
      .clk  (clk),
      .arstn(arstn),

      // HALT REQ
      .halt_req_in (halt_req_in),
      .halt_ack_out(halt_ack_out_fs),
      // -----------------

      // MEMORY INTERFACE
      .mem_addr(rom_addr),
      .mem_req(rom_req),
      .mem_insn_in(rom_data),
      .mem_ack(rom_ack),
      // -----------------

      // PC SETTING
      .pc_in(fs_pc_in),
      .pc_we(fs_pc_we_in),
      // -----------------

      // OUT DATA
      .valid_out(fs_valid_out),
      .ready_out(fs_ready_out),

      .epoch_out(fs_epoch_out),
      .pc_out(fs_pc_out),
      .insn_out(fs_insn_out)
      // -----------------
  );

  // -----------

  logic id_flush_in;

  logic id_valid_in;
  assign id_valid_in = fs_valid_out;
  logic id_ready_in;
  assign fs_ready_out = id_ready_in;

  logic [EPOCH_WIDTH-1:0] id_epoch_in;
  assign id_epoch_in = fs_epoch_out;

  logic [ADDR_WIDTH-1:0] id_pc_in;
  assign id_pc_in = fs_pc_out;
  logic [INSN_WIDTH-1:0] id_insn_in;
  assign id_insn_in = fs_insn_out;

  logic                   id_valid_out;
  logic                   id_ready_out;

  logic [EPOCH_WIDTH-1:0] id_epoch_out;

  logic [       XLEN-1:0] id_rs1_out;
  logic [       XLEN-1:0] id_rs2_out;
  logic [       XLEN-1:0] id_imm_out;

  logic [            4:0] id_rd_out;
  logic [ ADDR_WIDTH-1:0] id_pc_out;
  assign dbg_pc_id = id_pc_out;
  branch_type_e            id_pc_addr_type_out;
  logic                    id_pc_jump_en_out;

  wb_type_e                id_wb_type_out;
  logic                    id_mem_op_out;
  ls_type_e                id_mem_op_type_out;

  logic                    id_alu_en_out;
  alu_op_e                 id_alu_op_out;
  logic                    id_mdu_en_out;
  mdu_op_e                 id_mdu_op_out;

  alu_src1_e               id_arg_src_1_out;
  alu_src2_e               id_arg_src_2_out;

  logic         [     4:0] id_rd_in;
  logic         [XLEN-1:0] id_rd_val_in;
  logic                    id_rd_we_in;

  logic         [     2:0] id_dbg_used_regs_out[32];
  logic         [XLEN-1:0] id_dbg_x            [18];

  InsnDecodeStage #(
      .INSN_WIDTH(INSN_WIDTH),
      .XLEN(XLEN),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) decode_stage (
      .clk  (clk),
      .arstn(arstn),

      .halt_req_i(halt_req_in),
      .halt_ack_o(halt_ack_out_id),

      .flush_i(id_flush_in),

      .valid_i(id_valid_in),
      .ready_i(id_ready_in),

      .epoch_i(id_epoch_in),
      .pc_i(id_pc_in),
      .insn_i(id_insn_in),

      .valid_o(id_valid_out),
      .ready_o(id_ready_out),

      .epoch_o(id_epoch_out),

      .rs1_o(id_rs1_out),
      .rs2_o(id_rs2_out),
      .imm_o(id_imm_out),

      .rd_o(id_rd_out),
      .pc_o(id_pc_out),
      .pc_addr_type_o(id_pc_addr_type_out),
      .pc_jump_en_o(id_pc_jump_en_out),

      .wb_type_o(id_wb_type_out),
      .mem_op_o(id_mem_op_out),
      .mem_op_type_o(id_mem_op_type_out),

      .alu_en_o(id_alu_en_out),
      .alu_op_o(id_alu_op_out),
      .mdu_en_o(id_mdu_en_out),
      .mdu_op_o(id_mdu_op_out),

      .arg_src_1_o(id_arg_src_1_out),
      .arg_src_2_o(id_arg_src_2_out),

      .rd_i(id_rd_in),
      .rd_val_i(id_rd_val_in),
      .rd_we_i(id_rd_we_in),

      .dbg_used_regs_o(id_dbg_used_regs_out),
      .dbg_x_o(id_dbg_x)
  );

  assign dbg_x0  = id_dbg_x[0];
  assign dbg_x1  = id_dbg_x[1];
  assign dbg_x2  = id_dbg_x[2];
  assign dbg_x3  = id_dbg_x[3];
  assign dbg_x4  = id_dbg_x[4];
  assign dbg_x5  = id_dbg_x[5];
  assign dbg_x6  = id_dbg_x[6];
  assign dbg_x7  = id_dbg_x[7];
  assign dbg_x8  = id_dbg_x[8];
  assign dbg_x9  = id_dbg_x[9];
  assign dbg_x10 = id_dbg_x[10];
  assign dbg_x11 = id_dbg_x[11];
  assign dbg_x12 = id_dbg_x[12];
  assign dbg_x13 = id_dbg_x[13];
  assign dbg_x14 = id_dbg_x[14];
  assign dbg_x15 = id_dbg_x[15];
  assign dbg_x16 = id_dbg_x[16];
  assign dbg_x17 = id_dbg_x[17];

  // EXECUTE STAGE

  logic ex_valid_in;
  assign ex_valid_in = id_valid_out;
  logic ex_ready_in;
  assign id_ready_out = ex_ready_in;

  logic [XLEN-1:0] ex_rs1_in;
  assign ex_rs1_in = id_rs1_out;
  logic [XLEN-1:0] ex_rs2_in;
  assign ex_rs2_in = id_rs2_out;
  logic [XLEN-1:0] ex_imm_in;
  assign ex_imm_in = id_imm_out;

  logic [4:0] ex_rd_in;
  assign ex_rd_in = id_rd_out;
  logic [ADDR_WIDTH-1:0] ex_pc_in;
  assign ex_pc_in = id_pc_out;
  branch_type_e ex_pc_branch_type_in;
  assign ex_pc_branch_type_in = id_pc_addr_type_out;
  logic ex_pc_jump_en_in;
  assign ex_pc_jump_en_in = id_pc_jump_en_out;

  wb_type_e ex_wb_type_in;
  assign ex_wb_type_in = id_wb_type_out;
  logic ex_mem_op_in;
  assign ex_mem_op_in = id_mem_op_out;
  ls_type_e ex_mem_op_type_in;
  assign ex_mem_op_type_in = id_mem_op_type_out;

  logic ex_alu_en_in;
  assign ex_alu_en_in = id_alu_en_out;
  alu_op_e ex_alu_op_in;
  assign ex_alu_op_in = id_alu_op_out;

  logic ex_mdu_en_in;
  assign ex_mdu_en_in = id_mdu_en_out;
  mdu_op_e ex_mdu_op_in;
  assign ex_mdu_op_in = id_mdu_op_out;

  alu_src1_e ex_arg_src_1_in;
  assign ex_arg_src_1_in = id_arg_src_1_out;
  alu_src2_e ex_arg_src_2_in;
  assign ex_arg_src_2_in = id_arg_src_2_out;

  logic                  ex_valid_out;
  logic                  ex_ready_out;

  logic [      XLEN-1:0] ex_alu_out;
  logic [      XLEN-1:0] ex_rs2_out;
  logic [           4:0] ex_rd_out;

  logic [ADDR_WIDTH-1:0] ex_pc_out;
  assign dbg_pc_ex = ex_pc_out;

  logic [XLEN-1:0] ex_pc_branch_out;
  assign fs_pc_in = ex_pc_branch_out;
  logic ex_pc_we_out;
  assign fs_pc_we_in = ex_pc_we_out;
  assign id_flush_in = ex_pc_we_out;

  wb_type_e ex_wb_type_out;
  logic     ex_mem_op_out;
  ls_type_e ex_mem_op_type_out;

  ExecStage #(
      .XLEN(XLEN),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) exec_stage (
      .clk  (clk),
      .arstn(arstn),

      .halt_req_in (halt_req_in),
      .halt_ack_out(halt_ack_out_ex),

      .valid_in(ex_valid_in),
      .ready_in(ex_ready_in),

      .rs1_in(ex_rs1_in),
      .rs2_in(ex_rs2_in),
      .imm_in(ex_imm_in),

      .rd_in(ex_rd_in),
      .pc_in(ex_pc_in),
      .pc_branch_type_in(ex_pc_branch_type_in),
      .pc_jump_en_in(ex_pc_jump_en_in),

      .wb_type_in(ex_wb_type_in),
      .mem_op_in(ex_mem_op_in),
      .mem_op_type_in(ex_mem_op_type_in),

      .alu_op_in(ex_alu_op_in),
      .alu_src_1_in(ex_arg_src_1_in),
      .alu_src_2_in(ex_arg_src_2_in),

      .mdu_op_in(ex_mdu_op_in),

      .alu_en_in(ex_alu_en_in),
      .mdu_en_in(ex_mdu_en_in),

      .valid_out(ex_valid_out),
      .ready_out(ex_ready_out),

      .alu_out(ex_alu_out),
      .rs2_out(ex_rs2_out),
      .rd_out (ex_rd_out),

      .pc_out(ex_pc_out),
      .pc_branch_out(ex_pc_branch_out),
      .pc_we_out(ex_pc_we_out),

      .wb_type_out(ex_wb_type_out),
      .mem_op_out(ex_mem_op_out),
      .mem_op_type_out(ex_mem_op_type_out)
  );

  // MEMORY QUEUE

  logic                          lsu_req_in;
  logic                          lsu_ack_out;
  logic     [ADDR_WIDTH - 1 : 0] lsu_addr_in;
  ls_type_e                      lsu_mem_op_type_in;
  logic     [      XLEN - 1 : 0] lsu_write_data_in;
  logic     [      XLEN - 1 : 0] lsu_read_data_out;

  logic                          mem_mem_req_out;
  logic                          mem_mem_ack_in;

  logic     [    ADDR_WIDTH-1:0] mem_mem_addr_out;
  logic     [          XLEN-1:0] mem_mem_write_data_out;
  logic                          mem_mem_write_en_out;
  logic     [               3:0] mem_mem_write_mask_out;
  logic     [          XLEN-1:0] mem_mem_data_in;

  LoadStoreUnit #(
      .XLEN(XLEN),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) load_store_unit_i (
      .clk  (clk),
      .arstn(arstn),

      .cpu_req_in(lsu_req_in),
      .cpu_ack_out(lsu_ack_out),
      .cpu_addr_in(lsu_addr_in),
      .cpu_mem_op_type_in(lsu_mem_op_type_in),
      .cpu_write_data_in(lsu_write_data_in),
      .cpu_read_data_out(lsu_read_data_out),

      .mem_req_out(mem_mem_req_out),
      .mem_ack_in(mem_mem_ack_in),
      .mem_addr_out(mem_mem_addr_out),
      .mem_write_data_out(mem_mem_write_data_out),
      .mem_write_en_out(mem_mem_write_en_out),
      .mem_write_mask_out(mem_mem_write_mask_out),
      .mem_data_in(mem_mem_data_in)
  );

  logic                          mem_req_valid;
  logic                          mem_req_ready;
  logic     [ADDR_WIDTH - 1 : 0] mem_req_addr;
  ls_type_e                      mem_req_type;
  logic     [      XLEN - 1 : 0] mem_req_write_data;

  logic                          mem_resp_valid;
  logic                          mem_resp_ready;
  logic     [      XLEN - 1 : 0] mem_resp_data;

  MemReqSplitter #(
      .XLEN(XLEN),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) mem_queue_i (
      .clk  (clk),
      .rst_n(arstn),

      .req_valid_i(mem_req_valid),
      .req_ready_o(mem_req_ready),

      .addr_i(mem_req_addr),
      .op_type_i(mem_req_type),
      .write_data_i(mem_req_write_data),

      .resp_valid_o(mem_resp_valid),
      .resp_ready_i(mem_resp_ready),
      .read_data_o (mem_resp_data),

      .lsu_req_o(lsu_req_in),
      .lsu_ack_i(lsu_ack_out),
      .lsu_addr_o(lsu_addr_in),
      .lsu_mem_op_type_o(lsu_mem_op_type_in),
      .lsu_write_data_o(lsu_write_data_in),
      .lsu_read_data_i(lsu_read_data_out)
  );

  // MEMORY STAGE

  logic mem_valid_in;
  assign mem_valid_in = ex_valid_out;
  logic mem_ready_in;
  assign ex_ready_out = mem_ready_in;

  logic [XLEN-1:0] mem_alu_in;
  assign mem_alu_in = ex_alu_out;
  logic [XLEN-1:0] mem_rs2_in;
  assign mem_rs2_in = ex_rs2_out;
  logic [4:0] mem_rd_in;
  assign mem_rd_in = ex_rd_out;
  logic [ADDR_WIDTH-1:0] mem_pc_in;
  assign mem_pc_in = ex_pc_out;

  wb_type_e mem_wb_type_in;
  assign mem_wb_type_in = ex_wb_type_out;
  logic mem_mem_op_in;
  assign mem_mem_op_in = ex_mem_op_out;
  ls_type_e mem_mem_op_type_in;
  assign mem_mem_op_type_in = ex_mem_op_type_out;


  logic                      mem_valid_out;
  logic                      mem_ready_out;

  wb_type_e                  mem_wb_type_out;
  logic                      mem_mem_op_out;

  logic     [      XLEN-1:0] mem_alu_res_out;

  logic     [           4:0] mem_rd_out;
  logic     [ADDR_WIDTH-1:0] mem_pc_out;
  assign dbg_pc_mem = mem_pc_out;

  MemStage #(
      .XLEN(XLEN),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) mem_stage (
      .clk  (clk),
      .arstn(arstn),

      .halt_req_in (halt_req_in),
      .halt_ack_out(halt_ack_out_mem),

      .valid_in(mem_valid_in),
      .ready_in(mem_ready_in),

      .alu_in(mem_alu_in),
      .rs2_in(mem_rs2_in),
      .rd_in (mem_rd_in),
      .pc_in (mem_pc_in),

      .wb_type_in(mem_wb_type_in),
      .mem_op_in(mem_mem_op_in),
      .mem_op_type_in(mem_mem_op_type_in),

      .valid_out(mem_valid_out),
      .ready_out(mem_ready_out),

      .wb_type_out(mem_wb_type_out),
      .mem_op_out (mem_mem_op_out),

      .alu_res_out(mem_alu_res_out),

      .rd_out(mem_rd_out),
      .pc_out(mem_pc_out),

      .mem_req_valid_o(mem_req_valid),
      .mem_req_ready_i(mem_req_ready),
      .mem_req_addr_o(mem_req_addr),
      .mem_req_op_type_o(mem_req_type),
      .mem_req_write_data_o(mem_req_write_data)
  );

  // WRITEBACK STAGE

  logic wb_valid_in;
  assign wb_valid_in = mem_valid_out;
  logic wb_ready_in;
  assign mem_ready_out = wb_ready_in;

  wb_type_e wb_wb_type_in;
  assign wb_wb_type_in = mem_wb_type_out;
  logic wb_mem_op_in;
  assign wb_mem_op_in = mem_mem_op_out;

  logic [XLEN-1:0] wb_alu_res_in;
  assign wb_alu_res_in = mem_alu_res_out;

  logic [4:0] wb_rd_in;
  assign wb_rd_in = mem_rd_out;
  logic [ADDR_WIDTH-1:0] wb_pc_in;
  assign wb_pc_in = mem_pc_out;

  logic wb_reg_write_out;
  assign id_rd_we_in = wb_reg_write_out;
  logic [4:0] wb_rd_out;
  assign id_rd_in = wb_rd_out;
  logic [XLEN-1:0] wb_res_out;
  assign id_rd_val_in = wb_res_out;
  logic [ADDR_WIDTH-1:0] wb_pc_out;
  assign dbg_pc_wb = wb_pc_out;

  WriteBackStage #(
      .XLEN(XLEN),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) writeback_stage (
      .clk  (clk),
      .arstn(arstn),

      .valid_up_i(wb_valid_in),
      .ready_up_o(wb_ready_in),

      .wb_type_i(wb_wb_type_in),
      .mem_op_i (wb_mem_op_in),

      .alu_res_i(wb_alu_res_in),

      .rd_i(wb_rd_in),
      .pc_i(wb_pc_in),

      .reg_write_o(wb_reg_write_out),
      .rd_o(wb_rd_out),
      .res_o(wb_res_out),

      .mem_resp_valid_i(mem_resp_valid),
      .mem_resp_ready_o(mem_resp_ready),
      .mem_resp_read_data_i(mem_resp_data),

      .pc_o(wb_pc_out)
  );

  // HALT controls

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      halt_req_in <= 1'b0;
      halted <= 1'b0;
    end else begin
      if (halt_req) halt_req_in <= 1'b1;
      else if (resume_req) halt_req_in <= 1'b0;

      halted <= m_is_halted;
    end
  end

  // MEM connectivity

  always_comb begin
    if (m_is_halted) begin
      ram_addr = mem_debug_addr;
      ram_write_data = mem_debug_write_data;
      ram_we = mem_debug_wr_enable;
      ram_we_mask = mem_debug_wr_mask;
      ram_req = mem_debug_req;
      mem_debug_data = ram_data;
      mem_debug_ack = ram_ack;

      mem_mem_data_in = '0;
      mem_mem_ack_in = 1'b0;
    end else begin
      ram_addr = mem_mem_addr_out;
      ram_write_data = mem_mem_write_data_out;
      ram_we = mem_mem_write_en_out;
      ram_we_mask = mem_mem_write_mask_out;
      ram_req = mem_mem_req_out;
      mem_mem_data_in = ram_data;
      mem_mem_ack_in = ram_ack;

      mem_debug_data = '0;
      mem_debug_ack = 1'b0;
    end
  end

endmodule
