import arx_core_config_pkg::*;
import PipelineTypes::*;
import LoadStoreTypes::*;
import InstrTypes::*;

module MemStage (
    input logic clk,
    input logic arstn,

    // FROM EXEC STAGE
    input  logic valid_in,
    output logic ready_in,

    input ex2mem_t data_in,
    // -----------

    // TO WRITE BACK STAGE
    output logic valid_out,
    input  logic ready_out,

    output mem2wb_t data_out,
    // -----------

    // TO LSU
    mem_req_if.master mem_req,

    output logic busy_o
);

  // STAGE REGISTERS

  logic    valid_ff;

  ex2mem_t data_ff;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      valid_ff <= 1'b0;
    end else begin
      if (valid_in & ready_in) begin
        valid_ff <= 1'b1;
        data_ff  <= data_in;
      end else if (valid_out & ready_out) begin
        valid_ff <= 1'b0;
      end
    end
  end

  // -----------

  // MEM CONTROL

  logic mem_req_vld_ff;
  logic mem_req_vld_next;

  assign mem_req_vld_next = mem_req_vld_ff && !mem_req.ready;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      mem_req_vld_ff <= 1'b0;
    end else begin
      if (valid_in && ready_in) begin
        mem_req_vld_ff <= data_in.mem_op;
      end else begin
        mem_req_vld_ff <= mem_req_vld_next;
      end
    end
  end

  always_comb begin
    mem_req.valid = mem_req_vld_ff;
    mem_req.addr = data_ff.alu_res;
    mem_req.op = data_ff.mem_op_type;
    mem_req.write_data = data_ff.rs2;
  end

  // -----------

  // OUT ASSIGNMENTS

  always_comb begin
    data_out.wb_type = data_ff.wb_type;
    data_out.mem_op = data_ff.mem_op;
    data_out.alu_res = data_ff.alu_res;
    data_out.rd = data_ff.rd;
    data_out.pc = data_ff.pc;
  end

  always_comb begin
    valid_out = valid_ff && !mem_req_vld_next;
    ready_in  = ~valid_ff | (valid_out & ready_out);
  end

  assign busy_o = valid_ff;

  // -----------

endmodule
