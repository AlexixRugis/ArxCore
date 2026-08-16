`timescale 1ns/100ps

module ArxCore_tb;

logic [31:0]        out_1;

// Parameters
parameter ADDR_WIDTH = 32;
parameter XLEN = 32;
parameter INSN_WIDTH = 32;
parameter CLK_PERIOD = 10; // ns
parameter TIMEOUT = 1700000;

// CLOCK AND RESET
logic                           clk;
logic                           arstn;

logic [31:0]                    prog_memory[0:262143];
logic [XLEN-1:0]                memory [0:262143];

initial begin
    clk <= 1'b0;
    forever begin
        #(CLK_PERIOD/2) clk <= ~clk;
        // $display("%h", rom_addr);
    end
end

string output_str;
initial begin

    arstn <= 1'b0;
    repeat(10) @(posedge clk);
    arstn <= 1'b1;

    $monitor(out_1);
    wait (out_1 == 32'd16);

    output_str = "";

    for (int i = 0; i < 5; i = i + 1) begin
        output_str = {output_str, 
                    string'(memory[(32'h6F4 >> 2) + i][7:0]),
                    string'(memory[(32'h6F4 >> 2) + i][15:8]),
                    string'(memory[(32'h6F4 >> 2) + i][23:16]),
                    string'(memory[(32'h6F4 >> 2) + i][31:24])};
    end

    $display("%s", output_str);

    $finish();
end

initial begin
    #(TIMEOUT);
    $error("TIMEOUT");
    $stop();
end

// -----------

logic clk_en;
always_comb clk_en = 1'b1;

logic               halted;
logic               halt_req;
logic               resume_req;

logic [31:0]            rom_addr;
logic [31:0]            rom_val;

logic               rom_port_req;
logic               rom_port_ack;
logic [31:0]        rom_port_addr;
logic [31:0]        rom_port_data;

logic [31:0]        ram_addr;
logic [31:0]        ram_val;
logic [31:0]        ram_write_data;
logic               ram_we;
logic [3:0]         ram_mask;

logic [31:0]        ram_port_addr;
logic [31:0]        ram_port_data;
logic [31:0]        ram_port_write_data;
logic               ram_port_we;
logic [3:0]         ram_port_mask;
logic               ram_port_req;
logic               ram_port_ack;

logic [31:0]        periph_addr;
logic [31:0]        periph_val;
logic [31:0]        periph_write_data;
logic               periph_we;
logic [3:0]         periph_mask;

Peripherals periph(
    .clk(clk), .clk_en(clk_en), .arstn(arstn),
    .address(periph_addr), .data(periph_write_data), 
    .write_en(periph_we), .write_mask(periph_mask), .q(periph_val), .out_1(out_1));

MemoryInterconnect intrc(
    .clk(clk),
    .arstn(arstn),
    .clk_en(clk_en),

    .master1_addr(ram_port_addr),
    .master1_write_data(ram_port_write_data),
    .master1_wr_en(ram_port_we),
    .master1_wr_mask(ram_port_mask),
    .master1_req(ram_port_req),
    .master1_data(ram_port_data),
    .master1_ack(ram_port_ack),

    .master2_addr(rom_port_addr),
    .master2_write_data('0),
    .master2_wr_en('0),
    .master2_wr_mask('0),
    .master2_req(rom_port_req),
    .master2_data(rom_port_data),
    .master2_ack(rom_port_ack),

    .rom_addr(rom_addr),
    .rom_data(rom_val),

    .ram_addr(ram_addr),
    .ram_write_data(ram_write_data),
    .ram_wr_en(ram_we),
    .ram_wr_mask(ram_mask),
    .ram_data(ram_val),

    .periph_addr(periph_addr),
    .periph_write_data(periph_write_data),
    .periph_wr_en(periph_we),
    .periph_wr_mask(periph_mask),
    .periph_data(periph_val)
);

logic [31:0]        dbg_x0;
logic [31:0]        dbg_x1;
logic [31:0]        dbg_x2;
logic [31:0]        dbg_x3;
logic [31:0]        dbg_x4;
logic [31:0]        dbg_x5;
logic [31:0]        dbg_x6;
logic [31:0]        dbg_x7;
logic [31:0]        dbg_x10;
logic [31:0]        dbg_x11;
logic [31:0]        dbg_x12;
logic [31:0]        dbg_x13;
logic [31:0]        dbg_x14;
logic [31:0]        dbg_x15;
logic [31:0]        dbg_x16;
logic [31:0]        dbg_x17;
logic [31:0]        dbg_pc_fs;
logic [31:0]        dbg_pc_id;
logic [31:0]        dbg_pc_ex;
logic [31:0]        dbg_pc_mem;
logic [31:0]        dbg_pc_wb;


logic [31:0]        mem_debug_addr;
logic [31:0]        mem_debug_write_data;
logic               mem_debug_wr_enable;
logic [3:0]         mem_debug_wr_mask;
logic               mem_debug_req;
logic [31:0]        mem_debug_data;
logic               mem_debug_ack;

ArxCore p(
    .clk(clk),
    .arstn(arstn),
    
    .rom_addr(rom_port_addr),
    .rom_req(rom_port_req),
    .rom_data(rom_port_data),
    .rom_ack(rom_port_ack),
    
    .ram_addr(ram_port_addr),
    .ram_write_data(ram_port_write_data),
    .ram_we(ram_port_we),
    .ram_we_mask(ram_port_mask),
    .ram_req(ram_port_req),
    .ram_data(ram_port_data),
    .ram_ack(ram_port_ack),

    .halt_req(halt_req),
    .resume_req(resume_req),
    .halted(halted),

    .mem_debug_addr(mem_debug_addr),
    .mem_debug_write_data(mem_debug_write_data),
    .mem_debug_wr_enable(mem_debug_wr_enable),
    .mem_debug_wr_mask(mem_debug_wr_mask),
    .mem_debug_req(mem_debug_req),
    .mem_debug_data(mem_debug_data),
    .mem_debug_ack(mem_debug_ack),

    .dbg_x0(dbg_x0),
    .dbg_x1(dbg_x1),
    .dbg_x2(dbg_x2),
    .dbg_x3(dbg_x3),
    .dbg_x4(dbg_x4),
    .dbg_x5(dbg_x5),
    .dbg_x6(dbg_x6),
    .dbg_x7(dbg_x7),
    .dbg_x10(dbg_x10),
    .dbg_x11(dbg_x11),
    .dbg_x12(dbg_x12),
    .dbg_x13(dbg_x13),
    .dbg_x14(dbg_x14),
    .dbg_x15(dbg_x15),
    .dbg_x16(dbg_x16),
    .dbg_x17(dbg_x17),
    .dbg_pc_fs(dbg_pc_fs),
    .dbg_pc_id(dbg_pc_id),
    .dbg_pc_ex(dbg_pc_ex),
    .dbg_pc_mem(dbg_pc_mem),
    .dbg_pc_wb(dbg_pc_wb)
);

// -----------

initial begin
    halt_req <= 1'b0;
    resume_req <= 1'b0;
    
    mem_debug_req <= 1'b0;
end

// ROM emul

initial begin
    $readmemh("firmware.hex", prog_memory);
end

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
    end
    else begin
        rom_val <= prog_memory[rom_addr[19:2]];
    end
end
// -----------

// RAM EMUL


always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
    end
    else begin
        ram_val <= memory[ram_addr[19:2]];
        if (ram_we) begin
            //$display("RAM WRITE: *%h = %h, mask = %b", ram_addr[19:2], ram_write_data, ram_mask);
            if (ram_mask[0]) memory[ram_addr[19:2]][7:0] = ram_write_data[7:0];
            if (ram_mask[1]) memory[ram_addr[19:2]][15:8] = ram_write_data[15:8];
            if (ram_mask[2]) memory[ram_addr[19:2]][23:16] = ram_write_data[23:16];
            if (ram_mask[3]) memory[ram_addr[19:2]][31:24] = ram_write_data[31:24];
        end
    end
end

// -----------

endmodule