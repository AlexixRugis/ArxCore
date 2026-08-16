`timescale 1ns/1ns

module MemStage_tb;

import LoadStoreTypes::*;

// Parameters
parameter XLEN = 32;
parameter ADDR_WIDTH = 32;
parameter CLK_PERIOD = 10;

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

// MEMORY MODEL
logic [XLEN-1:0]                memory [0:255];
logic [ADDR_WIDTH-1:0]          mem_addr;
logic                           mem_req;
logic                           mem_ack;
logic [XLEN-1:0]                mem_write_data;
logic                           mem_write_en;
logic [3:0]                     mem_write_mask;
logic [XLEN-1:0]                mem_read_data;

logic [7:0]                     mem_latency;

typedef struct packed {
    logic [ADDR_WIDTH-1:0] addr;
    logic [XLEN-1:0] value;
    logic write_en;
    logic [3:0] write_mask;
} mem_transaction;

mailbox #(mem_transaction) mem_ops = new();
mem_transaction mem_op;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        mem_ack <= 1'b0;
        mem_latency <= 8'($urandom_range(0, 10));
    end
    else begin
        if (mem_req) begin
            if (mem_latency == 8'b0) begin
                if (mem_write_en) begin
                    if (mem_write_mask[0]) memory[mem_addr[9:2]][7:0] = mem_write_data[7:0];
                    if (mem_write_mask[1]) memory[mem_addr[9:2]][15:8] = mem_write_data[15:8];
                    if (mem_write_mask[2]) memory[mem_addr[9:2]][23:16] = mem_write_data[23:16];
                    if (mem_write_mask[3]) memory[mem_addr[9:2]][31:24] = mem_write_data[31:24];
                end
                mem_read_data <= memory[mem_addr[9:2]];
                mem_ack <= 1'b1;
                mem_latency <= 8'($urandom_range(0, 10));

                mem_op.addr = mem_addr;
                mem_op.value = memory[mem_addr[9:2]];
                mem_op.write_en = mem_write_en;
                mem_op.write_mask = mem_write_mask;
                mem_ops.put(mem_op);
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

// DUT Instance

logic                           halt_req_in;
logic                           halt_ack_out;

logic                           valid_in;
logic                           ready_in;

logic [XLEN-1:0]                alu_in;
logic [XLEN-1:0]                rs2_in;
logic [4:0]                     rd_in;
logic                           reg_write_in;
logic                           mem_to_reg_in;

logic                           mem_op_in;
ls_type_t                       mem_op_type_in;

logic                           valid_out;
logic                           ready_out;
logic                           reg_write_out;
logic                           mem_to_reg_out;
logic [XLEN-1:0]                alu_res_out;
logic [XLEN-1:0]                mem_val_out;
logic [4:0]                     rd_out;

MemStage #(
    .XLEN(XLEN),
    .ADDR_WIDTH(ADDR_WIDTH)
) dut (
    .clk(clk),
    .arstn(arstn),

    .halt_req_in(halt_req_in),
    .halt_ack_out(halt_ack_out),
    
    // FROM EXEC STAGE
    .valid_in(valid_in),
    .ready_in(ready_in),

    .alu_in(alu_in),
    .rs2_in(rs2_in),
    .rd_in(rd_in),
    .reg_write_in(reg_write_in),
    .mem_to_reg_in(mem_to_reg_in),

    .mem_op_in(mem_op_in),
    .mem_op_type_in(mem_op_type_in),
    
    // TO WRITE BACK STAGE
    .valid_out(valid_out),
    .ready_out(ready_out),
    .reg_write_out(reg_write_out),
    .mem_to_reg_out(mem_to_reg_out),
    .alu_res_out(alu_res_out),
    .mem_val_out(mem_val_out),
    .rd_out(rd_out),
    
    // TO DATA MEM
    .mem_req_out(mem_req),
    .mem_ack_in(mem_ack),
    .mem_addr_out(mem_addr),
    .mem_write_data_out(mem_write_data),
    .mem_write_en_out(mem_write_en),
    .mem_write_mask_out(mem_write_mask),
    .mem_data_in(mem_read_data)
);

parameter TRANSACTION_COUNT = 1000;

typedef struct packed {
    logic [XLEN-1:0] alu_result;
    logic [XLEN-1:0] rs2_value;
    logic [4:0] rd;

    logic mem_op;
    ls_type_t mem_op_type;

    logic reg_write;
    logic mem_to_reg;
} in_data_t;

typedef struct packed {
    logic [XLEN-1:0] alu_result;
    logic [XLEN-1:0] mem_value;
    logic [4:0] rd;
    logic reg_write;
    logic mem_to_reg;
} out_data_t;

mailbox #(in_data_t) mb_in = new();
mailbox #(out_data_t) mb_out = new();

function logic [ADDR_WIDTH-1:0] get_aligned_addr(ls_type_t op_type);
    logic [1:0] offset;
    case (op_type)
        STORE_WORD, LOAD_WORD: offset = 2'b00;
        STORE_HALFWORD, LOAD_HALFWORD, LOAD_HALFWORD_UNSIGNED: 
            offset = { 1'($urandom_range(0, 1)), 1'b0 };
        default: offset = $urandom_range(0, 3);
    endcase
    return {($urandom() & 32'hFFFF_FFFC), offset};
endfunction

function logic [XLEN-1:0] extract_mem_data(logic [XLEN-1:0] mem_word, 
                                           logic [ADDR_WIDTH-1:0] addr, 
                                           ls_type_t op_type);
    logic [1:0] offset;
    logic [15:0] half;
    logic [7:0] byte_;
    
    offset = addr[1:0];
    case (op_type)
        LOAD_WORD: return mem_word;
        LOAD_HALFWORD_UNSIGNED: begin
            return (offset == 2'b00) ? {16'b0, mem_word[15:0]} : {16'b0, mem_word[31:16]};
        end
        LOAD_HALFWORD: begin
            half = (offset == 2'b00) ? mem_word[15:0] : mem_word[31:16];
            return {{16{half[15]}}, half};
        end
        LOAD_BYTE_UNSIGNED: begin
            case (offset)
                2'b00: return {24'b0, mem_word[7:0]};
                2'b01: return {24'b0, mem_word[15:8]};
                2'b10: return {24'b0, mem_word[23:16]};
                2'b11: return {24'b0, mem_word[31:24]};
            endcase
        end
        LOAD_BYTE: begin
            case (offset)
                2'b00: byte_ = mem_word[7:0];
                2'b01: byte_ = mem_word[15:8];
                2'b10: byte_ = mem_word[23:16];
                2'b11: byte_ = mem_word[31:24];
            endcase
            return {{24{byte_[7]}}, byte_};
        end
        default: return '0;
    endcase
endfunction

task send_transaction();
    in_data_t in_data;

    logic use_mem;
    logic write_op;

    ls_type_t all_op_types[$];

    all_op_types = {STORE_WORD, STORE_HALFWORD, STORE_BYTE,
                    LOAD_WORD, LOAD_HALFWORD_UNSIGNED, LOAD_HALFWORD,
                    LOAD_BYTE_UNSIGNED, LOAD_BYTE};

    in_data.mem_op = $urandom_range(0, 1);
    if (in_data.mem_op) begin
        write_op = $urandom_range(0, 1);

        if (write_op) begin
            in_data.mem_op_type = all_op_types[$urandom_range(0, 2)];
        end else begin
            in_data.mem_op_type = all_op_types[$urandom_range(3, 7)];
        end

        in_data.alu_result = get_aligned_addr(in_data.mem_op_type);
        in_data.mem_to_reg = write_op;
    end
    else begin
        in_data.alu_result = $urandom();
        in_data.mem_to_reg = 1'b0;
    end

    in_data.rs2_value = $urandom();
    in_data.rd = $urandom_range(0, 31);
    in_data.reg_write = $urandom_range(0, 1);

    @(posedge clk);
    valid_in <= 1'b1;
    alu_in <= in_data.alu_result;
    rs2_in <= in_data.rs2_value;
    rd_in <= in_data.rd;
    reg_write_in <= in_data.reg_write;

    mem_op_in <= in_data.mem_op;
    mem_op_type_in <= in_data.mem_op_type;
    mem_to_reg_in <= in_data.mem_to_reg;

    while (!(valid_in & ready_in)) begin
        @(posedge clk);
    end
    valid_in <= 1'b0;

    mb_in.put(in_data);
endtask

task read_output();
    out_data_t out_data;
    
    ready_out <= 1'b0;
    wait(arstn);
    
    for (int i = 0; i < TRANSACTION_COUNT; i++) begin
        
        repeat($urandom_range(0, 4)) @(posedge clk);

        ready_out <= 1'b1;

        do begin
            @(posedge clk);
        end
        while(~(valid_out & ready_out));

        ready_out <= 1'b0;
        
        out_data.alu_result = alu_res_out;
        out_data.mem_value = mem_val_out;
        out_data.rd = rd_out;
        out_data.reg_write = reg_write_out;
        out_data.mem_to_reg = mem_to_reg_out;
        mb_out.put(out_data);
    end

endtask

// Check output correctness
task check_output();
    in_data_t in_data;
    out_data_t out_data;
    mem_transaction mem_op;
    logic [3:0] expected_mask;
    
    for (int i = 0; i < TRANSACTION_COUNT; i++) begin
        mb_in.get(in_data);
        mb_out.get(out_data);

        if (in_data.alu_result !== out_data.alu_result) begin
            $error("Alu result error! Expected: %h, Actual: %h", in_data.alu_result, out_data.alu_result);
        end

        if (in_data.rd !== out_data.rd) begin
            $error("rd mismatch! Expected: %h, Actual: %h", in_data.rd, out_data.rd);
        end

        if (in_data.reg_write !== out_data.reg_write) begin
            $error("reg_write mismatch! Expected: %h, Actual: %h", in_data.reg_write, out_data.reg_write);
        end

        if (in_data.mem_to_reg !== out_data.mem_to_reg) begin
            $error("mem_to_reg mismatch! Expected: %h, Actual: %h", in_data.mem_to_reg, out_data.mem_to_reg);
        end

        if (in_data.mem_op) begin
            if (mem_op.addr !== in_data.alu_result[XLEN-1:0] & 0'hFFFF_FFFC) begin
                    $error("Memory read addr mismatch! Expected: %h, Actual: %h", in_data.alu_result, mem_op.addr);
            end

            if (in_data.mem_op_type == STORE_WORD || in_data.mem_op_type == STORE_HALFWORD
                || in_data.mem_op_type == STORE_BYTE) begin
                $display("[MEM OP] Memory write op: %s", in_data.mem_op_type.name());

                mem_ops.get(mem_op);

                if (mem_op.write_en !== 1'b1) begin
                    $error("Expected write mem op!");
                end

                case (in_data.mem_op_type)
                    STORE_WORD: begin
                        if (mem_op.write_mask !== 4'b1111) begin
                            $error("STORE_WORD: Wrong mask! Expected 1111, Got %b", mem_op.write_mask);
                        end
                    end
                    STORE_HALFWORD: begin
                        expected_mask = in_data.alu_result[1] ? 4'b1100 : 4'b0011;
                        if (mem_op.write_mask !== expected_mask) begin
                            $error("STORE_HALFWORD: Wrong mask! Expected %b, Got %b", 
                                   expected_mask, mem_op.write_mask);
                        end
                    end
                    STORE_BYTE: begin
                        expected_mask = 4'b0001 << in_data.alu_result[1:0];
                        if (mem_op.write_mask !== expected_mask) begin
                            $error("STORE_BYTE: Wrong mask! Expected %b, Got %b", 
                                   expected_mask, mem_op.write_mask);
                        end
                    end
                endcase

                case(in_data.mem_op_type)
                    STORE_WORD: begin
                        if (mem_op.value !== in_data.rs2_value) begin
                            $error("STORE WORD: Mem write value mismatch! Expected: %h, Actual: %h", in_data.rs2_value, mem_op.addr);
                        end        
                    end
                    STORE_HALFWORD: begin
                        if (in_data.alu_result[1] === 1'b0) begin
                            if (mem_op.value[15:0] !== in_data.rs2_value[15:0]) begin
                                $error("STORE HALFWORD: Mem write value mismatch! Expected: %h, Actual: %h", in_data.rs2_value, mem_op.addr);
                            end
                        end
                        else begin
                            if (mem_op.value[31:16] !== in_data.rs2_value[15:0]) begin
                                $error("STORE HALFWORD: Mem write value mismatch! Expected: %h, Actual: %h", in_data.rs2_value, mem_op.addr);
                            end
                        end
                    end
                    STORE_BYTE: begin
                        case (in_data.alu_result[1:0])
                        2'b00: begin
                            if (mem_op.value[7:0] !== in_data.rs2_value[7:0]) begin
                                $error("STORE BYTE: Mem write value mismatch! Expected: %h, Actual: %h", in_data.rs2_value, mem_op.addr);
                            end
                        end
                        2'b01: begin
                            if (mem_op.value[15:8] !== in_data.rs2_value[7:0]) begin
                                $error("STORE BYTE: Mem write value mismatch! Expected: %h, Actual: %h", in_data.rs2_value, mem_op.addr);
                            end
                        end
                        2'b10: begin
                            if (mem_op.value[23:16] !== in_data.rs2_value[7:0]) begin
                                $error("STORE BYTE: Mem write value mismatch! Expected: %h, Actual: %h", in_data.rs2_value, mem_op.addr);
                            end
                        end
                        2'b11: begin
                            if (mem_op.value[31:24] !== in_data.rs2_value[7:0]) begin
                                $error("STORE BYTE: Mem write value mismatch! Expected: %h, Actual: %h", in_data.rs2_value, mem_op.addr);
                            end
                        end
                        endcase
                    end
                endcase
                
                
            end
            else begin
                $display("[MEM OP] Memory read op: %s", in_data.mem_op_type.name());

                mem_ops.get(mem_op);

                if (mem_op.write_en !== 1'b0) begin
                    $error("Expected read mem op!");
                end
                
                if (extract_mem_data(mem_op.value, in_data.alu_result, in_data.mem_op_type) !== out_data.mem_value) begin
                    $error("Mem read value mismatch! Expected: %h, Actual: %h", mem_op.value, out_data.mem_value);
                end
            end
        end
        
        $display("[CHECK] Transaction %0d: ALU=%h, MEM=%h, RD=%0d",
                 i, out_data.alu_result, out_data.mem_value, out_data.rd);
    end
endtask

// Initialize memory with random values
task init_memory();
    for (int i = 0; i < 256; i++) begin
        memory[i] = $urandom();
    end
endtask

initial begin
    halt_req_in <= 1'b0;
    valid_in <= 1'b0;
    ready_out <= 1'b0;
    alu_in <= '0;
    rs2_in <= '0;
    rd_in <= '0;
    reg_write_in <= 1'b0;
    mem_to_reg_in <= 1'b0;
    
    init_memory();
    
    wait(arstn);
    repeat(5) @(posedge clk);
    
    fork
        begin
            wait(arstn);
            for (int i = 0; i < TRANSACTION_COUNT; i++) begin
                send_transaction();
                repeat($urandom_range(0, 5)) @(posedge clk);
            end
        end
        
        read_output();
        check_output();
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