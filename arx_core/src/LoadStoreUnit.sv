module LoadStoreUnit
    import LoadStoreTypes::*;
#(
    parameter XLEN = 32,
    parameter ADDR_WIDTH = 32
) (
    input   logic                       clk,
    input   logic                       arstn,

// TO CPU
    input   logic                       cpu_req_in,
    output  logic                       cpu_ack_out,

    input   logic [ADDR_WIDTH-1:0]      cpu_addr_in,
    input   ls_type_t                   cpu_mem_op_type_in,
    input   logic [XLEN-1:0]            cpu_write_data_in,
    output  logic [XLEN-1:0]            cpu_read_data_out,
// -----------

// TO MEMORY
    output  logic                       mem_req_out,
    input   logic                       mem_ack_in,

    output  logic [ADDR_WIDTH-1:0]      mem_addr_out,
    output  logic [XLEN-1:0]            mem_write_data_out,
    output  logic                       mem_write_en_out,
    output  logic [3:0]                 mem_write_mask_out,
    input   logic [XLEN-1:0]            mem_data_in
// -----------
);

logic [XLEN-1:0]                        write_data_half_word;
logic [XLEN-1:0]                        write_data_byte;
assign write_data_half_word = {2{cpu_write_data_in[15:0]}};
assign write_data_byte = {4{cpu_write_data_in[7:0]}};

always_comb begin
    mem_req_out = cpu_req_in;
    cpu_ack_out = mem_ack_in;
    cpu_read_data_out = '0;
    mem_write_data_out = '0;
    mem_write_en_out = 1'b0;
    mem_write_mask_out = 4'b0000;
    mem_addr_out = { cpu_addr_in[ADDR_WIDTH-1:2], 2'b00 };

    unique case(cpu_mem_op_type_in)
        STORE_WORD: begin
            mem_write_en_out = 1'b1;
            mem_write_data_out = cpu_write_data_in;
            mem_write_mask_out = 4'b1111; 
        end
        STORE_HALFWORD: begin
            mem_write_en_out = 1'b1;
            mem_write_data_out = write_data_half_word;
            mem_write_mask_out = cpu_addr_in[1] ? 4'b1100 : 4'b0011;
        end
        STORE_BYTE: begin
            mem_write_en_out = 1'b1;
            mem_write_data_out = write_data_byte;
            unique case(cpu_addr_in[1:0])
                2'b00: mem_write_mask_out = 4'b0001;
                2'b01: mem_write_mask_out = 4'b0010;
                2'b10: mem_write_mask_out = 4'b0100;
                2'b11: mem_write_mask_out = 4'b1000;
            endcase
        end
        LOAD_WORD: begin
            cpu_read_data_out = mem_data_in;
        end
        LOAD_HALFWORD_UNSIGNED: begin
            cpu_read_data_out = cpu_addr_in[1] ?
                {16'b0, mem_data_in[31:16]} :
                {16'b0, mem_data_in[15:0]};
        end
        LOAD_BYTE_UNSIGNED: begin
            unique case(cpu_addr_in[1:0])
                2'b00: cpu_read_data_out = {24'b0, mem_data_in[7:0]};
                2'b01: cpu_read_data_out = {24'b0, mem_data_in[15:8]};
                2'b10: cpu_read_data_out = {24'b0, mem_data_in[23:16]};
                2'b11: cpu_read_data_out = {24'b0, mem_data_in[31:24]};
            endcase
        end
        LOAD_HALFWORD: begin
            cpu_read_data_out = cpu_addr_in[1] ?
                {{16{mem_data_in[31]}}, mem_data_in[31:16]} :
                {{16{mem_data_in[15]}}, mem_data_in[15:0]};
        end
        LOAD_BYTE: begin
            unique case(cpu_addr_in[1:0])
                2'b00: cpu_read_data_out = {{24{mem_data_in[7]}}, mem_data_in[7:0]};
                2'b01: cpu_read_data_out = {{24{mem_data_in[15]}}, mem_data_in[15:8]};
                2'b10: cpu_read_data_out = {{24{mem_data_in[23]}}, mem_data_in[23:16]};
                2'b11: cpu_read_data_out = {{24{mem_data_in[31]}}, mem_data_in[31:24]};
            endcase
        end
        default: begin
        end
    endcase
end

endmodule