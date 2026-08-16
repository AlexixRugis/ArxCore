module Timer(
    input   logic                   clk,
    input   logic                   clk_en,
    input   logic                   arstn,

    output  logic [31:0]            value
);

logic [31:0]                        cnt;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        cnt <= '0;
    end
    else begin
        cnt <= cnt + 1'b1;
    end
end

assign value = cnt;

endmodule