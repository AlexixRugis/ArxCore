`timescale 1ns/100ps

module InsnFetch_tb;

// Parameters
parameter ADDR_WIDTH = 32;
parameter INSN_WIDTH = 32;
parameter CLK_PERIOD = 10; // ns

// CLOCK AND RESET
logic                           clk;
logic                           arstn;

initial begin
    clk <= 1'b0;
    forever begin
        #(CLK_PERIOD/2) clk <= ~clk;
    end
end

initial begin
    arstn <= 1'b0;
    repeat(3) @(posedge clk);
    arstn <= 1'b1;
end
// -----------

// MEMORY

logic [INSN_WIDTH-1:0]          memory [0:255];

logic [ADDR_WIDTH-1:0]          mem_addr;
logic                           mem_req;
logic [7:0]                     mem_latency;
logic                           mem_ack;
logic [INSN_WIDTH-1:0]          mem_data;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        mem_ack <= 1'b0;
        mem_latency <= 8'($urandom_range(0,20));
    end
    else begin
        if (mem_req) begin
            if (mem_latency === 8'b0) begin
                mem_data <= memory[mem_addr[9:2]];
                mem_ack <= 1'b1;
                mem_latency <= 8'($urandom_range(0,10));
            end
            else begin
                mem_latency <= mem_latency - 1'b1;
                mem_ack <= 1'b0;
            end
        end
        else begin
            mem_ack <= 1'b0;
        end
    end
end

// -----------

// PC setting
logic [ADDR_WIDTH-1:0]          expected_pc;

logic [ADDR_WIDTH-1:0]          pc_in;
logic                           pc_we;

// OUT data
logic                           valid_out;
logic                           ready_out;
logic [ADDR_WIDTH-1:0]          pc_out;
logic [INSN_WIDTH-1:0]          insn_out;

logic                           halt_req_in;
logic                           halt_ack_out;

// DUT instance
InsnFetch #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSN_WIDTH(INSN_WIDTH)
) dut (
    .clk        (clk),
    .arstn      (arstn),
    .halt_req_in(halt_req_in),
    .halt_ack_out(halt_ack_out),
    .mem_addr   (mem_addr),
    .mem_req    (mem_req),
    .mem_insn_in(mem_data),
    .mem_ack    (mem_ack),
    .pc_in      (pc_in),
    .pc_we      (pc_we),
    .valid_out  (valid_out),
    .ready_out  (ready_out),
    .pc_out     (pc_out),
    .insn_out   (insn_out)
);

parameter PACKET_COUNT = 1000;
parameter JUMP_COUNT = 300;

typedef struct packed {
    logic [INSN_WIDTH-1:0] insn;
    logic [ADDR_WIDTH-1:0] pc;
    logic [ADDR_WIDTH-1:0] expected_pc;
} out_data_t;

mailbox #(out_data_t) mb_out = new();

task set_pc(
    input logic [ADDR_WIDTH-1:0] target_pc
);
    pc_we <= 1'b1;
    pc_in <= target_pc;
    @(posedge clk);
    pc_we <= 1'b0;

endtask

task read_out();
    out_data_t out_data;

    ready_out <= 1'b0;
    wait(arstn);

    for (int i = 0; i < PACKET_COUNT; i = i + 1) begin

        repeat($urandom_range(0, 4)) @(posedge clk);

        ready_out <= 1'b1;

        do begin
            @(posedge clk);
        end
        while(~(valid_out & ready_out));

        ready_out <= 1'b0;

        out_data.pc = pc_out;
        out_data.insn = insn_out;
        out_data.expected_pc = expected_pc;
        mb_out.put(out_data);
    end
endtask

task check_out();
    out_data_t out_data;

    for (int i = 0; i < PACKET_COUNT; i = i + 1) begin
        mb_out.get(out_data);

        if (out_data.pc[1:0] !== 2'b00) begin
            $error("Unexpected unaligned PC!");
        end

        if (out_data.expected_pc !== out_data.pc) begin
            $error("Unexpected PC value! Expected %h, Actual: %h", out_data.expected_pc, out_data.pc);
        end

        if (memory[out_data.pc[9:2]] !== out_data.insn) begin
            $error("Insn doesn't match! Expected: %h, Actual: %h", memory[out_data.pc[9:2]], out_data.insn);
        end
    end
endtask

task make_jumps();
    wait(arstn);
    repeat(10) @(posedge clk);
    for (int i = 0; i < JUMP_COUNT; i = i + 1) begin
        repeat($urandom_range(0, 50)) @(posedge clk);
        set_pc({ 30'($urandom_range(0, 200)), 2'b00 });
    end
endtask

task init_memory();
    for (int i = 0; i < 256; i++) begin
        memory[i] = $urandom();
    end
endtask

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        expected_pc <= '0;
    end
    else begin
        if (pc_we) begin
            expected_pc <= pc_in;
        end
        else if (valid_out & ready_out) begin
            expected_pc <= expected_pc + 3'd4;
        end
    end
end

initial begin
    pc_in <= '0;
    pc_we <= 1'b0;
    halt_req_in <= 1'b0;
    
    init_memory();

    set_pc(32'h00000010);

    fork
        read_out();
        check_out();
        make_jumps();
    join    
    
    #100;
    $finish;
end

parameter TIMEOUT = 100000;
initial begin
    #(TIMEOUT);
    $error("TIMEOUT");
    $stop();
end

endmodule