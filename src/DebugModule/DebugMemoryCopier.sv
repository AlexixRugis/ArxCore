module DebugMemoryCopier(
    input  logic            clk,
    input  logic            arstn,

    input  logic            copy_req,
    input  logic            copy_write,
    output logic            copy_ready,

    input  logic [7:0]      inp_packet_len,
    input  logic [7:0]      inp_packet_data,
    output logic [7:0]      inp_packet_data_addr,
    output logic            inp_packet_re,

    output logic [7:0]      out_packet_data,
    output logic [7:0]      out_packet_data_addr,
    output logic            out_packet_we,

    output logic [31:0]     data_addr,
    output logic [31:0]     data_write_data,
    output logic            data_wr_en,
    output logic [3:0]      data_wr_mask,
    output logic            data_req,
    input  logic [31:0]     data_data,
    input  logic            data_ack,

    output logic [7:0]      read_len
);

logic [31:0]    data_addr_internal;
logic [7:0]    data_write_data_internal;
logic [7:0]     data_data_internal;

ByteToWordAddrConverter addr_converter(
    .byte_addr(data_addr_internal),
    .write_data(data_write_data_internal),
    .word_addr(data_addr),
    .write_data_extended(data_write_data),
    .write_data_mask(data_wr_mask),
    .read_data_extended(data_data),
    .read_data(data_data_internal)
);

logic [31:0]    start_addr;

logic [7:0]     data_ptr;
logic [7:0]     next_data_ptr;
assign next_data_ptr = data_ptr + 8'b1;

enum logic [2:0] {
    S_IDLE = 3'b000,
    S_ADDR_0 = 3'b001,
    S_ADDR_1 = 3'b010,
    S_ADDR_2 = 3'b011,
    S_ADDR_3 = 3'b100,
    S_LEN = 3'b101,
    S_READ = 3'b110,
    S_WRITE = 3'b111
} cur_state, next_state;

always_comb begin
    next_state = cur_state;
    inp_packet_data_addr = 'x;
    inp_packet_re = 1'b0;

    data_addr_internal = 'x;
    data_write_data_internal = 'x;
    data_wr_en = 1'b0;
    data_req = 1'b0;

    out_packet_data = 'x;
    out_packet_data_addr = 'x;
    out_packet_we = 1'b0;

    case (cur_state) 
    S_IDLE: begin
        if (copy_req) begin
            inp_packet_data_addr = 8'h00;
            inp_packet_re = 1'b1;
            next_state = S_ADDR_0;
        end
    end
    S_ADDR_0: begin
        inp_packet_data_addr = 8'h01;
        inp_packet_re = 1'b1;
        next_state = S_ADDR_1;
    end
    S_ADDR_1: begin
        inp_packet_data_addr = 8'h02;
        inp_packet_re = 1'b1;
        next_state = S_ADDR_2;
    end
    S_ADDR_2: begin
        inp_packet_data_addr = 8'h03;
        inp_packet_re = 1'b1;
        next_state = S_ADDR_3;
    end
    S_ADDR_3: begin
        if (copy_write) begin
            if (inp_packet_len > 8'h04) begin
                inp_packet_data_addr = 8'h04;
                inp_packet_re = 1'b1;
                next_state = S_WRITE;
            end
            else begin
                next_state = S_IDLE;
            end
        end
        else begin
            inp_packet_data_addr = 8'h04;
            inp_packet_re = 1'b1;
            next_state = S_LEN;
        end
    end
    S_LEN: begin
        if (inp_packet_data != '0) begin
            next_state = S_READ;
        end
        else begin
            next_state = S_IDLE;
        end
    end
    S_WRITE: begin
        inp_packet_data_addr = data_ptr + 8'h04;
        inp_packet_re = 1'b1;
        data_req = 1'b1;
        data_wr_en = 1'b1;
        data_write_data_internal = inp_packet_data;
        data_addr_internal = 32'(start_addr + data_ptr);

        if (data_ack) begin
            data_req = 1'b0;

            if (data_ptr + 8'h01 + 8'h04 == inp_packet_len) begin
                next_state = S_IDLE;
            end
            else begin
                inp_packet_data_addr = next_data_ptr + 8'h04;
                inp_packet_re = 1'b1;
            end
        end
    end
    S_READ: begin
        data_req = 1'b1;
        data_addr_internal = 32'(start_addr + data_ptr);

        if (data_ack) begin
            data_req = 1'b0;

            out_packet_data_addr = data_ptr;
            out_packet_data = data_data_internal;
            out_packet_we = 1'b1;

            if (next_data_ptr == read_len) begin
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
    case(cur_state)
    S_ADDR_0: start_addr[31:24] <= inp_packet_data;
    S_ADDR_1: start_addr[23:16] <= inp_packet_data;
    S_ADDR_2: start_addr[15:8] <= inp_packet_data;
    S_ADDR_3: start_addr[7:0] <= inp_packet_data;
    S_LEN: read_len <= inp_packet_data;
    endcase
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        data_ptr <= '0;
    end
    else if (cur_state == S_IDLE) begin
        data_ptr <= '0;
    end
    else if (cur_state == S_READ & data_ack) begin
        data_ptr <= next_data_ptr;
    end
    else if (cur_state == S_WRITE & data_ack) begin
        data_ptr <= next_data_ptr;
    end
end

assign copy_ready = (cur_state != S_IDLE & next_state == S_IDLE);

endmodule