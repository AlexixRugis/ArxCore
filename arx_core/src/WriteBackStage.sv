module WriteBackStage #(
    parameter int unsigned XLEN = 32,
    parameter int unsigned ADDR_WIDTH = 32
) (
    input logic clk,
    input logic arstn,

    // FROM MEM STAGE
    input  logic valid_up_i,
    output logic ready_up_o,

    input logic reg_write_i,
    input logic mem_op_i,
    input logic mem_to_reg_i,

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
    input  logic mem_resp_valid_i,
    output logic mem_resp_ready_o,

    input logic [XLEN-1:0] mem_resp_read_data_i,

    // -----------
    output logic [ADDR_WIDTH-1:0] pc_o
);

  logic                  valid_ff;

  logic                  reg_we_ff;
  logic                  mem_op_ff;
  logic                  mem_to_reg_ff;
  logic [      XLEN-1:0] alu_res_ff;
  logic [           4:0] rd_ff;
  logic [ADDR_WIDTH-1:0] pc_ff;

  // STAGE DATA TRANSFER

  assign ready_up_o = valid_ff && mem_op_ff ? mem_resp_valid_i : 1'b1;

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
      reg_we_ff <= reg_write_i;
      mem_op_ff <= mem_op_i;
      mem_to_reg_ff <= mem_to_reg_i;
      alu_res_ff <= alu_res_i;
      rd_ff <= rd_i;
      pc_ff <= pc_i;
    end
  end

  // -----------

  // OUT ASSIGNMENTS

  assign mem_resp_ready_o = valid_ff && mem_op_ff;
  assign pc_o             = pc_ff;

  always_comb begin
    if (valid_ff) begin
      reg_write_o = reg_we_ff && (!mem_op_ff || mem_resp_valid_i);
      rd_o        = rd_ff;
      res_o       = mem_to_reg_ff ? mem_resp_read_data_i : alu_res_ff;
    end else begin
      reg_write_o = 1'b0;
      rd_o        = '0;
      res_o       = '0;
    end
  end

  // -----------

endmodule
