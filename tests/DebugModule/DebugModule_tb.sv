`timescale 1ns / 1ps

module DebugModule_tb;

    localparam CLK_PERIOD = 10;  // 100 MHz
    localparam TIMEOUT = 200000;
    
    reg clk;
    reg arstn;
    
    // UART input
    reg         input_valid;
    wire        input_ready;
    reg         input_error;
    reg [7:0]   input_byte;
    
    // UART output
    wire [7:0]  send_byte;
    wire        send_valid;
    reg         send_ready;
    
    // core control
    wire        halt_req;
    wire        resume_req;
    reg         is_halted;
    
    // prog mem
    wire [31:0] prog_addr;
    wire [31:0] prog_write_data;
    wire        prog_wr_en;
    wire [3:0]  prog_wr_mask;
    wire        prog_req;
    reg  [31:0] prog_data;
    reg         prog_ack;
    
    // data mem
    wire [31:0] data_addr;
    wire [31:0] data_write_data;
    wire        data_wr_en;
    wire [3:0]  data_wr_mask;
    wire        data_req;
    reg  [31:0] data_data;
    reg         data_ack;

    // soft reset

    wire        soft_reset_n;
    
    // mems
    reg [31:0] prog_memory [0:1023];
    reg [31:0] data_memory [0:1023];
    
    // out packet
    reg [7:0]  out_status;
    reg [7:0]  out_id;
    reg [7:0]  out_len;
    reg [7:0]  out_bytes [0:255];

    integer error_count = 0;
    integer test_count = 0;
    integer i, j;
    
    DebugModule #(.TIMEOUT_TICKS(200)) dut (
        .clk(clk),
        .arstn(arstn),
        .input_valid(input_valid),
        .input_ready(input_ready),
        .input_error(input_error),
        .input_byte(input_byte),
        .send_byte(send_byte),
        .send_valid(send_valid),
        .send_ready(send_ready),
        .halt_req(halt_req),
        .resume_req(resume_req),
        .is_halted(is_halted),
        .prog_addr(prog_addr),
        .prog_write_data(prog_write_data),
        .prog_wr_en(prog_wr_en),
        .prog_wr_mask(prog_wr_mask),
        .prog_req(prog_req),
        .prog_data(prog_data),
        .prog_ack(prog_ack),
        .data_addr(data_addr),
        .data_write_data(data_write_data),
        .data_wr_en(data_wr_en),
        .data_wr_mask(data_wr_mask),
        .data_req(data_req),
        .data_data(data_data),
        .data_ack(data_ack),
        
        .soft_reset_n(soft_reset_n)
    );
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    always @(posedge clk) begin
        if (prog_req) begin
            if (prog_wr_en) begin
                if (prog_wr_mask[0]) prog_memory[prog_addr[11:2]][7:0]   <= prog_write_data[7:0];
                if (prog_wr_mask[1]) prog_memory[prog_addr[11:2]][15:8]  <= prog_write_data[15:8];
                if (prog_wr_mask[2]) prog_memory[prog_addr[11:2]][23:16] <= prog_write_data[23:16];
                if (prog_wr_mask[3]) prog_memory[prog_addr[11:2]][31:24] <= prog_write_data[31:24];
                $display("  PROG MEM WRITE[0x%0h] <= 0x%0h (mask=%b)", 
                         prog_addr, prog_write_data, prog_wr_mask);
                prog_ack <= 1'b1;
                prog_data <= 32'b0;
            end else begin
                prog_data <= prog_memory[prog_addr[11:2]];
                $display("  PROG MEM READ[0x%0h] => 0x%0h", 
                         prog_addr, prog_memory[prog_addr[11:2]]);
                prog_ack <= 1'b1;
            end
        end else begin
            prog_ack <= 1'b0;
            prog_data <= 32'b0;
        end
    end
    
    always @(posedge clk) begin
        if (data_req) begin
            if (data_wr_en) begin
                if (data_wr_mask[0]) data_memory[data_addr[11:2]][7:0]   <= data_write_data[7:0];
                if (data_wr_mask[1]) data_memory[data_addr[11:2]][15:8]  <= data_write_data[15:8];
                if (data_wr_mask[2]) data_memory[data_addr[11:2]][23:16] <= data_write_data[23:16];
                if (data_wr_mask[3]) data_memory[data_addr[11:2]][31:24] <= data_write_data[31:24];
                $display("  DATA MEM WRITE[0x%0h] <= 0x%0h (mask=%b)", 
                         data_addr, data_write_data, data_wr_mask);
                data_ack <= 1'b1;
                data_data <= 32'b0;
            end else begin
                data_data <= data_memory[data_addr[11:2]];
                $display("  DATA MEM READ[0x%0h] => 0x%0h", 
                         data_addr, data_memory[data_addr[11:2]]);
                data_ack <= 1'b1;
            end
        end else begin
            data_ack <= 1'b0;
            data_data <= 32'b0;
        end
    end
    
    task send_byte_task(input [7:0] data, input error = 0);
        begin
            @(posedge clk);
            #1;
            input_byte = data;
            input_error = error;
            input_valid = 1'b1;
            while (!input_ready) @(posedge clk);
            @(posedge clk);
            #1;
            input_valid = 1'b0;
            input_error = 1'b0;
        end
    endtask
    
    task send_packet(
        input [7:0] cmd,
        input [7:0] id,
        input [7:0] len,
        input [7:0] data[]
    );
        integer i;
        begin
            $display("  Sending packet: CMD=0x%0h, ID=0x%0h, LEN=%0d", cmd, id, len);
            send_byte_task(cmd);
            send_byte_task(id);
            send_byte_task(len);
            for (i = 0; i < len; i = i + 1) begin
                send_byte_task(data[i]);
            end
        end
    endtask
    
    task receive_response;
        integer i;
        $display("  Waiting for response...");
        
        @(posedge clk);
        while (!send_valid) @(posedge clk);
        #1;
        out_status = send_byte;
        send_ready = 1'b1;
        $display("    STATUS: 0x%0h", out_status);
        
        @(posedge clk);
        while (!send_valid) @(posedge clk);
        #1;
        out_id = send_byte;
        $display("    ID: 0x%0h", out_id);
        
        @(posedge clk);
        while (!send_valid) @(posedge clk);
        #1;
        out_len = send_byte;
        $display("    LEN: %0d", out_len);
        
        for (i = 0; i < out_len; i = i + 1) begin
            @(posedge clk);
            while (!send_valid) @(posedge clk);
            #1;
            out_bytes[i] = send_byte;
            $display("    DATA[%0d]: 0x%0h", i, send_byte);
        end
            
        @(posedge clk);
        #1;
        send_ready = 1'b0;
    endtask

    task test_soft_reset;
        logic [7:0] data[];
        data = new[0];

        test_count = test_count + 1;
        $display("\n[TEST %0d] SOFT RESET command", test_count);

        send_packet(8'h06, 8'hAA, 8'h00, data);

        repeat (3) @(posedge clk);
        if (soft_reset_n) begin
            $display("  ERROR: soft_reset_n not asserted");
            error_count = error_count + 1;
        end

        repeat (10) @(posedge clk);
        if (!soft_reset_n) begin
            $display("  ERROR: soft_reset_n not deasserted");
            error_count = error_count + 1;
        end

        receive_response();
        if (out_status !== 8'h00) begin
            $display("  ERROR: Expected STATUS_OK (0x00), got 0x%0h", out_status);
            error_count = error_count + 1;
        end
        if (out_id !== 8'hAA) begin
            $display("  ERROR: Expected ID 0xAA, got 0x%0h", out_id);
            error_count = error_count + 1;
        end
        if (out_len !== 8'h00) begin
            $display("  ERROR: Expected LEN 0, got %0d", out_len);
            error_count = error_count + 1;
        end
        
        $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
    endtask
    
    task test_halt;
        logic [7:0] data[];
        data = new[0];

        test_count = test_count + 1;
        $display("\n[TEST %0d] HALT command", test_count);
        
        is_halted = 1'b0;
        send_packet(8'h00, 8'hAA, 8'h00, data);
        
        repeat (5) @(posedge clk);
        if (!halt_req) begin
            $display("  ERROR: halt_req not asserted");
            error_count = error_count + 1;
        end
        
        is_halted = 1'b1;
        
        receive_response();
        if (out_status !== 8'h00) begin
            $display("  ERROR: Expected STATUS_OK (0x00), got 0x%0h", out_status);
            error_count = error_count + 1;
        end
        if (out_id !== 8'hAA) begin
            $display("  ERROR: Expected ID 0xAA, got 0x%0h", out_id);
            error_count = error_count + 1;
        end
        if (out_len !== 8'h00) begin
            $display("  ERROR: Expected LEN 0, got %0d", out_len);
            error_count = error_count + 1;
        end
        
        $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
    endtask
    
    task test_resume;
        reg [7:0] data[];
        data = new[0];
        test_count = test_count + 1;
        $display("\n[TEST %0d] RESUME command", test_count);
        
        is_halted = 1'b1;
        send_packet(8'h01, 8'hBB, 8'h00, data);
        
        repeat (5) @(posedge clk);
        if (!resume_req) begin
            $display("  ERROR: resume_req not asserted");
            error_count = error_count + 1;
        end
        
        is_halted = 1'b0;
        
        receive_response();
        
        if (out_status !== 8'h00) begin
            $display("  ERROR: Expected STATUS_OK (0x00), got 0x%0h", out_status);
            error_count = error_count + 1;
        end
        if (out_id !== 8'hBB) begin
            $display("  ERROR: Expected ID 0xBB, got 0x%0h", out_id);
            error_count = error_count + 1;
        end
        
        $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
    endtask

    task test_get_state(
        input bit halt_state
    );
    reg [7:0] data[];
    bit old_halt_state;
    data = new[0];

    test_count = test_count + 1;
    $display("\n[TEST %0d] GET_STATE command (halt_state=%d)", test_count, halt_state);

    old_halt_state = is_halted;
    #1
    is_halted = halt_state;
    send_packet(8'h07, 8'hAB, 8'h00, data);
    receive_response();

    if (out_status !== 8'h00) begin
        $display("  ERROR: Expected STATUS_OK (0x00), got 0x%0h", out_status);
        error_count = error_count + 1;
    end
    if (out_id !== 8'hAB) begin
        $display("  ERROR: Expected ID 0xBB, got 0x%0h", out_id);
        error_count = error_count + 1;
    end
    if (out_len != 8'h01) begin
        $display("  ERROR: Expected LEN 0x01, got 0x%0h", out_len);
        error_count = error_count + 1;
    end
    if (out_bytes[0] != { 7'b0, halt_state }) begin
        $display("  ERROR: Expected STATE 0x%0h, got 0x%0h", { 7'b0, halt_state }, out_bytes[0]);
        error_count = error_count + 1;
    end

    is_halted = old_halt_state;
    $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
    endtask
    
    task test_prog_write;
        reg [31:0] check_data;
        begin
            test_count = test_count + 1;
            $display("\n[TEST %0d] Program memory write", test_count);
            
            is_halted = 1'b1;
            
            send_byte_task(8'h03);  // CMD_WRITE_PROG
            send_byte_task(8'hCC);  // ID
            send_byte_task(8'h08);  // LEN = 4(addr) + 4(data)
            send_byte_task(8'h00);  // addr[31:24]
            send_byte_task(8'h00);  // addr[23:16]
            send_byte_task(8'h05);  // addr[15:8]
            send_byte_task(8'h78);  // addr[7:0]
            send_byte_task(8'hAA);  // data[0]
            send_byte_task(8'hBB);  // data[1]
            send_byte_task(8'hCC);  // data[2]
            send_byte_task(8'hDD);  // data[3]
            
            repeat (50) @(posedge clk);

            receive_response();
            
            check_data = prog_memory[32'h00000578 >> 2];
            if (check_data !== 32'hDDCCBBAA) begin
                $display("  ERROR: Memory[0x00000578] expected 0xDDCCBBAA, got 0x%0h", check_data);
                error_count = error_count + 1;
            end else begin
                $display("  Memory[0x00000578] = 0xDDCCBBAA OK");
            end
            
            $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
        end
    endtask
    
    task test_prog_read;
        integer i;
        reg ok;
        test_count = test_count + 1;
        $display("\n[TEST %0d] Program memory read", test_count);
        
        prog_memory[32'h00000120 >> 2] = 32'h11124134;
        prog_memory[32'h00000124 >> 2] = 32'haa443322;
        
        is_halted = 1'b1;
        
        send_byte_task(8'h02);  // CMD_READ_PROG
        send_byte_task(8'hDD);  // ID
        send_byte_task(8'h05);  // LEN = 4(addr) + 1(cnt)
        send_byte_task(8'h00);  // addr[31:24]
        send_byte_task(8'h00);  // addr[23:16]
        send_byte_task(8'h01);  // addr[15:8]
        send_byte_task(8'h23);  // addr[7:0]
        send_byte_task(8'h04);  // read_len = 4 байта
        
        receive_response();
        
        if (out_status !== 8'h00) begin
            $display("  ERROR: Expected STATUS_OK, got 0x%0h", out_status);
            error_count = error_count + 1;
        end
        if (out_id !== 8'hDD) begin
            $display("  ERROR: Expected ID 0xDD, got 0x%0h", out_id);
            error_count = error_count + 1;
        end
        if (out_len !== 8'h04) begin
            $display("  ERROR: Expected LEN 4, got %0d", out_len);
            error_count = error_count + 1;
        end
        
        ok = 1'b1;
        if (out_bytes[0] !== 8'h11) begin
            $display("  ERROR: DATA[0] expected 0x11, got 0x%0h", out_bytes[0]);
            ok = 1'b0;
        end
        if (out_bytes[1] !== 8'h22) begin
            $display("  ERROR: DATA[1] expected 0x22, got 0x%0h", out_bytes[1]);
            ok = 1'b0;
        end
        if (out_bytes[2] !== 8'h33) begin
            $display("  ERROR: DATA[2] expected 0x33, got 0x%0h", out_bytes[2]);
            ok = 1'b0;
        end
        if (out_bytes[3] !== 8'h44) begin
            $display("  ERROR: DATA[3] expected 0x44, got 0x%0h", out_bytes[3]);
            ok = 1'b0;
        end
        
        if (ok) $display("  Data read correctly: 0x%0h 0x%0h 0x%0h 0x%0h", 
                        out_bytes[0], out_bytes[1], out_bytes[2], out_bytes[3]);
        else error_count = error_count + 1;
        
        $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
    endtask
    
    task test_data_write;
        reg [31:0] check_data;
        test_count = test_count + 1;
        $display("\n[TEST %0d] Data memory write", test_count);
        
        is_halted = 1'b1;
        
        send_byte_task(8'h05);  // CMD_WRITE_DATA
        send_byte_task(8'hEE);  // ID
        send_byte_task(8'h08);  // LEN
        send_byte_task(8'h00);  // addr[31:24]
        send_byte_task(8'h00);  // addr[23:16]
        send_byte_task(8'h0f);  // addr[15:8]
        send_byte_task(8'h20);  // addr[7:0]
        send_byte_task(8'h11);  // data[0]
        send_byte_task(8'h22);  // data[1]
        send_byte_task(8'h33);  // data[2]
        send_byte_task(8'h44);  // data[3]
        
        repeat (50) @(posedge clk);

        receive_response();
        
        check_data = data_memory[32'h00000f20 >> 2];
        if (check_data !== 32'h44332211) begin
            $display("  ERROR: Memory[0x00000f20] expected 0x44332211, got 0x%0h", check_data);
            error_count = error_count + 1;
        end else begin
            $display("  Memory[0x00000f20] = 0x44332211 OK");
        end
        
        $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
    endtask

    task test_data_read;
        integer i;
        reg ok;
        test_count = test_count + 1;
        $display("\n[TEST %0d] Data memory read", test_count);
        
        data_memory[32'h00000120 >> 2] = 32'h11124134;
        data_memory[32'h00000124 >> 2] = 32'haa443322;
        
        is_halted = 1'b1;
        
        send_byte_task(8'h04);  // CMD_READ_DATA
        send_byte_task(8'hDD);  // ID
        send_byte_task(8'h05);  // LEN = 4(addr) + 1(cnt)
        send_byte_task(8'h00);  // addr[31:24]
        send_byte_task(8'h00);  // addr[23:16]
        send_byte_task(8'h01);  // addr[15:8]
        send_byte_task(8'h23);  // addr[7:0]
        send_byte_task(8'h04);  // read_len
        
        receive_response();
        
        if (out_status !== 8'h00) begin
            $display("  ERROR: Expected STATUS_OK, got 0x%0h", out_status);
            error_count = error_count + 1;
        end
        if (out_id !== 8'hDD) begin
            $display("  ERROR: Expected ID 0xDD, got 0x%0h", out_id);
            error_count = error_count + 1;
        end
        if (out_len !== 8'h04) begin
            $display("  ERROR: Expected LEN 4, got %0d", out_len);
            error_count = error_count + 1;
        end
        
        ok = 1'b1;
        if (out_bytes[0] !== 8'h11) begin
            $display("  ERROR: DATA[0] expected 0x11, got 0x%0h", out_bytes[0]);
            ok = 1'b0;
        end
        if (out_bytes[1] !== 8'h22) begin
            $display("  ERROR: DATA[1] expected 0x22, got 0x%0h", out_bytes[1]);
            ok = 1'b0;
        end
        if (out_bytes[2] !== 8'h33) begin
            $display("  ERROR: DATA[2] expected 0x33, got 0x%0h", out_bytes[2]);
            ok = 1'b0;
        end
        if (out_bytes[3] !== 8'h44) begin
            $display("  ERROR: DATA[3] expected 0x44, got 0x%0h", out_bytes[3]);
            ok = 1'b0;
        end
        
        if (ok) $display("  Data read correctly: 0x%0h 0x%0h 0x%0h 0x%0h", 
                        out_bytes[0], out_bytes[1], out_bytes[2], out_bytes[3]);
        else error_count = error_count + 1;
        
        $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
    endtask
    
    task test_unknown_cmd;
        reg [7:0] data[];
        data = new[0];
        test_count = test_count + 1;
        $display("\n[TEST %0d] Unknown command", test_count);
        
        send_packet(8'hFF, 8'hFF, 8'h00, data);
        
        receive_response();
        
        if (out_status !== 8'hFD) begin  // STATUS_ERROR_CMD
            $display("  ERROR: Expected STATUS_ERROR_CMD (0xFD), got 0x%0h", out_status);
            error_count = error_count + 1;
        end
        
        $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
    endtask
    
    task test_parity_error;
        test_count = test_count + 1;
        $display("\n[TEST %0d] Parity error", test_count);
        
        send_byte_task(8'h00, 1'b1);
        
        receive_response();
        
        if (out_status !== 8'hFF) begin  // STATUS_ERROR_PARITY
            $display("  ERROR: Expected STATUS_ERROR_PARITY (0xFF), got 0x%0h", out_status);
            error_count = error_count + 1;
        end
        
        $display("  [TEST %0d] %s", test_count, error_count ? "FAILED" : "PASSED");
    endtask
    
    task init_memory;
        begin
            for (i = 0; i < 1024; i = i + 1) begin
                prog_memory[i] = 32'h00000000;
                data_memory[i] = 32'h00000000;
            end
        end
    endtask
    
    initial begin
        #TIMEOUT;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
    initial begin
        $display("\n=== DebugModule Testbench ===");
        $dumpfile("DebugModule_tb.vcd");
        $dumpvars(0, DebugModule_tb);
        
        arstn = 1'b0;
        input_valid = 1'b0;
        input_error = 1'b0;
        input_byte = 8'h00;
        send_ready = 1'b0;
        is_halted = 1'b0;
        prog_ack = 1'b0;
        prog_data = 32'b0;
        data_ack = 1'b0;
        data_data = 32'b0;
        
        init_memory();
        error_count = 0;
        test_count = 0;
        
        repeat (5) @(posedge clk);
        #1;
        arstn = 1'b1;
        repeat (5) @(posedge clk);
        #1;
        
        $display("\nReset complete, starting tests...\n");
        
        test_halt();
        #200;
        
        test_resume();
        #200;
        
        test_prog_write();
        #500;
        
        test_prog_read();
        #500;
        
        test_data_write();
        #500;

        test_data_read();
        #500;
        
        test_unknown_cmd();
        #200;
        
        test_parity_error();
        #200;

        test_soft_reset();
        #200;

        test_get_state(1'b0);
        #200

        test_get_state(1'b1);
        #200

        #1000;
        
        $display("\n=== Test Summary ===");
        $display("Total tests:  %0d", test_count);
        $display("Errors:       %0d", error_count);
        
        if (error_count == 0) begin
            $display("\nALL TESTS PASSED\n");
        end else begin
            $display("\nSOME TESTS FAILED\n");
        end
        
        $finish;
    end

endmodule