import arx_core_config_pkg::*;
import PipelineTypes::*;
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

    output logic [31:0] dbg_pc_fs1,
    output logic dbg_vld_fs1,
    output logic [31:0] dbg_pc_fs2,
    output logic dbg_vld_fs2,
    output logic [31:0] dbg_pc_id,
    output logic dbg_vld_id,
    output logic [31:0] dbg_pc_ex,
    output logic dbg_vld_ex,
    output logic [31:0] dbg_pc_mem,
    output logic dbg_vld_mem,
    output logic [31:0] dbg_pc_wb,
    output logic dbg_vld_wb
);

  logic fetch_en_ff;

  logic all_busy;
  logic if1_busy;
  logic if2_busy;
  logic id_busy;
  logic ex_busy;
  logic mem_busy;
  logic wb_busy;

  logic if2id_valid;
  logic if2id_ready;
  logic id2ex_valid;
  logic id2ex_ready;
  logic ex2mem_valid;
  logic ex2mem_ready;
  logic mem2wb_valid;
  logic mem2wb_ready;

  logic redirect_req;
  logic [ADDR_WIDTH-1:0] redirect_pc_req;

  logic redirect_resp;
  logic [ADDR_WIDTH-1:0] redirect_pc_resp;
  logic [EPOCH_WIDTH-1:0] redirect_epoch_resp;

  redir_epoch_unit i_redir_epoch_unit (
      .clk(clk),
      .arstn(arstn),
      .redirect_i(redirect_req),
      .pc_i(redirect_pc_req),

      .redirect_o(redirect_resp),
      .epoch_o(redirect_epoch_resp),
      .pc_o(redirect_pc_resp)
  );

  // FETCH STAGE

  mem_req_if #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .XLEN(XLEN)
  ) i_prog_mem_req ();

  mem_resp_if #(.XLEN(XLEN)) i_prog_mem_resp ();

  MemReqSplitter #(
      .XLEN(XLEN),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) i_prog_mem_queue (
      .clk  (clk),
      .rst_n(arstn),

      .req (i_prog_mem_req),
      .resp(i_prog_mem_resp),

      .lsu_req_o(rom_req),
      .lsu_ack_i(rom_ack),
      .lsu_addr_o(rom_addr),
      //.lsu_mem_op_type_o(),
      //.lsu_write_data_o(),
      .lsu_read_data_i(rom_data)
  );

  logic   [31:0] fs_pc_in;
  logic          fs_pc_we_in;

  if2id_t        if2id_data;
  assign dbg_pc_fs2 = if2id_data.pc;

  InsnFetch i_fetch (
      .clk  (clk),
      .arstn(arstn),

      .fetch_en_i(fetch_en_ff),

      // MEMORY INTERFACE
      .mem_req (i_prog_mem_req),
      .mem_resp(i_prog_mem_resp),
      // -----------------

      // PC SETTING
      .redir_i(redirect_resp),
      .redir_pc_i(redirect_pc_resp),
      .epoch_i(redirect_epoch_resp),
      // -----------------

      // OUT DATA
      .valid_out(if2id_valid),
      .ready_out(if2id_ready),

      .data_out(if2id_data),
      // -----------------

      .if1_pc_dbg_o(dbg_pc_fs1),
      .if1_busy_o  (if1_busy),
      .if2_busy_o  (if2_busy)
  );

  // -----------

  id2ex_t id2ex_data;
  assign dbg_pc_id = id2ex_data.pc;

  reg_wb_t            reg_wb;

  logic    [     2:0] id_dbg_used_regs_out[32];
  logic    [XLEN-1:0] id_dbg_x            [18];

  InsnDecodeStage decode_stage (
      .clk  (clk),
      .arstn(arstn),

      .redir_i(redirect_resp),
      .redir_epoch_i(redirect_epoch_resp),

      .valid_i(if2id_valid),
      .ready_i(if2id_ready),

      .data_i(if2id_data),

      .valid_o(id2ex_valid),
      .ready_o(id2ex_ready),

      .data_o(id2ex_data),

      .reg_wb_i(reg_wb),

      .dbg_used_regs_o(id_dbg_used_regs_out),
      .dbg_x_o(id_dbg_x),

      .busy_o(id_busy)
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

  ex2mem_t ex2mem_data;
  assign dbg_pc_ex = ex2mem_data.pc;

  ExecStage exec_stage (
      .clk  (clk),
      .arstn(arstn),

      .valid_in(id2ex_valid),
      .ready_in(id2ex_ready),

      .data_in(id2ex_data),

      .valid_out(ex2mem_valid),
      .ready_out(ex2mem_ready),

      .data_out(ex2mem_data),

      .redir_o(redirect_req),
      .redir_pc_o(redirect_pc_req),

      .busy_o(ex_busy)
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

  mem_req_if #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .XLEN(XLEN)
  ) i_data_mem_req ();

  mem_resp_if #(.XLEN(XLEN)) i_data_mem_resp ();

  MemReqSplitter #(
      .XLEN(XLEN),
      .ADDR_WIDTH(ADDR_WIDTH)
  ) mem_queue_i (
      .clk  (clk),
      .rst_n(arstn),

      .req (i_data_mem_req),
      .resp(i_data_mem_resp),

      .lsu_req_o(lsu_req_in),
      .lsu_ack_i(lsu_ack_out),
      .lsu_addr_o(lsu_addr_in),
      .lsu_mem_op_type_o(lsu_mem_op_type_in),
      .lsu_write_data_o(lsu_write_data_in),
      .lsu_read_data_i(lsu_read_data_out)
  );

  // MEMORY STAGE

  mem2wb_t mem2wb_data;
  assign dbg_pc_mem = mem2wb_data.pc;

  MemStage mem_stage (
      .clk  (clk),
      .arstn(arstn),

      .valid_in(ex2mem_valid),
      .ready_in(ex2mem_ready),

      .data_in(ex2mem_data),

      .valid_out(mem2wb_valid),
      .ready_out(mem2wb_ready),

      .data_out(mem2wb_data),

      .mem_req(i_data_mem_req),

      .busy_o(mem_busy)
  );

  // WRITEBACK STAGE

  logic [ADDR_WIDTH-1:0] wb_pc_out;
  assign dbg_pc_wb = wb_pc_out;

  WriteBackStage writeback_stage (
      .clk  (clk),
      .arstn(arstn),

      .valid_up_i(mem2wb_valid),
      .ready_up_o(mem2wb_ready),

      .data_i(mem2wb_data),

      .reg_wb_o(reg_wb),

      .mem_resp(i_data_mem_resp),

      .pc_o(wb_pc_out),

      .busy_o(wb_busy)
  );

  // HALT controls

  assign all_busy = if1_busy | if2_busy | id_busy | ex_busy | mem_busy | wb_busy;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      fetch_en_ff <= 1'b0;
    end else begin
      if (halt_req) fetch_en_ff <= 1'b0;
      else if (resume_req) fetch_en_ff <= 1'b1;

      halted <= ~all_busy;
    end
  end

  // MEM connectivity

  always_comb begin
    if (~fetch_en_ff && ~all_busy) begin
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

  assign dbg_vld_fs1  = if1_busy;
  assign dbg_vld_fs2  = if2_busy;
  assign dbg_vld_id  = id_busy;
  assign dbg_vld_ex  = ex_busy;
  assign dbg_vld_mem = mem_busy;
  assign dbg_vld_wb  = wb_busy;

endmodule
