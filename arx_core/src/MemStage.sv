module MemStage
  import LoadStoreTypes::*;
  import InstrTypes::*;
#(
    parameter int unsigned XLEN = 32,
    parameter int unsigned ADDR_WIDTH = 32
) (
    input logic clk,
    input logic arstn,

    // HALT REQ
    input  logic halt_req_in,
    output logic halt_ack_out,
    // -----------

    // FROM EXEC STAGE
    input  logic valid_in,
    output logic ready_in,

    input logic [XLEN-1:0] alu_in,
    input logic [XLEN-1:0] rs2_in,
    input logic [     4:0] rd_in,

    input logic [ADDR_WIDTH-1:0] pc_in,

    input wb_type_e wb_type_in,
    input logic     mem_op_in,
    input ls_type_e mem_op_type_in,

    // -----------

    // TO WRITE BACK STAGE
    output logic valid_out,
    input  logic ready_out,

    output wb_type_e wb_type_out,
    output logic mem_op_out,

    output logic [XLEN-1:0] alu_res_out,

    output logic [           4:0] rd_out,
    output logic [ADDR_WIDTH-1:0] pc_out,
    // -----------

    // TO LSU
    mem_req_if.master mem_req
);

  // STAGE REGISTERS

  logic                      valid_ff;

  logic     [ADDR_WIDTH-1:0] pc_ff;

  logic     [      XLEN-1:0] alu_res_ff;
  logic     [      XLEN-1:0] rs2_ff;
  logic     [           4:0] rd_ff;

  wb_type_e                  wb_type_ff;
  logic                      mem_op_ff;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      valid_ff <= 1'b0;
    end else begin
      if (valid_in & ready_in) begin
        valid_ff <= 1'b1;

        pc_ff <= pc_in;

        alu_res_ff <= alu_in;
        rs2_ff <= rs2_in;
        rd_ff <= rd_in;

        wb_type_ff <= wb_type_in;
        mem_op_ff <= mem_op_in;
      end else if (valid_out & ready_out) begin
        valid_ff <= 1'b0;
      end
    end
  end

  // -----------

  // MEM CONTROL

  logic mem_req_vld_ff;
  logic mem_req_vld_next;

  ls_type_e mem_op_type_in_ff;

  assign mem_req_vld_next = mem_req_vld_ff && !mem_req.ready;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      mem_req_vld_ff <= 1'b0;
    end else begin
      if (valid_in && ready_in) begin
        mem_req_vld_ff <= mem_op_in;
      end else begin
        mem_req_vld_ff <= mem_req_vld_next;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (valid_in && ready_in) begin
      mem_op_type_in_ff <= mem_op_type_in;
    end
  end

  always_comb begin
    mem_req.valid = mem_req_vld_ff;
    mem_req.addr = alu_res_ff;
    mem_req.op = mem_op_type_in_ff;
    mem_req.write_data = rs2_ff;
  end

  // -----------

  // OUT ASSIGNMENTS

  always_comb begin
    halt_ack_out = halt_req_in && (!mem_req_vld_ff || !valid_ff);

    wb_type_out = wb_type_ff;
    mem_op_out = mem_op_ff;
    alu_res_out = alu_res_ff;
    rd_out = rd_ff;
    pc_out = pc_ff;
  end

  always_comb begin
    if (~halt_req_in) begin
      valid_out = valid_ff && !mem_req_vld_next;
      ready_in  = ~valid_ff | (valid_out & ready_out);
    end else begin
      valid_out = 1'b0;
      ready_in  = 1'b0;
    end
  end

  // -----------

endmodule
