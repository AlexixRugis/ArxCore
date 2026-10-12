import arx_core_config_pkg::*;

module redir_epoch_unit (
    input logic clk,
    input logic arstn,

    input logic redirect_i,
    input logic [ADDR_WIDTH-1:0] pc_i,

    output logic redirect_o,
    output logic [EPOCH_WIDTH-1:0] epoch_o,
    output logic [ADDR_WIDTH-1:0] pc_o
);

  logic [EPOCH_WIDTH-1:0] epoch_cnt_ff;
  logic [EPOCH_WIDTH-1:0] epoch_cnt_next;

  assign epoch_cnt_next = epoch_cnt_ff + 1'b1;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      epoch_cnt_ff <= '0;
    end else begin
      if (redirect_i) begin
        epoch_cnt_ff <= epoch_cnt_next;
      end
    end
  end

  assign redirect_o = redirect_i;
  assign epoch_o = epoch_cnt_next;
  assign pc_o = pc_i;

endmodule
