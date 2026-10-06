module RegisterFile #(
    parameter int unsigned XLEN = 32
) (
    input logic clk,
    input logic arstn,

    input  logic [     4:0] rs_1,
    output logic [XLEN-1:0] out_1,
    input  logic [     4:0] rs_2,
    output logic [XLEN-1:0] out_2,

    input logic [     4:0] rd,
    input logic            write_en,
    input logic [XLEN-1:0] write_data,

    output logic [XLEN-1:0] dbg_x[18]
);

  logic [XLEN-1:0] regs[32];

  assign out_1 = regs[rs_1];
  assign out_2 = regs[rs_2];

  always @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      for (int i = 0; i < 32; i++) begin
        regs[i] <= '0;
      end
    end else if (write_en & |rd) begin
      regs[rd] <= write_data;
    end
  end

  always_comb begin
    for (int i = 0; i < 18; i = i + 1) begin
      dbg_x[i] = regs[i];
    end
  end

endmodule
