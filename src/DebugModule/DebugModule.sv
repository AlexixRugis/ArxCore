module DebugModule #(
    parameter TIMEOUT_TICKS = 1000000
) (
    input  logic             clk,
    input  logic             arstn,

    input  logic       input_valid,
    output logic       input_ready,
    input  logic       input_error,
    input  logic [7:0]  input_byte,

    output logic [7:0]  send_byte,
    output logic        send_valid,
    input  logic        send_ready,

    output logic        halt_req,
    output logic        resume_req,
    input  logic        is_halted,

    output logic [31:0]    prog_addr,
    output logic [31:0]    prog_write_data,
    output logic           prog_wr_en,
    output logic [3:0]     prog_wr_mask,
    output logic           prog_req,
    input  logic [31:0]    prog_data,
    input  logic           prog_ack,

    output logic [31:0]    data_addr,
    output logic [31:0]    data_write_data,
    output logic           data_wr_en,
    output logic [3:0]     data_wr_mask,
    output logic           data_req,
    input  logic [31:0]    data_data,
    input  logic           data_ack,

    output logic           soft_reset_n
);

logic [$clog2(TIMEOUT_TICKS)-1:0] timeout_counter;

logic           inp_packet_valid;
logic           inp_packet_ready;
logic           inp_packet_error;
logic [7:0]     inp_packet_cmd;
logic [7:0]     inp_packet_id;
logic [7:0]     inp_packet_len;
logic [7:0]     inp_packet_data;
logic [7:0]     inp_packet_data_addr;
logic           inp_packet_data_re;

PacketParser packet_parser_inst(
    .clk(clk),
    .arstn(arstn),

    .input_valid(input_valid),
    .input_ready(input_ready),
    .input_error(input_error),
    .input_byte(input_byte),

    .res_valid(inp_packet_valid),
    .res_ready(inp_packet_ready),
    .res_error(inp_packet_error),
    .res_cmd(inp_packet_cmd),
    .res_id(inp_packet_id),
    .res_len(inp_packet_len),
    .res_data(inp_packet_data),
    .res_data_addr(inp_packet_data_addr),
    .res_data_re(inp_packet_data_re)
);

logic [7:0]     out_status;
logic           out_status_we;
logic [7:0]     out_id;
logic           out_id_we;
logic [7:0]     out_len;
logic           out_len_we;
logic [7:0]     out_payload;
logic [7:0]     out_payload_addr;
logic           out_payload_we;
logic           out_send_req;
logic           out_send_ack;

PacketBuffer packet_buffer_inst(
    .clk(clk),
    .arstn(arstn),

    .send_data(send_byte),
    .send_valid(send_valid),
    .send_ready(send_ready),

    .status(out_status),
    .status_we(out_status_we),
    .id(out_id),
    .id_we(out_id_we),
    .len(out_len),
    .len_we(out_len_we),
    .payload(out_payload),
    .payload_addr(out_payload_addr),
    .payload_we(out_payload_we),
    .send_req(out_send_req),
    .send_ack(out_send_ack)
);

logic           prog_mem_copy_req;
logic           prog_mem_copy_write;
logic           prog_mem_copy_ready;
logic [7:0]     prog_mem_read_len;

logic [7:0]     prog_mem_in_data_addr;
logic           prog_mem_in_data_re;

logic [7:0]     prog_mem_out_payload;
logic [7:0]     prog_mem_out_payload_addr;
logic           prog_mem_out_payload_we;

DebugMemoryCopier prog_mem_copier(
    .clk(clk),
    .arstn(arstn),
    
    .copy_req(prog_mem_copy_req),
    .copy_write(prog_mem_copy_write),
    .copy_ready(prog_mem_copy_ready),

    .inp_packet_len(inp_packet_len),
    .inp_packet_data(inp_packet_data),
    .inp_packet_data_addr(prog_mem_in_data_addr),
    .inp_packet_re(prog_mem_in_data_re),

    .out_packet_data(prog_mem_out_payload),
    .out_packet_data_addr(prog_mem_out_payload_addr),
    .out_packet_we(prog_mem_out_payload_we),

    .data_addr(prog_addr),
    .data_write_data(prog_write_data),
    .data_wr_en(prog_wr_en),
    .data_wr_mask(prog_wr_mask),
    .data_req(prog_req),
    .data_data(prog_data),
    .data_ack(prog_ack),
    
    .read_len(prog_mem_read_len)
);

logic           data_mem_copy_req;
logic           data_mem_copy_write;
logic           data_mem_copy_ready;
logic [7:0]     data_mem_read_len;

logic [7:0]     data_mem_in_data_addr;
logic           data_mem_in_data_re;

logic [7:0]     data_mem_out_payload;
logic [7:0]     data_mem_out_payload_addr;
logic           data_mem_out_payload_we;

logic [7:0]     state_out_payload;
logic [7:0]     state_out_payload_addr;
logic           state_out_payload_we;

DebugMemoryCopier data_mem_copier(
    .clk(clk),
    .arstn(arstn),
    
    .copy_req(data_mem_copy_req),
    .copy_write(data_mem_copy_write),
    .copy_ready(data_mem_copy_ready),

    .inp_packet_len(inp_packet_len),
    .inp_packet_data(inp_packet_data),
    .inp_packet_data_addr(data_mem_in_data_addr),
    .inp_packet_re(data_mem_in_data_re),

    .out_packet_data(data_mem_out_payload),
    .out_packet_data_addr(data_mem_out_payload_addr),
    .out_packet_we(data_mem_out_payload_we),

    .data_addr(data_addr),
    .data_write_data(data_write_data),
    .data_wr_en(data_wr_en),
    .data_wr_mask(data_wr_mask),
    .data_req(data_req),
    .data_data(data_data),
    .data_ack(data_ack),

    .read_len(data_mem_read_len)
);

always_comb begin
    out_payload = 'x;
    out_payload_addr = 'x;
    out_payload_we = 1'b0;
    inp_packet_data_addr = 'x;
    inp_packet_data_re = 1'b0;

    if (prog_mem_out_payload_we) begin
        out_payload = prog_mem_out_payload;
        out_payload_addr = prog_mem_out_payload_addr;
        out_payload_we = 1'b1;
    end
    else if (data_mem_out_payload_we) begin
        out_payload = data_mem_out_payload;
        out_payload_addr = data_mem_out_payload_addr;
        out_payload_we = 1'b1;
    end
    else if (state_out_payload_we) begin
        out_payload = state_out_payload;
        out_payload_addr = state_out_payload_addr;
        out_payload_we = 1'b1;
    end

    if (prog_mem_in_data_re) begin
        inp_packet_data_addr = prog_mem_in_data_addr;
        inp_packet_data_re = 1'b1;
    end
    else if (data_mem_in_data_re) begin
        inp_packet_data_addr = data_mem_in_data_addr;
        inp_packet_data_re = 1'b1;
    end
end

logic soft_reset_req;
logic soft_reset_ack;

ResetController #(.RESET_TICKS(10)) reset_controller(
    .clk(clk),
    .arstn(arstn),
    .req(soft_reset_req),
    .ack(soft_reset_ack),
    .reset_n(soft_reset_n)
);

localparam [7:0] CMD_HALT = 8'h00;
localparam [7:0] CMD_RESUME = 8'h01;
localparam [7:0] CMD_READ_PROG = 8'h02;
localparam [7:0] CMD_WRITE_PROG = 8'h03;
localparam [7:0] CMD_READ_DATA = 8'h04;
localparam [7:0] CMD_WRITE_DATA = 8'h05;
localparam [7:0] CMD_RESET = 8'h06;
localparam [7:0] CMD_GET_STATE = 8'h07;

localparam [7:0] STATUS_OK = 8'h00;
localparam [7:0] STATUS_ERROR_PARITY = 8'hFF;
localparam [7:0] STATUS_ERROR_ARGS = 8'hFE;
localparam [7:0] STATUS_ERROR_CMD = 8'hFD;

enum logic [3:0] {
    S_WAIT_INPUT,
    S_WAIT_TIMEOUT,
    S_CMD_HALT,
    S_CMD_RESUME,
    S_CMD_READ_PROG,
    S_CMD_WRITE_PROG,
    S_CMD_READ_DATA,
    S_CMD_WRITE_DATA,
    S_CMD_RESET,
    S_CMD_STATE,
    S_ERROR_PARITY,
    S_ERROR_ARGS,
    S_ERROR_CMD,
    S_WAIT_SEND
} cur_state, next_state;

always_comb begin
    next_state = cur_state;
    out_send_req = 1'b0;
    inp_packet_ready = 1'b0;

    halt_req = 1'b0;
    resume_req = 1'b0;

    out_status = 'x;
    out_status_we = 1'b0;
    out_id = 'x;
    out_id_we = 1'b0;
    out_len = 'x;
    out_len_we = 1'b0;

    prog_mem_copy_req = 1'b0;
    prog_mem_copy_write = 'x;

    data_mem_copy_req = 1'b0;
    data_mem_copy_write = 'x;

    soft_reset_req = 1'b0;

    state_out_payload = 'x;
    state_out_payload_addr = 'x;
    state_out_payload_we = 1'b0;

    case(cur_state)
    S_WAIT_INPUT: begin
        if (inp_packet_valid) begin
            if (inp_packet_error) begin
                next_state = S_WAIT_TIMEOUT;
            end
            else begin
                case (inp_packet_cmd)
                CMD_HALT: next_state = S_CMD_HALT;
                CMD_RESUME: next_state = S_CMD_RESUME;
                CMD_READ_PROG: begin
                    if (inp_packet_len >= 8'h05)
                        next_state = S_CMD_READ_PROG;
                    else
                        next_state = S_ERROR_ARGS;
                end
                CMD_WRITE_PROG: begin
                    if (inp_packet_len >= 8'h04)
                        next_state = S_CMD_WRITE_PROG;
                    else
                        next_state = S_ERROR_ARGS;
                end
                CMD_READ_DATA: begin
                    if (inp_packet_len >= 8'h05)
                        next_state = S_CMD_READ_DATA;
                    else
                        next_state = S_ERROR_ARGS;
                end
                CMD_WRITE_DATA: begin
                    if (inp_packet_len >= 8'h04)
                        next_state = S_CMD_WRITE_DATA;
                    else
                        next_state = S_ERROR_ARGS;
                end
                CMD_RESET: next_state = S_CMD_RESET;
                CMD_GET_STATE: next_state = S_CMD_STATE;
                default: next_state = S_ERROR_CMD;
                endcase
            end
        end
    end
    S_CMD_HALT: begin
        halt_req = 1'b1;
        out_status = STATUS_OK;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = '0;
        out_len_we = 1'b1;
        
        if (is_halted) begin
            next_state = S_WAIT_SEND;
        end
    end
    S_CMD_RESUME: begin
        resume_req = 1'b1;
        out_status = STATUS_OK;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = '0;
        out_len_we = 1'b1;
        
        if (~is_halted) begin
            next_state = S_WAIT_SEND;
        end
    end
    S_CMD_RESET: begin
        soft_reset_req = 1'b1;
        out_status = STATUS_OK;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = '0;
        out_len_we = 1'b1;

        if (soft_reset_ack) begin
            next_state = S_WAIT_SEND;
        end
    end
    S_CMD_STATE: begin
        out_status = STATUS_OK;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = 8'h01;
        out_len_we = 1'b1;

        state_out_payload_addr = 8'b0;
        state_out_payload = { 7'b0, is_halted };
        state_out_payload_we = 1'b1;

        next_state = S_WAIT_SEND;
    end
    S_CMD_READ_PROG: begin
        prog_mem_copy_req = 1'b1;
        prog_mem_copy_write = 1'b0;
        out_status = STATUS_OK;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = prog_mem_read_len;
        out_len_we = 1'b1;

        if (prog_mem_copy_ready) begin
            next_state = S_WAIT_SEND;
        end
    end
    S_CMD_WRITE_PROG: begin
        prog_mem_copy_req = 1'b1;
        prog_mem_copy_write = 1'b1;
        out_status = STATUS_OK;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = '0;
        out_len_we = 1'b1;

        if (prog_mem_copy_ready) begin
            next_state = S_WAIT_SEND;
        end
    end
    S_CMD_READ_DATA: begin
        data_mem_copy_req = 1'b1;
        data_mem_copy_write = 1'b0;
        out_status = STATUS_OK;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = data_mem_read_len;
        out_len_we = 1'b1;

        if (data_mem_copy_ready) begin
            next_state = S_WAIT_SEND;
        end
    end
    S_CMD_WRITE_DATA: begin
        data_mem_copy_req = 1'b1;
        data_mem_copy_write = 1'b1;
        out_status = STATUS_OK;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = '0;
        out_len_we = 1'b1;

        if (data_mem_copy_ready) begin
            next_state = S_WAIT_SEND;
        end
    end
    S_ERROR_PARITY: begin
        out_status = STATUS_ERROR_PARITY;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = '0;
        out_len_we = 1'b1;
        next_state = S_WAIT_SEND;
    end
    S_ERROR_ARGS: begin
        out_status = STATUS_ERROR_ARGS;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = '0;
        out_len_we = 1'b1;
        next_state = S_WAIT_SEND;
    end
    S_ERROR_CMD: begin
        out_status = STATUS_ERROR_CMD;
        out_status_we = 1'b1;
        out_id = inp_packet_id;
        out_id_we = 1'b1;
        out_len = '0;
        out_len_we = 1'b1;
        next_state = S_WAIT_SEND;
    end
    S_WAIT_SEND: begin
        out_send_req = 1'b1;

        if (out_send_ack) begin
            inp_packet_ready = 1'b1;
            next_state = S_WAIT_INPUT;
        end
    end
    S_WAIT_TIMEOUT: begin
        if (timeout_counter == TIMEOUT_TICKS - 1) begin
            next_state = S_ERROR_PARITY;
        end
    end
    endcase
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        cur_state <= S_WAIT_INPUT;
    end
    else begin
        cur_state <= next_state;
    end
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        timeout_counter <= '0;
    end
    else begin
        if (input_valid) begin
            timeout_counter <= '0;
        end
        else if (cur_state == S_WAIT_TIMEOUT) begin
            timeout_counter <= timeout_counter + 1'b1;
        end
    end
end

endmodule