import arx_core_config_pkg::*;
import PipelineTypes::*;
import InstrTypes::*;

module WriteBackStage (
    input logic clk,
    input logic arstn,

    // FROM MEM STAGE
    input  logic valid_up_i,
    output logic ready_up_o,

    input mem2wb_t data_i,
    // -----------

    // TO REG FILE
    output reg_wb_t reg_wb_o,
    // -----------

    // FROM LSU
    mem_resp_if.slave mem_resp,
    // -----------

    output logic [ADDR_WIDTH-1:0] pc_o
);

  logic    valid_ff;
  mem2wb_t data_ff;

  // STAGE DATA TRANSFER

  assign ready_up_o = valid_ff && data_ff.mem_op ? mem_resp.valid : 1'b1;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      valid_ff <= 1'b0;
    end else begin
      if (ready_up_o) begin
        valid_ff <= valid_up_i;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (ready_up_o) begin
      data_ff <= data_i;
    end
  end

  // -----------

  // OUT ASSIGNMENTS

  assign mem_resp.ready = valid_ff && data_ff.mem_op;
  assign pc_o           = data_ff.pc;

  always_comb begin
    if (valid_ff) begin
      reg_wb_o.we   = (data_ff.wb_type != WB_NONE) && (!data_ff.mem_op || mem_resp.valid);
      reg_wb_o.rd   = data_ff.rd;
      reg_wb_o.data = (data_ff.wb_type == WB_MEM_RES) ? mem_resp.data : data_ff.alu_res;
    end else begin
      reg_wb_o.we   = 1'b0;
      reg_wb_o.rd   = '0;
      reg_wb_o.data = '0;
    end
  end

  // -----------

endmodule
