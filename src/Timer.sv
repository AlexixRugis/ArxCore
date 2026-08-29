module Timer (
    input logic clk,
    input logic clk_en,
    input logic arstn,

    output logic [31:0] value
);

  logic [31:0] cnt_ff;
  logic [5:0] cnt_50_ff;
  logic cnt_50_overflow;

  assign cnt_50_overflow = (cnt_50_ff == 6'd49);

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      cnt_50_ff <= '0;
    end else begin
      if (clk_en) begin
        cnt_50_ff <= cnt_50_overflow ? 6'd0 : cnt_50_ff + 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
      cnt_ff <= '0;
    end else begin
      if (clk_en && cnt_50_overflow) begin
        cnt_ff <= cnt_ff + 1'b1;
      end
    end
  end

  assign value = cnt_ff;

endmodule
