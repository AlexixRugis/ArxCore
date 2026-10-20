module MemReqJoiner
  import LoadStoreTypes::*;
#(
    parameter int unsigned XLEN = 32,
    parameter int unsigned ADDR_WIDTH = 32
) (
    input logic clk,
    input logic rst_n,

    mem_req_if.master req,
    mem_resp_if.slave resp,

    input  logic                  lsu_req_i,
    output logic                  lsu_ack_o,

    input  logic [ADDR_WIDTH-1:0] lsu_addr_i,
    input  logic                  lsu_wr_en_i,
    input  logic [           3:0] lsu_wr_mask_i,
    input  logic [XLEN-1:0]       lsu_write_data_i,
    output logic [XLEN-1:0]       lsu_read_data_o
);

  logic req_pending_ff;

  logic req_handshake;
  logic resp_handshake;

  ls_type_e req_op;
  logic [ADDR_WIDTH-1:0] req_addr;

  always_comb begin
    if (!lsu_wr_en_i) begin
      req_op = LOAD_WORD;
    end else begin
      case (lsu_wr_mask_i)
        4'b1111: req_op = STORE_WORD;
        4'b0011, 4'b1100: req_op = STORE_HALFWORD;
        4'b0001, 4'b0010, 4'b0100, 4'b1000: req_op = STORE_BYTE;
        default: req_op = STORE_WORD;
      endcase
    end
  end

  always_comb begin
    req_addr = lsu_addr_i;

    if (lsu_wr_en_i) begin
      case (lsu_wr_mask_i)
        4'b0001: req_addr[1:0] = 2'b00;
        4'b0010: req_addr[1:0] = 2'b01;
        4'b0100: req_addr[1:0] = 2'b10;
        4'b1000: req_addr[1:0] = 2'b11;
        4'b0011: begin
          req_addr[1] = 1'b0;
          req_addr[0] = 1'b0;
        end
        4'b1100: begin
          req_addr[1] = 1'b1;
          req_addr[0] = 1'b0;
        end
        4'b1111: req_addr[1:0] = 2'b00;
        default: ;
      endcase
    end
  end

  assign req.valid = lsu_req_i && !req_pending_ff;
  assign req.addr = req_addr;
  assign req.op = req_op;
  assign req.write_data = lsu_write_data_i;

  assign req_handshake = req.valid && req.ready;

  assign resp.ready = req_pending_ff;
  assign resp_handshake = resp.valid && resp.ready;

  assign lsu_ack_o = resp_handshake;
  assign lsu_read_data_o = resp.data;

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      req_pending_ff <= 1'b0;
    end else begin
      req_pending_ff <= (req_pending_ff && !resp_handshake) || req_handshake;
    end
  end

endmodule
