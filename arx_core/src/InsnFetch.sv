import arx_core_config_pkg::*;
import PipelineTypes::*;
import LoadStoreTypes::*;

module InsnFetch (
    input clk,
    input arstn,

    // HALT REQ
    input logic fetch_en_i,
    // -----------------

    // MEMORY INTERFACE
    mem_req_if.master mem_req,
    mem_resp_if.slave mem_resp,
    // -----------------

    // PC SETTING
    input logic redir_i,
    input logic [ADDR_WIDTH-1:0] redir_pc_i,
    input logic [EPOCH_WIDTH-1:0] epoch_i,
    // -----------------

    // OUT DATA
    output logic valid_out,
    input  logic ready_out,

    output if2id_t data_out,
    // -----------------

    output logic [ADDR_WIDTH-1:0] if1_pc_dbg_o,
    output logic if1_busy_o,
    output logic if2_busy_o
);

  logic redir_pending_ff;
  logic [ADDR_WIDTH-1:0] redir_pc_ff;
  logic [EPOCH_WIDTH-1:0] redir_epoch_ff;

  logic mem_req_vld_ff;
  logic mem_req_vld_next;

  logic [EPOCH_WIDTH-1:0] epoch_st1_ff;
  logic [EPOCH_WIDTH-1:0] epoch_st1_next;
  logic [EPOCH_WIDTH-1:0] epoch_st2_ff;

  logic [2:0] pc_incr_ff;

  logic [ADDR_WIDTH-1:0] pc_st1_ff;
  logic [ADDR_WIDTH-1:0] pc_st1_next;
  logic [ADDR_WIDTH-1:0] pc_st2_ff;

  logic valid_st1_ff;
  logic valid_st1;
  logic ready_st1;
  logic stall_st1;

  logic valid_st2_ff;
  logic valid_st2;
  logic ready_st2;
  logic stall_st2;

  // REDIR

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      redir_pending_ff <= 1'b0;
    end else begin
      if (ready_st1 & fetch_en_i) begin
        redir_pending_ff <= 1'b0;
      end else if (redir_i) begin
        redir_pending_ff <= 1'b1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (redir_i) begin
      redir_pc_ff <= redir_pc_i;
      redir_epoch_ff <= epoch_i;
    end
  end

  // IF1

  assign stall_st1 = mem_req_vld_next;
  assign ready_st1 = ~valid_st1_ff | (~stall_st1 & ready_st2);
  assign valid_st1 = valid_st1_ff && ~stall_st1;

  assign mem_req_vld_next = mem_req_vld_ff & ~mem_req.ready;

  assign pc_st1_next = redir_i ? redir_pc_i :
                       redir_pending_ff ? redir_pc_ff : (pc_st1_ff + pc_incr_ff);
  assign epoch_st1_next = redir_i ? epoch_i :
                          redir_pending_ff ? redir_epoch_ff : epoch_st1_ff;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      valid_st1_ff <= 1'b0;
    end else begin
      if (ready_st1) begin
        valid_st1_ff <= fetch_en_i;
      end
    end
  end

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      pc_incr_ff <= '0;
    end else begin
      if (ready_st1 & fetch_en_i) begin
        pc_incr_ff <= 3'd4;
      end
    end
  end

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      pc_st1_ff <= '0;
      epoch_st1_ff <= '0;
    end else begin
      if (ready_st1 & fetch_en_i) begin
        pc_st1_ff <= pc_st1_next;
        epoch_st1_ff <= epoch_st1_next;
      end
    end
  end

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      mem_req_vld_ff <= 1'b0;
    end else begin
      if (ready_st1) begin
        mem_req_vld_ff <= fetch_en_i;
      end else begin
        mem_req_vld_ff <= mem_req_vld_next;
      end
    end
  end

  assign mem_req.valid = mem_req_vld_ff;
  assign mem_req.addr = pc_st1_ff;
  assign mem_req.op = LOAD_WORD;
  assign mem_req.write_data = '0;

  // IF2

  assign stall_st2 = ~mem_resp.valid;
  assign ready_st2 = ~valid_st2_ff | (~stall_st2 & ready_out);
  assign valid_st2 = valid_st2_ff & ~stall_st2;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      valid_st2_ff <= 1'b0;
    end else begin
      if (ready_st2) begin
        valid_st2_ff <= valid_st1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (valid_st1 && ready_st2) begin
      pc_st2_ff <= pc_st1_ff;
      epoch_st2_ff <= epoch_st1_ff;
    end
  end

  assign valid_out = valid_st2;
  assign data_out.epoch = epoch_st2_ff;
  assign data_out.pc = pc_st2_ff;
  assign data_out.insn = mem_resp.data;

  assign mem_resp.ready = valid_st2_ff && ready_out;

  assign if1_pc_dbg_o = pc_st1_ff;
  assign if1_busy_o = valid_st1_ff;
  assign if2_busy_o = valid_st2_ff;

endmodule
