module RamArbiter2to1(
    input   logic           clk,
    input   logic           arstn,
    input   logic           clk_en,

    input   logic [31:0]    master1_addr,
    input   logic [31:0]    master1_write_data,
    input   logic           master1_wr_en,
    input   logic [3:0]     master1_wr_mask,
    input   logic           master1_req,
    output  logic [31:0]    master1_data,
    output  logic           master1_ack,

    input   logic [31:0]    master2_addr,
    input   logic [31:0]    master2_write_data,
    input   logic           master2_wr_en,
    input   logic [3:0]     master2_wr_mask,
    input   logic           master2_req,
    output  logic [31:0]    master2_data,
    output  logic           master2_ack,

    output  logic [31:0]    slave_addr,
    output  logic [31:0]    slave_write_data,
    output  logic           slave_wr_en,
    output  logic [3:0]     slave_wr_mask,
    output  logic           slave_req,
    input   logic [31:0]    slave_data,
    input   logic           slave_ack
);

localparam MASTER_1 = 1'b0;
localparam MASTER_2 = 1'b1;

logic                       selected_master;
logic                       next_master;

always_comb begin
    case ({ master1_req, master2_req })
    2'b00: next_master = selected_master;
    2'b01: next_master = MASTER_2;
    2'b10: next_master = MASTER_1;
    2'b11: next_master = slave_ack ? ~selected_master : selected_master;
    endcase
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        selected_master <= MASTER_1;
    end
    else if (clk_en) begin
        selected_master <= next_master;
    end
end

// Input MUX
always_comb begin
    if (next_master) begin
        slave_addr = master2_addr;
        slave_write_data = master2_write_data;
        slave_wr_en = master2_wr_en;
        slave_wr_mask = master2_wr_mask;
        slave_req = master2_req;
    end
    else begin
        slave_addr = master1_addr;
        slave_write_data = master1_write_data;
        slave_wr_en = master1_wr_en;
        slave_wr_mask = master1_wr_mask;
        slave_req = master1_req;
    end
end

// Output MUX
always_comb begin
    if (selected_master) begin
        master1_data = '0;
        master1_ack = '0;

        master2_data = slave_data;
        master2_ack = slave_ack;
    end
    else begin
        master1_data = slave_data;
        master1_ack = slave_ack;

        master2_data = '0;
        master2_ack = '0;
    end
end

endmodule