module RegisterFile #(
    parameter XLEN = 32
) (
    input   logic             clk,
    input   logic             arstn,

    input   logic [4:0]       rs_1,
    output  logic [XLEN-1:0]  out_1,
    input   logic [4:0]       rs_2,
    output  logic [XLEN-1:0]  out_2,

    input   logic [4:0]       rd,
    input   logic             write_en,
    input   logic [XLEN-1:0]  write_data,

    output  logic [XLEN-1:0]  dbg_x0,
    output  logic [XLEN-1:0]  dbg_x1,
    output  logic [XLEN-1:0]  dbg_x2,
    output  logic [XLEN-1:0]  dbg_x3,
    output  logic [XLEN-1:0]  dbg_x4,
    output  logic [XLEN-1:0]  dbg_x5,
    output  logic [XLEN-1:0]  dbg_x6,
    output  logic [XLEN-1:0]  dbg_x7,
    output  logic [XLEN-1:0]  dbg_x10,
    output  logic [XLEN-1:0]  dbg_x11,
    output  logic [XLEN-1:0]  dbg_x12,
    output  logic [XLEN-1:0]  dbg_x13,
    output  logic [XLEN-1:0]  dbg_x14,
    output  logic [XLEN-1:0]  dbg_x15,
    output  logic [XLEN-1:0]  dbg_x16,
    output  logic [XLEN-1:0]  dbg_x17
);

logic [XLEN-1:0] regs [0:31];

assign out_1 = regs[rs_1];
assign out_2 = regs[rs_2];

always @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        for (int i = 0; i < 32; i++) begin
            regs[i] <= '0;
        end
    end
    else if (write_en & |rd) begin
        regs[rd] <= write_data;
    end
end

assign dbg_x0 = regs[0];
assign dbg_x1 = regs[1];
assign dbg_x2 = regs[2];
assign dbg_x3 = regs[3];
assign dbg_x4 = regs[4];
assign dbg_x5 = regs[5];
assign dbg_x6 = regs[6];
assign dbg_x7 = regs[7];
assign dbg_x10 = regs[10];
assign dbg_x11 = regs[11];
assign dbg_x12 = regs[12];
assign dbg_x13 = regs[13];
assign dbg_x14 = regs[14];
assign dbg_x15 = regs[15];
assign dbg_x16 = regs[16];
assign dbg_x17 = regs[17];

endmodule