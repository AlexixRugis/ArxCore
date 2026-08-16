module ByteToWordAddrConverter(
    input  logic [31:0]         byte_addr,
    input  logic [7:0]          write_data,
    output logic [31:0]         word_addr,
    output logic [31:0]         write_data_extended,
    output logic [3:0]          write_data_mask,
    
    input  logic [31:0]         read_data_extended,
    output logic [7:0]          read_data
);

assign word_addr = {byte_addr[31:2], 2'b00};
assign write_data_mask = 4'b0001 << byte_addr[1:0];
assign write_data_extended = write_data << {byte_addr[1:0], 3'b000};
assign read_data = 8'(read_data_extended >> {byte_addr[1:0], 3'b000});

endmodule