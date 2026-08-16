module PacketBuffer(
    input logic         clk,
    input logic         arstn,

    input logic [7:0]   status,
    input logic         status_we,
    input logic [7:0]   id,
    input logic         id_we,
    input logic [7:0]   len,
    input logic         len_we,
    input logic [7:0]   payload_addr,
    input logic [7:0]   payload,
    input logic         payload_we,

    input logic         send_req,
    output logic        send_ack,

    output logic [7:0]  send_data,
    output logic        send_valid,
    input  logic        send_ready
);

logic [7:0]     status_reg;
logic [7:0]     id_reg;
logic [7:0]     len_reg;

logic [7:0]     data_ptr;
logic [7:0]     next_data_ptr;
assign next_data_ptr = data_ptr + 8'b1;

(* ramstyle = "M10K" *)
logic [7:0]     payload_data_buf [0:255];

always_ff @(posedge clk) begin
    if (status_we) status_reg <= status;
    if (id_we) id_reg <= id;
    if (len_we) len_reg <= len;
    if (payload_we) payload_data_buf[payload_addr] <= payload;
end

enum logic [2:0] {
    S_IDLE = 3'b000,
    S_SEND_STATUS = 3'b001,
    S_SEND_ID = 3'b010,
    S_SEND_LEN = 3'b011,
    S_SEND_PAYLOAD = 3'b100
} cur_state, next_state;

always_comb begin
    next_state = cur_state;
    send_data = 'x;
    send_valid = '0;

    case (cur_state)
    S_IDLE: begin
        if (send_req) begin
            next_state = S_SEND_STATUS;
        end
    end
    S_SEND_STATUS: begin
        send_data = status_reg;
        send_valid = '1;
        
        if (send_ready) begin
            next_state = S_SEND_ID;
        end
    end
    S_SEND_ID: begin
        send_data = id_reg;
        send_valid = '1;
        
        if (send_ready) begin
            next_state = S_SEND_LEN;
        end
    end
    S_SEND_LEN: begin
        send_data = len_reg;
        send_valid = '1;
        
        if (send_ready) begin
            if (len_reg == 8'b0) begin
                next_state = S_IDLE;
            end
            else begin
                next_state = S_SEND_PAYLOAD;
            end
        end
    end
    S_SEND_PAYLOAD: begin
        send_data = payload_data_buf[data_ptr];
        send_valid = '1;

        if (send_ready) begin
            if (next_data_ptr == len_reg) begin
                next_state = S_IDLE;
            end
        end
    end
    endcase
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        cur_state <= S_IDLE;
    end
    else begin
        cur_state <= next_state;
    end
end

always_ff @(posedge clk) begin
    if (cur_state == S_IDLE & send_req) begin
        data_ptr <= '0;
    end
    if (cur_state == S_SEND_PAYLOAD & send_ready) begin
        data_ptr <= next_data_ptr;
    end
end

assign send_ack = (cur_state != S_IDLE & next_state == S_IDLE);

endmodule