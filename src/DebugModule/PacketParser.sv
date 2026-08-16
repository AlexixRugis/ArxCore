module PacketParser(
    input   logic       clk,
    input   logic       arstn,

    input   logic       input_valid,
    output  logic       input_ready,
    input   logic       input_error,
    input   logic [7:0]  input_byte,

    output  logic       res_valid,
    input   logic       res_ready,
    output  logic       res_error,
    output  logic [7:0] res_cmd,
    output  logic [7:0] res_id,
    output  logic [7:0] res_len,
    
    output  logic [7:0] res_data,
    input   logic [7:0] res_data_addr,
    input   logic       res_data_re
);

enum logic [2:0] {
    S_WAIT_CMD      = 3'b000,
    S_WAIT_ID       = 3'b001,
    S_WAIT_LEN      = 3'b010,
    S_WAIT_DATA     = 3'b011,
    S_WAIT_READY    = 3'b100
} cur_state, next_state;

(* ramstyle = "M10K" *)
logic [7:0]     res_data_buf [0:255];

logic [7:0]     data_ptr;
logic [7:0]     next_data_ptr;
assign next_data_ptr = data_ptr + 8'b1;

always_comb begin
    next_state = cur_state;
    
    case (cur_state)
    S_WAIT_CMD: begin
        if (input_valid) begin
            next_state = S_WAIT_ID;
        end
    end
    S_WAIT_ID: begin
        if (input_valid) begin
            next_state = S_WAIT_LEN;
        end
    end
    S_WAIT_LEN: begin
        if (input_valid) begin

            if (input_byte == 8'b0) begin
                next_state = S_WAIT_READY;
            end
            else begin
                next_state = S_WAIT_DATA;
            end
        end
    end
    S_WAIT_DATA: begin
        if (input_valid) begin            
            if (next_data_ptr == res_len) begin
                next_state = S_WAIT_READY;
            end
        end
    end
    S_WAIT_READY: begin
        if (res_ready) begin
            next_state = S_WAIT_CMD;
        end
    end
    endcase

    if (cur_state != S_WAIT_READY & input_valid & input_error) begin
        next_state = S_WAIT_READY;
    end
end

assign input_ready = 1'b1;
assign res_valid = cur_state == S_WAIT_READY;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        cur_state <= S_WAIT_CMD;
    end
    else begin
        cur_state <= next_state;
    end
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        data_ptr <= '0;
    end
    else begin
        if (input_valid) begin
            case(cur_state)
            S_WAIT_CMD:     res_cmd <= input_byte;
            S_WAIT_ID:      res_id <= input_byte;
            S_WAIT_LEN: begin
                            res_len <= input_byte;
                            data_ptr <= '0;
            end
            S_WAIT_DATA: begin
                res_data_buf[data_ptr] <= input_byte;
                data_ptr <= next_data_ptr;
            end
            endcase

            if (cur_state != S_WAIT_READY) begin
                res_error <= input_error;
            end
        end

        if (cur_state == S_WAIT_READY & res_ready) begin
            res_error <= '0;
        end
    end
end

always_ff @(posedge clk) begin
    if (res_data_re) begin
        res_data <= res_data_buf[res_data_addr];
    end
end

endmodule