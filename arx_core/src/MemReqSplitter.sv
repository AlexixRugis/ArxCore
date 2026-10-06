module MemReqSplitter
  import LoadStoreTypes::*;
#(
    parameter int unsigned XLEN = 32,
    parameter int unsigned ADDR_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    // FROM MEM STAGE
    mem_req_if.slave req,
    // -----------

    // TO WB STAGE
    mem_resp_if.master resp,
    // -----------

    // TO LSU
    output logic lsu_req_o,
    input  logic lsu_ack_i,

    output logic     [ADDR_WIDTH-1:0] lsu_addr_o,
    output ls_type_e                  lsu_mem_op_type_o,
    output logic     [      XLEN-1:0] lsu_write_data_o,
    input  logic     [      XLEN-1:0] lsu_read_data_i
    // -----------
);

  logic in_handshake;
  logic out_handshake;

  logic req_vld_ff;
  logic req_vld_next;
  logic [ADDR_WIDTH-1:0] req_addr_ff;
  ls_type_e req_op_type_ff;
  logic [XLEN-1:0] req_write_data_ff;

  logic out_buffer_vld_ff;
  logic out_buffer_vld_next;
  logic [XLEN-1:0] out_buffer_ff;

  // REQUEST LOGIC BEGIN

  assign in_handshake      = req.valid && req.ready;

  assign lsu_addr_o        = in_handshake ? req.addr : req_addr_ff;
  assign lsu_mem_op_type_o = in_handshake ? req.op : req_op_type_ff;
  assign lsu_write_data_o  = in_handshake ? req.write_data : req_write_data_ff;

  assign req_vld_next      = in_handshake || (req_vld_ff && !lsu_ack_i);

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      req_vld_ff <= 1'b0;
    end else begin
      req_vld_ff <= req_vld_next;
    end
  end

  always_ff @(posedge clk) begin
    if (in_handshake) begin
      req_addr_ff <= req.addr;
      req_op_type_ff <= req.op;
      req_write_data_ff <= req.write_data;
    end
  end

  assign req.ready = (!req_vld_ff || lsu_ack_i) && ~out_buffer_vld_next;
  assign lsu_req_o = req_vld_next;

  // REQUEST LOGIC END

  // RESPONSE LOGIC BEGIN

  assign out_handshake = resp.valid && resp.ready;

  assign out_buffer_vld_next = !out_handshake && (lsu_ack_i || out_buffer_vld_ff);

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      out_buffer_vld_ff <= 1'b0;
    end else begin
      out_buffer_vld_ff <= out_buffer_vld_next;
    end
  end

  always_ff @(posedge clk) begin
    if (lsu_ack_i) begin
      out_buffer_ff <= lsu_read_data_i;
    end
  end

  assign resp.valid = out_buffer_vld_ff || lsu_ack_i;
  assign resp.data  = out_buffer_vld_ff ? out_buffer_ff : lsu_read_data_i;

  // RESPONSE LOGIC END

endmodule
