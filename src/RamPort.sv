module RamPort
  import LoadStoreTypes::*;
(
    input logic clk,
    input logic arstn,
    input logic clk_en,

    mem_req_if.slave   req,
    mem_resp_if.master resp,

    output logic [31:0] ram_addr,
    output logic [31:0] ram_write_data,
    output logic        ram_wr_en,
    output logic [ 3:0] ram_byte_en,
    input  logic [31:0] ram_data
);

  logic in_handshake;

  logic op_valid_ff;

  logic [31:0] write_data_word;
  logic [31:0] write_data_halfword;
  logic [31:0] write_data_byte;

  logic [31:0] mem_addr_ff;
  logic [31:0] mem_addr_next;

  assign in_handshake = req.valid && req.ready;

  assign mem_addr_next = in_handshake ? req.addr : mem_addr_ff;
  assign write_data_word = req.write_data;
  assign write_data_halfword = {2{req.write_data[15:0]}};
  assign write_data_byte = {4{req.write_data[7:0]}};

  assign req.ready = clk_en && (!op_valid_ff || resp.ready);
  assign ram_addr = {mem_addr_next[31:2], 2'b00};

  always_comb begin
    case (req.op)
      STORE_WORD: begin
        ram_wr_en = in_handshake;
        ram_byte_en = 4'b1111;
        ram_write_data = write_data_word;
      end
      STORE_HALFWORD: begin
        ram_wr_en = in_handshake;
        ram_byte_en = mem_addr_next[1] ? 4'b1100 : 4'b0011;
        ram_write_data = write_data_halfword;
      end
      STORE_BYTE: begin
        ram_wr_en = in_handshake;
        ram_byte_en = mem_addr_next[1] ?
          (mem_addr_next[0] ? 4'b1000 : 4'b0100) :
          (mem_addr_next[0] ? 4'b0010 : 4'b0001);
        ram_write_data = write_data_byte;
      end
      default: begin
        ram_wr_en = 1'b0;
        ram_byte_en = 4'b0000;
        ram_write_data = '0;
      end
    endcase
  end

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      op_valid_ff <= 1'b0;
    end else begin
      if (req.ready) begin
        op_valid_ff <= req.valid;
      end
    end
  end

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      mem_addr_ff <= '0;
    end else begin
      mem_addr_ff <= mem_addr_next;
    end
  end

  assign resp.data  = ram_data;
  assign resp.valid = op_valid_ff;
endmodule
