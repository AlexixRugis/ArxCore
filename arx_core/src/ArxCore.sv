import IALUTypes::*;
import LoadStoreTypes::*;
import BranchTypes::*;

module ArxCore
(
    input                       clk,
    input                       arstn,
    
    output  logic [31:0]        rom_addr,
    output  logic               rom_req,
    input   logic [31:0]        rom_data,
    input   logic               rom_ack,
    
    output  logic [31:0]        ram_addr,
    output  logic [31:0]        ram_write_data,
    output  logic               ram_we,
    output  logic [3:0]         ram_we_mask,
    output  logic               ram_req,
    input   logic [31:0]        ram_data,
    input   logic               ram_ack,

    input   logic               halt_req,
    input   logic               resume_req,
    output  logic               halted,

    input   logic [31:0]        mem_debug_addr,
    input   logic [31:0]        mem_debug_write_data,
    input   logic               mem_debug_wr_enable,
    input   logic [3:0]         mem_debug_wr_mask,
    input   logic               mem_debug_req,
    output  logic [31:0]        mem_debug_data,
    output  logic               mem_debug_ack,


    output  logic [31:0]        dbg_x0,
    output  logic [31:0]        dbg_x1,
    output  logic [31:0]        dbg_x2,
    output  logic [31:0]        dbg_x3,
    output  logic [31:0]        dbg_x4,
    output  logic [31:0]        dbg_x5,
    output  logic [31:0]        dbg_x6,
    output  logic [31:0]        dbg_x7,
    output  logic [31:0]        dbg_x10,
    output  logic [31:0]        dbg_x11,
    output  logic [31:0]        dbg_x12,
    output  logic [31:0]        dbg_x13,
    output  logic [31:0]        dbg_x14,
    output  logic [31:0]        dbg_x15,
    output  logic [31:0]        dbg_x16,
    output  logic [31:0]        dbg_x17,

    output  logic [31:0]        dbg_pc_fs,
    output  logic [31:0]        dbg_pc_id,
    output  logic [31:0]        dbg_pc_ex,
    output  logic [31:0]        dbg_pc_mem,
    output  logic [31:0]        dbg_pc_wb
);

localparam XLEN = 32;
localparam ADDR_WIDTH = 32;
localparam INSN_WIDTH = 32;

logic                           halt_req_in;
logic                           halt_ack_out_fs;
logic                           halt_ack_out_id;
logic                           halt_ack_out_ex;
logic                           halt_ack_out_mem;

logic                           m_is_halted;
assign m_is_halted = halt_ack_out_fs & halt_ack_out_id & halt_ack_out_ex & halt_ack_out_mem;

// FETCH STAGE

logic [31:0]                    fs_pc_in;
logic                           fs_pc_we_in;

logic                           fs_valid_out;
logic                           fs_ready_out;

logic [31:0]                    fs_pc_out;
assign dbg_pc_fs = fs_pc_out;
logic [31:0]                    fs_insn_out;

InsnFetch #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .INSN_WIDTH(INSN_WIDTH)
) fetch_stage (
    .clk(clk),
    .arstn(arstn),

    // HALT REQ
    .halt_req_in(halt_req_in),
    .halt_ack_out(halt_ack_out_fs),
    // -----------------

    // MEMORY INTERFACE
    .mem_addr(rom_addr),
    .mem_req(rom_req),
    .mem_insn_in(rom_data),
    .mem_ack(rom_ack),
    // -----------------

    // PC SETTING
    .pc_in(fs_pc_in),
    .pc_we(fs_pc_we_in),
    // -----------------

    // OUT DATA
    .valid_out(fs_valid_out),
    .ready_out(fs_ready_out),

    .pc_out(fs_pc_out),
    .insn_out(fs_insn_out)
    // -----------------
);

// -----------

logic                           id_flush_in;

logic                           id_valid_in;
assign id_valid_in = fs_valid_out;
logic                           id_ready_in;
assign fs_ready_out = id_ready_in;

logic [ADDR_WIDTH-1:0]          id_pc_in;
assign id_pc_in = fs_pc_out;
logic [INSN_WIDTH-1:0]          id_insn_in;
assign id_insn_in = fs_insn_out;

logic                           id_valid_out;
logic                           id_ready_out;

logic [XLEN-1:0]                id_rs1_out;
logic [XLEN-1:0]                id_rs2_out;
logic [XLEN-1:0]                id_imm_out;

logic [4:0]                     id_rd_out;
logic [ADDR_WIDTH-1:0]          id_pc_out;
assign dbg_pc_id = id_pc_out;
branch_type_t                   id_pc_addr_type_out;
logic                           id_pc_jump_en_out;

logic                           id_reg_write_out;
logic                           id_mem_to_reg_out;
logic                           id_mem_op_out;
ls_type_t                       id_mem_op_type_out;
    
ALU_op_t                        id_alu_op_out;
ALU_src1_t                      id_alu_src_1_out;
ALU_src2_t                      id_alu_src_2_out;

MDU_op_t                        id_mdu_op_out;

logic                           id_alu_en_out;
logic                           id_mdu_en_out;

logic [4:0]                     id_rd_in;
logic [XLEN-1:0]                id_rd_val_in;
logic                           id_rd_we_in;

logic [2:0]                    id_dbg_used_regs_out [0:31];

InsnDecodeStage #(
    .INSN_WIDTH(INSN_WIDTH),
    .XLEN(XLEN),
    .ADDR_WIDTH(ADDR_WIDTH)
) decode_stage (
    .clk(clk),
    .arstn(arstn),

    .halt_req_in(halt_req_in),
    .halt_ack_out(halt_ack_out_id),

    .flush_in(id_flush_in),

    .valid_in(id_valid_in),
    .ready_in(id_ready_in),

    .pc_in(id_pc_in),
    .insn_in(id_insn_in),

    .valid_out(id_valid_out),
    .ready_out(id_ready_out),

    .rs1_out(id_rs1_out),
    .rs2_out(id_rs2_out),
    .imm_out(id_imm_out),

    .rd_out(id_rd_out),
    .pc_out(id_pc_out),
    .pc_addr_type_out(id_pc_addr_type_out),
    .pc_jump_en_out(id_pc_jump_en_out),

    .reg_write_out(id_reg_write_out),
    .mem_to_reg_out(id_mem_to_reg_out),
    .mem_op_out(id_mem_op_out),
    .mem_op_type_out(id_mem_op_type_out),

    .alu_op_out(id_alu_op_out),
    .alu_src_1_out(id_alu_src_1_out),
    .alu_src_2_out(id_alu_src_2_out),

    .mdu_op_out(id_mdu_op_out),
    
    .alu_en_out(id_alu_en_out),
    .mdu_en_out(id_mdu_en_out),

    .rd_in(id_rd_in),
    .rd_val_in(id_rd_val_in),
    .rd_we_in(id_rd_we_in),

    .dbg_used_regs_out(id_dbg_used_regs_out),
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
    .dbg_x17(dbg_x17)
);

// EXECUTE STAGE

logic                       ex_valid_in;
assign ex_valid_in = id_valid_out;
logic                       ex_ready_in;
assign id_ready_out = ex_ready_in;

logic [XLEN-1:0]            ex_rs1_in;
assign ex_rs1_in = id_rs1_out;
logic [XLEN-1:0]            ex_rs2_in;
assign ex_rs2_in = id_rs2_out;
logic [XLEN-1:0]            ex_imm_in;
assign ex_imm_in = id_imm_out;

logic [4:0]                 ex_rd_in;
assign ex_rd_in = id_rd_out;
logic [ADDR_WIDTH-1:0]      ex_pc_in;
assign ex_pc_in = id_pc_out;
branch_type_t               ex_pc_branch_type_in;
assign ex_pc_branch_type_in = id_pc_addr_type_out;
logic                       ex_pc_jump_en_in;
assign ex_pc_jump_en_in = id_pc_jump_en_out;

logic                       ex_reg_write_in;
assign ex_reg_write_in = id_reg_write_out;
logic                       ex_mem_to_reg_in;
assign ex_mem_to_reg_in = id_mem_to_reg_out;
logic                       ex_mem_op_in;
assign ex_mem_op_in = id_mem_op_out;
ls_type_t                   ex_mem_op_type_in;
assign ex_mem_op_type_in = id_mem_op_type_out;

logic [IALU_OP_WIDTH-1:0]   ex_alu_op_in;
assign ex_alu_op_in = id_alu_op_out;
ALU_src1_t                  ex_alu_src_1_in;
assign ex_alu_src_1_in = id_alu_src_1_out;
ALU_src2_t                  ex_alu_src_2_in;
assign ex_alu_src_2_in = id_alu_src_2_out;

MDU_op_t                    ex_mdu_op_in;
assign ex_mdu_op_in = id_mdu_op_out;

logic                       ex_alu_en_in;
assign ex_alu_en_in = id_alu_en_out;
logic                       ex_mdu_en_in;
assign ex_mdu_en_in = id_mdu_en_out;

logic                       ex_valid_out;
logic                       ex_ready_out;

logic [XLEN-1:0]            ex_alu_out;
logic [XLEN-1:0]            ex_rs2_out;
logic [4:0]                 ex_rd_out;

logic [ADDR_WIDTH-1:0]      ex_pc_out;
assign dbg_pc_ex = ex_pc_out;

logic [XLEN-1:0]            ex_pc_branch_out;
assign fs_pc_in = ex_pc_branch_out;
logic                       ex_pc_we_out;
assign fs_pc_we_in = ex_pc_we_out;
assign id_flush_in = ex_pc_we_out;

logic                       ex_reg_write_out;
logic                       ex_mem_to_reg_out;
logic                       ex_mem_op_out;
ls_type_t                   ex_mem_op_type_out;

ExecStage #(
    .XLEN(32),
    .ADDR_WIDTH(32)
) exec_stage (
    .clk(clk),
    .arstn(arstn),

    .halt_req_in(halt_req_in),
    .halt_ack_out(halt_ack_out_ex),

    .valid_in(ex_valid_in),
    .ready_in(ex_ready_in),

    .rs1_in(ex_rs1_in),
    .rs2_in(ex_rs2_in),
    .imm_in(ex_imm_in),

    .rd_in(ex_rd_in),
    .pc_in(ex_pc_in),
    .pc_branch_type_in(ex_pc_branch_type_in),
    .pc_jump_en_in(ex_pc_jump_en_in),

    .reg_write_in(ex_reg_write_in),
    .mem_to_reg_in(ex_mem_to_reg_in),
    .mem_op_in(ex_mem_op_in),
    .mem_op_type_in(ex_mem_op_type_in),

    .alu_op_in(ex_alu_op_in),
    .alu_src_1_in(ex_alu_src_1_in),
    .alu_src_2_in(ex_alu_src_2_in),

    .mdu_op_in(ex_mdu_op_in),

    .alu_en_in(ex_alu_en_in),
    .mdu_en_in(ex_mdu_en_in),

    .valid_out(ex_valid_out),
    .ready_out(ex_ready_out),

    .alu_out(ex_alu_out),
    .rs2_out(ex_rs2_out),
    .rd_out(ex_rd_out),

    .pc_out(ex_pc_out),
    .pc_branch_out(ex_pc_branch_out),
    .pc_we_out(ex_pc_we_out),

    .reg_write_out(ex_reg_write_out),
    .mem_to_reg_out(ex_mem_to_reg_out),
    .mem_op_out(ex_mem_op_out),
    .mem_op_type_out(ex_mem_op_type_out)
);

// MEMORY STAGE

logic                       mem_valid_in;
assign mem_valid_in = ex_valid_out;
logic                       mem_ready_in;
assign ex_ready_out = mem_ready_in;

logic [XLEN-1:0]            mem_alu_in;
assign mem_alu_in = ex_alu_out;
logic [XLEN-1:0]            mem_rs2_in;
assign mem_rs2_in = ex_rs2_out;
logic [4:0]                 mem_rd_in;
assign mem_rd_in = ex_rd_out;
logic [ADDR_WIDTH-1:0]      mem_pc_in;
assign mem_pc_in = ex_pc_out;

logic                       mem_reg_write_in;
assign mem_reg_write_in = ex_reg_write_out;
logic                       mem_mem_to_reg_in;
assign mem_mem_to_reg_in = ex_mem_to_reg_out;
logic                       mem_mem_op_in;
assign mem_mem_op_in = ex_mem_op_out;
ls_type_t                   mem_mem_op_type_in;
assign mem_mem_op_type_in = ex_mem_op_type_out;


logic                       mem_valid_out;
logic                       mem_ready_out;

logic                       mem_reg_write_out;
logic                       mem_mem_to_reg_out;

logic [XLEN-1:0]            mem_alu_res_out;
logic [XLEN-1:0]            mem_mem_val_out;

logic [4:0]                 mem_rd_out;
logic [ADDR_WIDTH-1:0]      mem_pc_out;
assign dbg_pc_mem = mem_pc_out;

logic                       mem_mem_req_out;
logic                       mem_mem_ack_in;

logic [ADDR_WIDTH-1:0]      mem_mem_addr_out;
logic [XLEN-1:0]            mem_mem_write_data_out;
logic                       mem_mem_write_en_out;
logic [3:0]                 mem_mem_write_mask_out;
logic [XLEN-1:0]            mem_mem_data_in;

MemStage #(
    .XLEN(32),
    .ADDR_WIDTH(32)
) mem_stage (
    .clk(clk),
    .arstn(arstn),

    .halt_req_in(halt_req_in),
    .halt_ack_out(halt_ack_out_mem),

    .valid_in(mem_valid_in),
    .ready_in(mem_ready_in),

    .alu_in(mem_alu_in),
    .rs2_in(mem_rs2_in),
    .rd_in(mem_rd_in),
    .pc_in(mem_pc_in),

    .reg_write_in(mem_reg_write_in),
    .mem_to_reg_in(mem_mem_to_reg_in),
    .mem_op_in(mem_mem_op_in),
    .mem_op_type_in(mem_mem_op_type_in),

    .valid_out(mem_valid_out),
    .ready_out(mem_ready_out),

    .reg_write_out(mem_reg_write_out),
    .mem_to_reg_out(mem_mem_to_reg_out),

    .alu_res_out(mem_alu_res_out),
    .mem_val_out(mem_mem_val_out),

    .rd_out(mem_rd_out),
    .pc_out(mem_pc_out),

    .mem_req_out(mem_mem_req_out),
    .mem_ack_in(mem_mem_ack_in),

    .mem_addr_out(mem_mem_addr_out),
    .mem_write_data_out(mem_mem_write_data_out),
    .mem_write_en_out(mem_mem_write_en_out),
    .mem_write_mask_out(mem_mem_write_mask_out),
    .mem_data_in(mem_mem_data_in)
);

// WRITEBACK STAGE

logic                       wb_valid_in;
assign wb_valid_in = mem_valid_out;
logic                       wb_ready_in;
assign mem_ready_out = wb_ready_in;

logic                       wb_reg_write_in;
assign wb_reg_write_in = mem_reg_write_out;
logic                       wb_mem_to_reg_in;
assign wb_mem_to_reg_in = mem_mem_to_reg_out;

logic [XLEN-1:0]            wb_alu_res_in;
assign wb_alu_res_in = mem_alu_res_out;
logic [XLEN-1:0]            wb_mem_val_in;
assign wb_mem_val_in = mem_mem_val_out;

logic [4:0]                 wb_rd_in;
assign wb_rd_in = mem_rd_out;
logic [ADDR_WIDTH-1:0]      wb_pc_in;
assign wb_pc_in = mem_pc_out;

logic                       wb_reg_write_out;
assign id_rd_we_in = wb_reg_write_out;
logic [4:0]                 wb_rd_out;
assign id_rd_in = wb_rd_out;
logic [XLEN-1:0]            wb_res_out;
assign id_rd_val_in = wb_res_out;
logic [ADDR_WIDTH-1:0]      wb_pc_out;
assign dbg_pc_wb = wb_pc_out;

WriteBackStage #(
    .XLEN(32)
) writeback_stage (
    .clk(clk),
    .arstn(arstn),

    .valid_in(wb_valid_in),
    .ready_in(wb_ready_in),

    .reg_write_in(wb_reg_write_in),
    .mem_to_reg_in(wb_mem_to_reg_in),

    .alu_res_in(wb_alu_res_in),
    .mem_val_in(wb_mem_val_in),

    .rd_in(wb_rd_in),
    .pc_in(wb_pc_in),

    .reg_write_out(wb_reg_write_out),
    .rd_out(wb_rd_out),
    .res_out(wb_res_out),
    .pc_out(wb_pc_out)
);

// HALT controls

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        halt_req_in <= 1'b0;
    end
    else begin
        if (halt_req) halt_req_in <= 1'b1;
        else if (resume_req) halt_req_in <= 1'b0;

        halted <= m_is_halted;
    end
end

// MEM connectivity

always_comb begin
    if (m_is_halted) begin
        ram_addr = mem_debug_addr;
        ram_write_data = mem_debug_write_data;
        ram_we = mem_debug_wr_enable;
        ram_we_mask = mem_debug_wr_mask;
        ram_req = mem_debug_req;
        mem_debug_data = ram_data;
        mem_debug_ack = ram_ack;

        mem_mem_data_in = '0;
        mem_mem_ack_in = 1'b0;
    end
    else begin
        ram_addr = mem_mem_addr_out;
        ram_write_data = mem_mem_write_data_out;
        ram_we = mem_mem_write_en_out;
        ram_we_mask = mem_mem_write_mask_out;
        ram_req = mem_mem_req_out;
        mem_mem_data_in = ram_data;
        mem_mem_ack_in = ram_ack;

        mem_debug_data = '0;
        mem_debug_ack = 1'b0;
    end
end

endmodule