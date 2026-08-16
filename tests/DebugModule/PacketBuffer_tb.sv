`timescale 1ns / 1ps

module PacketBuffer_tb;

    localparam CLK_PERIOD = 10;
    localparam TIMEOUT = 100000;
    
    reg clk;
    reg arstn;
    
    reg [7:0] status;
    reg       status_we;
    reg [7:0] id;
    reg       id_we;
    reg [7:0] len;
    reg       len_we;
    reg [7:0] payload_addr;
    reg [7:0] payload;
    reg       payload_we;
    
    reg       send_req;
    wire      send_ack;
    wire [7:0] send_data;
    wire      send_valid;
    reg       send_ready;
    
    integer error_count = 0;
    integer test_count = 0;
    integer i, j;
    
    PacketBuffer dut (
        .clk           (clk),
        .arstn         (arstn),
        .status        (status),
        .status_we     (status_we),
        .id            (id),
        .id_we         (id_we),
        .len           (len),
        .len_we        (len_we),
        .payload_addr  (payload_addr),
        .payload       (payload),
        .payload_we    (payload_we),
        .send_req      (send_req),
        .send_ack      (send_ack),
        .send_data     (send_data),
        .send_valid    (send_valid),
        .send_ready    (send_ready)
    );
    
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    task write_status(input [7:0] value);
        @(posedge clk);
        #1;
        status <= value;
        status_we <= 1'b1;
        @(posedge clk);
        #1;
        status_we <= 1'b0;
    endtask
    
    task write_id(input [7:0] value);
        @(posedge clk);
        #1;
        id <= value;
        id_we <= 1'b1;
        @(posedge clk);
        #1;
        id_we <= 1'b0;
    endtask
    
    task write_len(input [7:0] value);
        @(posedge clk);
        #1;
        len <= value;
        len_we <= 1'b1;
        @(posedge clk);
        #1;
        len_we <= 1'b0;
    endtask
    
    task write_payload(input [7:0] addr, input [7:0] data);
        @(posedge clk);
        #1;
        payload_addr <= addr;
        payload <= data;
        payload_we <= 1'b1;
        @(posedge clk);
        #1;
        payload_we <= 1'b0;
    endtask
    
    task write_payload_array(input [7:0] start_addr, input [7:0] data[], input int size);
        for (i = 0; i < size; i = i + 1) begin
            write_payload(start_addr + i, data[i]);
        end
    endtask
    
    task init_packet(
        input [7:0] test_status,
        input [7:0] test_id,
        input [7:0] test_len,
        input [7:0] test_data[],
        input int data_size
    );
        write_status(test_status);
        write_id(test_id);
        write_len(test_len);
        if (data_size > 0) begin
            write_payload_array(0, test_data, data_size);
        end
    endtask
    
    task send_and_check(
        input [7:0] exp_status,
        input [7:0] exp_id,
        input [7:0] exp_len,
        input [7:0] exp_data[],
        input int exp_size,
        input string test_name
    );
        reg [7:0] received_data[0:255];
        reg ok;
        
        test_count = test_count + 1;
        $display("\n[TEST %0d] %s", test_count, test_name);
        $display("  Starting transmission...");
        
        @(posedge clk);
        #1;
        send_req = 1'b1;
        
        @(posedge clk);
        #1;
        send_req = 1'b0;
        
        ok = 1'b1;
        
        @(posedge clk);
        #1;
        if (send_valid !== 1'b1) begin
            $display("  ERROR: send_valid not asserted for STATUS");
            ok = 1'b0;
        end
        if (send_data !== exp_status) begin
            $display("  ERROR: STATUS expected 0x%0h, got 0x%0h", exp_status, send_data);
            ok = 1'b0;
        end else begin
            $display("  STATUS: 0x%0h OK", send_data);
        end
        send_ready = 1'b1;
        
        @(posedge clk);
        #1;
        if (send_valid !== 1'b1) begin
            $display("  ERROR: send_valid not asserted for ID");
            ok = 1'b0;
        end
        if (send_data !== exp_id) begin
            $display("  ERROR: ID expected 0x%0h, got 0x%0h", exp_id, send_data);
            ok = 1'b0;
        end else begin
            $display("  ID: 0x%0h OK", send_data);
        end
        
        @(posedge clk);
        #1;
        if (send_valid !== 1'b1) begin
            $display("  ERROR: send_valid not asserted for LEN");
            ok = 1'b0;
        end
        if (send_data !== exp_len) begin
            $display("  ERROR: LEN expected 0x%0h, got 0x%0h", exp_len, send_data);
            ok = 1'b0;
        end else begin
            $display("  LEN: %0d OK", send_data);
        end
        
        for (i = 0; i < exp_size; i = i + 1) begin
            @(posedge clk);
            #1;
            if (send_valid !== 1'b1) begin
                $display("  ERROR: send_valid not asserted for DATA[%0d]", i);
                ok = 1'b0;
            end
            if (send_data !== exp_data[i]) begin
                $display("  ERROR: DATA[%0d] expected 0x%0h, got 0x%0h", 
                         i, exp_data[i], send_data);
                ok = 1'b0;
            end else begin
                $display("  DATA[%0d]: 0x%0h OK", i, send_data);
            end
            received_data[i] = send_data;
        end
        
        if (send_ack !== 1'b1) begin
            $display("  ERROR: send_ack not asserted at end of transmission");
            ok = 1'b0;
        end else begin
            $display("  send_ack OK at end");
        end
        
        @(posedge clk);
        #1;
        send_ready = 1'b0;
        if (send_valid !== 1'b0) begin
            $display("  ERROR: send_valid still asserted after transmission");
            ok = 1'b0;
        end
        
        if (ok) begin
            $display("  [OK] Test passed");
        end else begin
            $display("  [FAIL] Test failed");
            error_count = error_count + 1;
        end
    endtask
    
    task test_empty_packet;
        reg [7:0] empty_data[];
        empty_data = new[0];
        init_packet(8'h00, 8'hAA, 8'h00, empty_data, 0);
        send_and_check(8'h00, 8'hAA, 8'h00, empty_data, 0, "Empty packet (LEN=0)");
    endtask
    
    task test_one_byte;
        reg [7:0] test_data[];
        test_data = new[1];
        test_data[0] = 8'h55;
        init_packet(8'h01, 8'hBB, 8'h01, test_data, 1);
        send_and_check(8'h01, 8'hBB, 8'h01, test_data, 1, "One byte packet");
    endtask
    
    task test_few_bytes;
        reg [7:0] test_data[];
        test_data = new[4];
        test_data[0] = 8'h11;
        test_data[1] = 8'h22;
        test_data[2] = 8'h33;
        test_data[3] = 8'h44;
        init_packet(8'h02, 8'hCC, 8'h04, test_data, 4);
        send_and_check(8'h02, 8'hCC, 8'h04, test_data, 4, "Four bytes packet");
    endtask
    
    task test_max_packet;
        reg [7:0] test_data[];
        test_data = new[255];
        
        for (i = 0; i < 255; i = i + 1) begin
            test_data[i] = i;
        end
        
        init_packet(8'h03, 8'hDD, 8'hFF, test_data, 255);
        send_and_check(8'h03, 8'hDD, 8'hFF, test_data, 255, "Maximum packet (255 bytes)");
    endtask
    
    task test_two_packets;
        reg [7:0] data1[];
        reg [7:0] data2[];
        data1 = new[2];
        data2 = new[3];
        
        data1[0] = 8'h11;
        data1[1] = 8'h22;
        data2[0] = 8'h33;
        data2[1] = 8'h44;
        data2[2] = 8'h55;
        
        $display("\n[TEST] Two packets in sequence");
        
        init_packet(8'h05, 8'h11, 8'h02, data1, 2);
        send_and_check(8'h05, 8'h11, 8'h02, data1, 2, "First packet");
        
        init_packet(8'h06, 8'h22, 8'h03, data2, 3);
        send_and_check(8'h06, 8'h22, 8'h03, data2, 3, "Second packet");
    endtask
    
    task test_random_access;
        reg [7:0] test_data[];
        test_data = new[4];
        
        $display("\n[TEST] Random payload access");
        
        write_status(8'h07);
        write_id(8'h33);
        write_len(8'h04);
        
        write_payload(8'h02, 8'hAA);
        write_payload(8'h00, 8'hBB);
        write_payload(8'h03, 8'hCC);
        write_payload(8'h01, 8'hDD);
        
        test_data[0] = 8'hBB;
        test_data[1] = 8'hDD;
        test_data[2] = 8'hAA;
        test_data[3] = 8'hCC;
        
        send_and_check(8'h07, 8'h33, 8'h04, test_data, 4, "Random access test");
    endtask
    
    initial begin
        #TIMEOUT;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
    initial begin
        $display("\n=== PacketBuffer Testbench ===");
        $dumpfile("PacketBuffer_tb.vcd");
        $dumpvars(0, PacketBuffer_tb);
        
        arstn = 1'b0;
        status = 8'h00;
        status_we = 1'b0;
        id = 8'h00;
        id_we = 1'b0;
        len = 8'h00;
        len_we = 1'b0;
        payload_addr = 8'h00;
        payload = 8'h00;
        payload_we = 1'b0;
        send_req = 1'b0;
        send_ready = 1'b0;
        
        error_count = 0;
        test_count = 0;
        
        repeat (5) @(posedge clk);
        #1;
        arstn = 1'b1;
        repeat (5) @(posedge clk);
        #1;
        
        $display("\nReset complete, starting tests...\n");
        
        test_empty_packet();
        #100;
        
        test_one_byte();
        #100;
        
        test_few_bytes();
        #100;
        
        test_max_packet();
        #200;
        
        test_two_packets();
        #100;
        
        test_random_access();
        #100;
        
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