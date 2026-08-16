module RamPort(
    input   logic           clk,
    input   logic           arstn,
    input   logic           clk_en,

    input   logic [31:0]    addr,
    input   logic [31:0]    write_data,
    input   logic           wr_en,
    input   logic [3:0]     wr_mask,
    input   logic           req,
    output  logic [31:0]    data,
    output  logic           ack,

    output  logic [31:0]    ram_addr,
    output  logic [31:0]    ram_write_data,
    output  logic           ram_wr_en,
    output  logic [3:0]     ram_byte_en,
    input   logic [31:0]    ram_data
);

enum logic [1:0] {
    S_IDLE,
    S_WAIT_DATA
} cur_state;

//assign ack = (cur_state == S_WAIT_DATA);

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        ack <= '0;
    end
    else if (clk_en) begin
        ack <= req;
    end
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        cur_state <= S_IDLE;
    end
    else if (clk_en) begin
        case (cur_state) 
        S_IDLE: begin
            if (req) begin
                cur_state <= S_WAIT_DATA;
            end
        end
        S_WAIT_DATA: begin
            // There is no wait. Latency is one clock cycle
            if (~req) begin
                cur_state <= S_IDLE;
            end
        end
        endcase
    end
end

assign ram_addr = addr;
assign ram_wr_en = req & wr_en;
assign ram_byte_en = wr_mask;
assign ram_write_data = write_data;

assign data = ram_data;

endmodule