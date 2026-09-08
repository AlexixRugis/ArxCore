module ArxToAvalon (
    input logic clk,
    input logic arstn,
    input logic clk_en,

    input  logic [31:0] addr,
    input  logic [31:0] write_data,
    input  logic        wr_en,
    input  logic [ 3:0] wr_mask,
    input  logic        req,
    output logic [31:0] data,
    output logic        ack,

    output logic [29:0] avalon_addr,
    output logic [31:0] avalon_write_data,
    output logic [3:0] avalon_write_mask,
    input logic [31:0] avalon_read_data,
    input logic avalon_ack,
    output logic avalon_read,
    output logic avalon_write
);

  assign avalon_addr = addr[29:0];
  assign avalon_write_data = write_data;
  assign avalon_write_mask = wr_mask;

  assign avalon_read = clk_en && req && ~wr_en;
  assign avalon_write = clk_en && req && wr_en;

  logic ack_ff;
  logic [31:0] read_data_ff;

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        ack_ff <= 1'b0;
    end
    else begin
        if (clk_en) begin
            ack_ff <= avalon_ack;
        end
    end
  end

  always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        read_data_ff <= 'b0;
    end
    else begin
        if (clk_en) begin
            if (avalon_ack && avalon_read) begin
                read_data_ff <= avalon_read_data;
            end
        end
    end
  end

  assign ack = ack_ff;
  assign data = read_data_ff;

endmodule
