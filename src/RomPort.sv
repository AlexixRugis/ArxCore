module RomPort(
    input   logic           clk,
    input   logic           arstn,
    input   logic           clk_en,

    input   logic [31:0]    addr,
    input   logic           req,
    output  logic [31:0]    data,
    output  logic           ack,

    output  logic [31:0]    rom_addr,
    input   logic [31:0]    rom_data
);

enum logic [1:0] {
    S_IDLE,
    S_WAIT_DATA
} cur_state;

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

assign rom_addr = addr;
assign data = rom_data;
assign ack = cur_state == S_WAIT_DATA;

endmodule