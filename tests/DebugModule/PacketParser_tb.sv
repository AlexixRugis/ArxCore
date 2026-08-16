`timescale 1ns / 1ps

module PacketParser_tb;

    localparam CLK_PERIOD = 10;
    localparam TIMEOUT = 100000;
    
    reg clk;
    reg arstn;
    
    reg         input_valid;
    wire        input_ready;
    reg         input_error;
    reg  [7:0]  input_byte;
    
    wire        res_valid;
    reg         res_ready;
    wire        res_error;
    wire [7:0]  res_cmd;
    wire [7:0]  res_id;
    wire [7:0]  res_len;
    wire [7:0]  res_data;
    reg  [7:0]  res_data_addr;
    reg         res_data_re;
    
    integer error_count = 0;
    integer test_count = 0;
    integer i, j;
    
    PacketParser dut (
        .clk            (clk),
        .arstn          (arstn),
        .input_valid    (input_valid),
        .input_ready    (input_ready),
        .input_error    (input_error),
        .input_byte     (input_byte),
        .res_valid      (res_valid),
        .res_ready      (res_ready),
        .res_error      (res_error),
        .res_cmd        (res_cmd),
        .res_id         (res_id),
        .res_len        (res_len),
        .res_data       (res_data),
        .res_data_addr  (res_data_addr),
        .res_data_re    (res_data_re)
    );
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    task send_byte(
        input [7:0] data,
        input error
    );
        @(posedge clk);
        #1
        input_valid = 1'b1;
        input_byte = data;
        input_error = error;
        while (~input_ready) @(posedge clk);
        @(posedge clk);
        #1
        input_valid = 1'b0;
        input_error = 1'b0;
    endtask
    
    task send_byte_ok(
        input [7:0] data
    );
        send_byte(data, 1'b0);
    endtask
    
    task send_packet_4(
        input [7:0] cmd,
        input [7:0] id,
        input [7:0] d0,
        input [7:0] d1,
        input [7:0] d2,
        input [7:0] d3
    );
        test_count = test_count + 1;
        $display("[TEST %0d] Sending packet: CMD=0x%0h, ID=0x%0h, LEN=4", 
                    test_count, cmd, id);
        
        send_byte_ok(cmd);
        send_byte_ok(id);
        send_byte_ok(8'h04);
        send_byte_ok(d0);
        send_byte_ok(d1);
        send_byte_ok(d2);
        send_byte_ok(d3);

        @(posedge clk);
        while (~res_valid) @(posedge clk);
        
        check_response_4(cmd, id, d0, d1, d2, d3, 1'b0);
        
        @(posedge clk);
        res_ready = 1'b1;
        @(posedge clk);
        res_ready = 1'b0;
        
        $display("[TEST %0d] Completed\n", test_count);
    endtask
    
    task send_empty_packet(
        input [7:0] cmd,
        input [7:0] id
    );
        test_count = test_count + 1;
        $display("[TEST %0d] Sending empty packet: CMD=0x%0h, ID=0x%0h", 
                    test_count, cmd, id);
        
        send_byte_ok(cmd);
        send_byte_ok(id);
        send_byte_ok(8'h00);
        
        @(posedge clk);
        while (~res_valid) @(posedge clk);
        
        check_response_empty(cmd, id, 1'b0);
        
        @(posedge clk);
        res_ready = 1'b1;
        @(posedge clk);
        res_ready = 1'b0;
        
        $display("[TEST %0d] Completed\n", test_count);
    endtask
    
    task check_response_4(
        input [7:0] exp_cmd,
        input [7:0] exp_id,
        input [7:0] exp_d0,
        input [7:0] exp_d1,
        input [7:0] exp_d2,
        input [7:0] exp_d3,
        input bit exp_error
    );
        reg ok;
        ok = 1'b1;
        
        if (res_cmd !== exp_cmd) begin
            $display("ERROR: CMD mismatch: expected 0x%0h, got 0x%0h", exp_cmd, res_cmd);
            ok = 1'b0;
        end
        
        if (res_id !== exp_id) begin
            $display("ERROR: ID mismatch: expected 0x%0h, got 0x%0h", exp_id, res_id);
            ok = 1'b0;
        end
        
        if (res_len !== 8'h04) begin
            $display("ERROR: LEN mismatch: expected 4, got %0d", res_len);
            ok = 1'b0;
        end
        
        if (res_error !== exp_error) begin
            $display("ERROR: ERROR flag mismatch: expected %0b, got %0b", exp_error, res_error);
            ok = 1'b0;
        end
        
        res_data_addr = 0;
        res_data_re = 1'b1;
        @(posedge clk);
        #1;
        if (res_data !== exp_d0) begin
            $display("ERROR: DATA[0] mismatch: expected 0x%0h, got 0x%0h", exp_d0, res_data);
            ok = 1'b0;
        end
        
        res_data_addr = 1;
        @(posedge clk);
        #1;
        if (res_data !== exp_d1) begin
            $display("ERROR: DATA[1] mismatch: expected 0x%0h, got 0x%0h", exp_d1, res_data);
            ok = 1'b0;
        end
        
        res_data_addr = 2;
        @(posedge clk);
        #1;
        if (res_data !== exp_d2) begin
            $display("ERROR: DATA[2] mismatch: expected 0x%0h, got 0x%0h", exp_d2, res_data);
            ok = 1'b0;
        end
        
        res_data_addr = 3;
        @(posedge clk);
        #1;
        if (res_data !== exp_d3) begin
            $display("ERROR: DATA[3] mismatch: expected 0x%0h, got 0x%0h", exp_d3, res_data);
            ok = 1'b0;
        end
        
        res_data_re = 1'b0;
        
        if (ok) begin
            $display("OK: Packet verified successfully");
        end else begin
            error_count = error_count + 1;
        end
    endtask
    
    task check_response_empty(
        input [7:0] exp_cmd,
        input [7:0] exp_id,
        input bit exp_error
    );
        reg ok;
        ok = 1'b1;
        
        if (res_cmd !== exp_cmd) begin
            $display("ERROR: CMD mismatch: expected 0x%0h, got 0x%0h", exp_cmd, res_cmd);
            ok = 1'b0;
        end
        
        if (res_id !== exp_id) begin
            $display("ERROR: ID mismatch: expected 0x%0h, got 0x%0h", exp_id, res_id);
            ok = 1'b0;
        end
        
        if (res_len !== 8'h00) begin
            $display("ERROR: LEN mismatch: expected 0, got %0d", res_len);
            ok = 1'b0;
        end
        
        if (res_error !== exp_error) begin
            $display("ERROR: ERROR flag mismatch: expected %0b, got %0b", exp_error, res_error);
            ok = 1'b0;
        end
        
        if (ok) begin
            $display("OK: Empty packet verified successfully");
        end else begin
            error_count = error_count + 1;
        end
    endtask
    
    task send_error_packet;
        test_count = test_count + 1;
        $display("[TEST %0d] Sending packet with parity error", test_count);
        
        send_byte(8'h03, 1'b1);
        
        @(posedge clk);
        while (~res_valid) @(posedge clk);
        
        if (res_error !== 1'b1) begin
            $display("ERROR: Expected error flag, but got 0");
            error_count = error_count + 1;
        end else begin
            $display("OK: Error correctly detected");
        end
        
        @(posedge clk);
        res_ready = 1'b1;
        @(posedge clk);
        res_ready = 1'b0;
        
        $display("[TEST %0d] Completed\n", test_count);
    endtask
    
    task send_max_packet(
        input [7:0] cmd,
        input [7:0] id
    );
        test_count = test_count + 1;
        $display("[TEST %0d] Sending max packet (255 bytes)", test_count);
        
        send_byte_ok(cmd);
        send_byte_ok(id);
        send_byte_ok(8'hFF);
        
        for (i = 0; i < 255; i = i + 1) begin
            send_byte_ok(i);
        end
        
        @(posedge clk);
        while (~res_valid) @(posedge clk);
        
        res_data_re = 1'b1;
        
        for (i = 0; i < 10; i = i + 1) begin
            res_data_addr = i;
            @(posedge clk);
            #1;
            if (res_data !== i) begin
                $display("ERROR: DATA[%0d] mismatch: expected 0x%0h, got 0x%0h", 
                            i, i, res_data);
                error_count = error_count + 1;
            end
        end
        
        res_data_re = 1'b0;
        
        @(posedge clk);
        res_ready = 1'b1;
        @(posedge clk);
        res_ready = 1'b0;
        
        $display("[TEST %0d] Completed\n", test_count);
    endtask
    
    task send_multiple_packets;
        $display("--- Testing multiple packets ---");
        
        // Packet 1
        test_count = test_count + 1;
        $display("[TEST %0d] First packet", test_count);
        send_byte_ok(8'h11);
        send_byte_ok(8'h22);
        send_byte_ok(8'h02);
        send_byte_ok(8'hAA);
        send_byte_ok(8'hBB);
        
        @(posedge clk);
        while (~res_valid) @(posedge clk);
        
        if (res_cmd !== 8'h11) $display("ERROR: CMD mismatch");
        if (res_id !== 8'h22) $display("ERROR: ID mismatch");
        if (res_len !== 8'h02) $display("ERROR: LEN mismatch");
        
        res_data_addr = 0;
        res_data_re = 1'b1;
        @(posedge clk);
        #1;
        if (res_data !== 8'hAA) $display("ERROR: DATA[0] mismatch");
        res_data_addr = 1;
        @(posedge clk);
        #1;
        if (res_data !== 8'hBB) $display("ERROR: DATA[1] mismatch");
        res_data_re = 1'b0;
        
        @(posedge clk);
        res_ready = 1'b1;
        @(posedge clk);
        res_ready = 1'b0;
        
        // Packet 2
        test_count = test_count + 1;
        $display("[TEST %0d] Second packet", test_count);
        send_byte_ok(8'h33);
        send_byte_ok(8'h44);
        send_byte_ok(8'h01);
        send_byte_ok(8'hCC);
        
        @(posedge clk);
        while (~res_valid) @(posedge clk);
        
        if (res_cmd !== 8'h33) $display("ERROR: CMD mismatch");
        if (res_id !== 8'h44) $display("ERROR: ID mismatch");
        if (res_len !== 8'h01) $display("ERROR: LEN mismatch");
        
        res_data_addr = 0;
        res_data_re = 1'b1;
        @(posedge clk);
        #1;
        if (res_data !== 8'hCC) $display("ERROR: DATA[0] mismatch");
        res_data_re = 1'b0;
        
        @(posedge clk);
        res_ready = 1'b1;
        @(posedge clk);
        res_ready = 1'b0;
        
        $display("--- Multiple packets completed ---\n");
    endtask
    
    initial begin
        #TIMEOUT;
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    initial begin
        $display("\n=== Starting PacketParser Testbench ===\n");
        $dumpfile("PacketParser_tb.vcd");
        $dumpvars(0, PacketParser_tb);
        
        arstn = 1'b0;
        input_valid = 1'b0;
        input_error = 1'b0;
        input_byte = 8'h00;
        res_ready = 1'b0;
        res_data_addr = 8'h00;
        res_data_re = 1'b0;
        
        error_count = 0;
        test_count = 0;
        
        repeat (5) @(posedge clk);
        arstn = 1'b1;
        repeat (5) @(posedge clk);
        
        $display("Reset complete, starting tests...\n");
        
        #100;
        send_packet_4(8'h01, 8'hAA, 8'h11, 8'h22, 8'h33, 8'h44);
        
        #100;
        send_empty_packet(8'h02, 8'hBB);
        
        #100;
        send_error_packet();
        
        #100;
        send_max_packet(8'h04, 8'hDD);
        
        #100;
        send_multiple_packets();
        
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
    
    // always @(posedge clk) begin
    //     if (res_valid) begin
    //         $display("DEBUG: Packet received: CMD=0x%0h, ID=0x%0h, LEN=%0d, ERROR=%0b", 
    //                  res_cmd, res_id, res_len, res_error);
    //     end
    // end

endmodule