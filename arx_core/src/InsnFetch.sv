module InsnFetch #(
    parameter ADDR_WIDTH = 32,
    parameter INSN_WIDTH = 32
)(
    input                           clk,
    input                           arstn,

    // HALT REQ
    input   logic                   halt_req_in,
    output  logic                   halt_ack_out,
    // -----------------

    // MEMORY INTERFACE
    output  logic [ADDR_WIDTH-1:0]  mem_addr,
    output  logic                   mem_req,
    input   logic [INSN_WIDTH-1:0]  mem_insn_in,
    input                           mem_ack,
    // -----------------

    // PC SETTING
    input   logic [ADDR_WIDTH-1:0]  pc_in,
    input   logic                   pc_we,
    // -----------------

    // OUT DATA
    output  logic                   valid_out,
    input   logic                   ready_out,

    output  logic [ADDR_WIDTH-1:0]  pc_out,
    output  logic [INSN_WIDTH-1:0]  insn_out
    // -----------------
);

typedef enum logic [1:0] {
    SOURCE_NONE,
    SOURCE_MEM,
    SOURCE_BUF
} out_source_t;

typedef enum logic [1:0] {
    REQ_NONE,
    REQ_CUR,
    REQ_NEXT
} mem_req_t;

logic [ADDR_WIDTH-1:0]          pc_in_buf;
logic                           pc_we_buf;

logic [ADDR_WIDTH-1:0]          pc_in_internal;
logic                           pc_we_internal;

assign pc_we_internal = pc_we | pc_we_buf;
assign pc_in_internal = pc_we ? pc_in : pc_in_buf;

logic                           pc_we_ack;

logic [ADDR_WIDTH-1:0]          pc;
logic [ADDR_WIDTH-1:0]          pc_next;

logic                           pc_upd;

logic [INSN_WIDTH-1:0]          insn_buf;
logic                           insn_buf_we;

assign pc_next = pc_we_internal ? pc_in_internal : (pc + 3'd4);

out_source_t                    out_source;
mem_req_t                       mem_req_type;

// STATE MACHINE
typedef enum logic [1:0] {
    S_IDLE,
    S_FETCH,
    S_WAIT_HANDSHAKE,
    S_HALT
} if_state_t;

if_state_t                      next_state, 
                                cur_state;

always_comb begin
    next_state = cur_state;

    out_source = SOURCE_NONE;
    mem_req_type = REQ_NONE;

    pc_upd = 1'b0;
    pc_we_ack = 1'b0;
    insn_buf_we = 1'b0;

    halt_ack_out = 1'b0;

    case (cur_state)
    S_IDLE: begin
        next_state = S_FETCH;
    end
    S_FETCH: begin
        mem_req_type = REQ_CUR;

        if (mem_ack) begin
            out_source = SOURCE_MEM;

            if (ready_out | pc_we_internal) begin
                if (pc_we_internal) begin
                    out_source = SOURCE_NONE;
                    pc_we_ack = 1'b1;
                end

                pc_upd = 1'b1;
                mem_req_type = REQ_NEXT;
                next_state = S_FETCH;
            end
            else begin
                insn_buf_we = 1'b1;
                mem_req_type = REQ_NONE;
                next_state = S_WAIT_HANDSHAKE;
            end
        end
    end
    S_WAIT_HANDSHAKE: begin
        out_source = SOURCE_BUF;
        halt_ack_out = halt_req_in;

        if (ready_out | pc_we) begin

            if (pc_we_internal) begin
                out_source = SOURCE_NONE;
                pc_we_ack = 1'b1;
            end

            pc_upd = 1'b1;
            mem_req_type = REQ_NEXT;
            next_state = S_FETCH;
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
// -----------------

// OUT SOURCE

always_comb begin
    case (out_source)
    SOURCE_NONE: begin
        valid_out = 1'b0;
        insn_out = 'x;
        pc_out = 'x;
    end
    SOURCE_MEM: begin
        valid_out = 1'b1;
        insn_out = mem_insn_in;
        pc_out = pc;
    end
    SOURCE_BUF: begin
        valid_out = 1'b1;
        insn_out = insn_buf;
        pc_out = pc;
    end
    endcase

    if (halt_req_in) begin
        valid_out = 1'b0;
    end
end

// -----------------

// MEM REQ

always_comb begin
    case (mem_req_type)
    REQ_NONE: begin
        mem_req = 1'b0;
        mem_addr = 'x;
    end
    REQ_CUR: begin
        mem_req = 1'b1;
        mem_addr = pc;
    end
    REQ_NEXT: begin
        mem_req = 1'b1;
        mem_addr = pc_next;
    end
    endcase
end

// -----------------

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        pc <= '0;
        insn_buf <= '0;

        pc_we_buf <= 1'b0;
    end
    else begin
        if (insn_buf_we) begin
            insn_buf <= mem_insn_in;    
        end

        if (pc_we & ~pc_we_ack) begin
            pc_we_buf <= 1'b1;
            pc_in_buf <= pc_in;
        end

        if (pc_we_ack) begin
            pc_we_buf <= 1'b0;
        end

        if (pc_upd) begin
            pc <= pc_next;
        end
    end
end

endmodule