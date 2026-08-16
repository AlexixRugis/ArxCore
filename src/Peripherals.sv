module Peripherals(
	input   logic                   clk,
    input   logic                   clk_en,
    input   logic                   arstn,

	input   logic [31:0]            address,
	input   logic [31:0]            data,
	input   logic                   write_en,
    input   logic [3:0]             write_mask,
	output  logic [31:0]            q,
    output  logic [31:0]            out_1
);

logic [31:0] timer_value;

Timer timer(
    .clk(clk),
    .clk_en(clk_en),
    .arstn(arstn),

    .value(timer_value)
);

always_comb begin
    case(address)
    32'd0: q = out_1;
    32'd4: q = timer_value;
    default: q = '0;
    endcase
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        out_1 <= 32'b0;
    end
    else if (clk_en) begin
        if (write_en & address == 32'b0) begin
            if (write_mask[0]) out_1[7:0] <= data[7:0];
            if (write_mask[1]) out_1[15:8] <= data[15:8];
            if (write_mask[2]) out_1[23:16] <= data[23:16];
            if (write_mask[3]) out_1[31:24] <= data[31:24];
        end
    end
end

endmodule