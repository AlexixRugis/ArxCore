module WriteBackStage
  import InstrTypes::*;
#(
    parameter int unsigned XLEN = 32,
    parameter int unsigned ADDR_WIDTH = 32
) (
    input logic clk,
    input logic arstn,

    // FROM MEM STAGE
    input  logic valid_up_i,
    output logic ready_up_o,

    input wb_type_e wb_type_i,
    input logic mem_op_i,

    input logic [XLEN-1:0] alu_res_i,

    input logic [           4:0] rd_i,
    input logic [ADDR_WIDTH-1:0] pc_i,

    // -----------

    // TO REG FILE
    output logic            reg_write_o,
    output logic [     4:0] rd_o,
    output logic [XLEN-1:0] res_o,

    // -----------

    // FROM LSU
    mem_resp_if.slave mem_resp,
    // -----------

    output logic [ADDR_WIDTH-1:0] pc_o
);

  logic                      valid_ff;

  wb_type_e                  wb_type_ff;
  logic                      mem_op_ff;
  logic     [      XLEN-1:0] alu_res_ff;
  logic     [           4:0] rd_ff;
  logic     [ADDR_WIDTH-1:0] pc_ff;

  // STAGE DATA TRANSFER

  assign ready_up_o = valid_ff && mem_op_ff ? mem_resp.valid : 1'b1;

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
      wb_type_ff <= wb_type_i;
      mem_op_ff <= mem_op_i;
      alu_res_ff <= alu_res_i;
      rd_ff <= rd_i;
      pc_ff <= pc_i;
    end
  end

  // -----------

  // OUT ASSIGNMENTS

  assign mem_resp.ready = valid_ff && mem_op_ff;
  assign pc_o             = pc_ff;

  always_comb begin
    if (valid_ff) begin
      reg_write_o = (wb_type_ff != WB_NONE) && (!mem_op_ff || mem_resp.valid);
      rd_o        = rd_ff;
      res_o       = (wb_type_ff == WB_MEM_RES) ? mem_resp.data : alu_res_ff;
    end else begin
      reg_write_o = 1'b0;
      rd_o        = '0;
      res_o       = '0;
    end
  end

  // -----------

endmodule
