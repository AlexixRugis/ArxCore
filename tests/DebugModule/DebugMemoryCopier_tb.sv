`timescale 1ns / 1ps

module DebugMemoryCopier_tb;

    // Параметры
    localparam CLK_PERIOD = 10;  // 100 MHz
    localparam TIMEOUT = 100000;
    
    // Сигналы
    reg clk;
    reg arstn;
    
    // Управляющие сигналы
    reg         copy_req;
    reg         copy_write;
    wire        copy_ready;
    
    // Входной пакет (от PacketParser)
    reg  [7:0]  inp_packet_len;
    reg  [7:0]  inp_packet_data;
    wire [7:0]  inp_packet_data_addr;
    wire        inp_packet_re;
    
    // Выходной пакет (к PacketBuffer)
    wire [7:0]  out_packet_data;
    wire [7:0]  out_packet_data_addr;
    wire        out_packet_we;
    
    // Интерфейс с памятью
    wire [31:0] data_addr;
    wire [31:0] data_write_data;
    wire        data_wr_en;
    wire [3:0]  data_wr_mask;
    wire        data_req;
    reg  [31:0] data_data;
    reg         data_ack;
    
    // Модель памяти (простая)
    reg [31:0] memory [0:255];  // 256 слов памяти

    reg [31:0] inp_packet_buf [0:255];
    reg [31:0] out_packet_buf [0:255];
    
    // Для отслеживания
    integer error_count = 0;
    integer test_count = 0;
    integer i, j;
    
    // Инстанс тестируемого модуля
    DebugMemoryCopier dut (
        .clk                (clk),
        .arstn              (arstn),
        .copy_req           (copy_req),
        .copy_write         (copy_write),
        .copy_ready         (copy_ready),
        .inp_packet_len     (inp_packet_len),
        .inp_packet_data    (inp_packet_data),
        .inp_packet_data_addr (inp_packet_data_addr),
        .inp_packet_re      (inp_packet_re),
        .out_packet_data    (out_packet_data),
        .out_packet_data_addr (out_packet_data_addr),
        .out_packet_we      (out_packet_we),
        .data_addr          (data_addr),
        .data_write_data    (data_write_data),
        .data_wr_en         (data_wr_en),
        .data_wr_mask       (data_wr_mask),
        .data_req           (data_req),
        .data_data          (data_data),
        .data_ack           (data_ack)
    );
    
    // Генерация тактового сигнала
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    always @(posedge clk) begin
        if (inp_packet_re) begin
            inp_packet_data <= inp_packet_buf[inp_packet_data_addr];
        end
    end

    always @(posedge clk) begin
        if (out_packet_we) begin
            out_packet_buf[out_packet_data_addr] <= out_packet_data;
        end
    end
    
    // Модель памяти - обработка запросов
    always @(posedge clk) begin
        if (data_req) begin
            if (data_wr_en) begin
                // Запись в память

                memory[data_addr[9:2]] <= memory[data_addr[9:2]] & ~{{8{data_wr_mask[3]}},{8{data_wr_mask[2]}},{8{data_wr_mask[1]}},{8{data_wr_mask[0]}}} |
                    data_write_data & {{8{data_wr_mask[3]}},{8{data_wr_mask[2]}},{8{data_wr_mask[1]}},{8{data_wr_mask[0]}}};
                $display("  MEM WRITE[0x%0h] <= 0x%0h, mask = 0x%0h", data_addr, data_write_data, data_wr_mask);
                data_ack <= 1'b1;
                data_data <= 32'b0;
            end else begin
                // Чтение из памяти
                data_data <= memory[data_addr[9:2]];
                $display("  MEM READ[0x%0h] => 0x%0h", data_addr, memory[data_addr[9:2]]);
                data_ack <= 1'b1;
            end
        end else begin
            data_ack <= 1'b0;
            data_data <= 32'b0;
        end
    end
    
    // Задача для инициализации памяти тестовыми данными
    task init_memory();
        for (i = 0; i < 256; i = i + 1) begin
            memory[i] = 32'h00000000;
        end
    endtask
    
    // Задача для заполнения памяти паттерном
    task fill_memory_pattern(input [31:0] base_addr, input int count);
        for (i = 0; i < count; i = i + 1) begin
            memory[base_addr[9:2] + i] = 32'h01010101 * i;
        end
    endtask
    
    // Задача для отправки байта во входной пакет
    task set_inp_byte(input [7:0] addr, input [7:0] data);
        inp_packet_buf[addr] = data;
    endtask
    
    // Задача для отправки пакета на запись в память
    task send_write_packet(
        input [31:0] address,
        input [7:0]  data_len,
        input [7:0]  data[]
    );
        integer i;
        begin
            test_count = test_count + 1;
            $display("\n[TEST %0d] Write packet: addr=0x%0h, len=%0d bytes", 
                     test_count, address, data_len);
            
            copy_write = 1'b1;
            inp_packet_len = 8'h04 + data_len;  // 4 байта адреса + данные
            
            // Отправляем адрес (4 байта, big-endian)
            set_inp_byte(8'h00, address[31:24]);
            set_inp_byte(8'h01, address[23:16]);
            set_inp_byte(8'h02, address[15:8]);
            set_inp_byte(8'h03, address[7:0]);
            
            // Отправляем данные
            for (i = 0; i < data_len; i = i + 1) begin
                set_inp_byte(8'h04 + i, data[i]);
            end

            // Запускаем копирование
            @(posedge clk);
            #1;
            copy_req = 1'b1;
            @(posedge clk);
            #1;
            copy_req = 1'b0;
            
            
            // Ждем завершения
            @(posedge clk);
            while (!copy_ready) @(posedge clk);
            #1;
            
            $display("  Write completed");
        end
    endtask
    
    // Задача для отправки пакета на чтение из памяти
    task send_read_packet(
        input [31:0] address,
        input [7:0]  data_len
    );
        integer i;
        reg [7:0] expected_data;
        reg ok;
        begin
            test_count = test_count + 1;
            $display("\n[TEST %0d] Read packet: addr=0x%0h, len=%0d bytes", 
                     test_count, address, data_len);
            
            copy_write = 1'b0;
            inp_packet_len = 8'h05;  // 4 байта адреса + длина данных
            
            // Отправляем адрес (4 байта)
            set_inp_byte(8'h00, address[31:24]);
            set_inp_byte(8'h01, address[23:16]);
            set_inp_byte(8'h02, address[15:8]);
            set_inp_byte(8'h03, address[7:0]);
            
            // Отправляем длину данных
            set_inp_byte(8'h04, data_len);

            // Запускаем копирование
            @(posedge clk);
            #1;
            copy_req = 1'b1;
            @(posedge clk);
            #1;
            copy_req = 1'b0;
            
            // Ждем завершения
            @(posedge clk);
            while (!copy_ready) @(posedge clk);
            #1;

                        // Проверяем выходные данные
            $display("  Checking read data:");
            ok = 1'b1;
            
            for (i = 0; i < data_len; i = i + 1) begin                
                expected_data = memory[(address + i) >> 2] >> (8*((address + i) & 3));
                expected_data = expected_data & 8'hFF;
                
                if (out_packet_buf[i] !== expected_data) begin
                    $display("  ERROR: DATA[%0d] expected 0x%0h, got 0x%0h", 
                             i, expected_data, out_packet_buf[i]);
                    ok = 1'b0;
                    error_count = error_count + 1;
                end else begin
                    $display("  DATA[%0d] = 0x%0h OK", i, out_packet_buf[i]);
                end
            end
            
            if (ok) $display("  Read completed OK");
        end
    endtask
    
    // Тест 1: Запись одного байта
    task test_write_one_byte;
        reg [7:0] data[];
        data = new[1];
        data[0] = 8'hAA;
        
        send_write_packet(32'h0010, 8'h01, data);
        
        // Проверка
        if (memory[32'h0010 >> 2] !== 32'h000000AA) begin
            $display("  ERROR: Memory[0x1000] expected 0xAA, got 0x%0h", 
                     memory[32'h1000 >> 2]);
            error_count = error_count + 1;
        end else begin
            $display("  Memory[0x1000] = 0xAA OK");
        end
    endtask
    
    // Тест 2: Запись четырех байт
    task test_write_four_bytes;
        reg [7:0] data[];
        data = new[4];
        data[0] = 8'h11;
        data[1] = 8'h22;
        data[2] = 8'h33;
        data[3] = 8'h44;
        
        send_write_packet(32'h0020, 8'h04, data);
        
        // Проверка
        if (memory[32'h0020 >> 2] !== 32'h44332211) begin
            $display("  ERROR: Memory[0x0020] expected 0x44332211, got 0x%0h", 
                     memory[32'h0020 >> 2]);
            error_count = error_count + 1;
        end else begin
            $display("  Memory[0x2000] = 0x44332211 OK");
        end
    endtask
    
    // Тест 3: Запись 251 байт (максимум)
    task test_write_max;
        reg [7:0] data[];
        integer i;
        data = new[251];
        
        for (i = 0; i < 251; i = i + 1) begin
            data[i] = i;
        end
        
        send_write_packet(32'h0000, 8'hFF - 8'h04, data);
        
        // Проверка нескольких байт
        for (i = 0; i < 10; i = i + 1) begin
            if ((memory[(32'h0000 + i) >> 2] >> (8*(i & 3)) & 8'hFF) !== i) begin
                $display("  ERROR: Memory[0x%0h] expected 0x%0h but got 0x%0h", 
                         32'h0000 + i, i, memory[(32'h0000 + i) >> 2] >> (8*(i & 3)) & 8'hFF);
                error_count = error_count + 1;
            end
        end
        $display("  Max write completed");
    endtask

    // Тест 3: Чтение 255 байт (максимум)
    task test_read_max;
        send_read_packet(32'h0000, 8'hFF);
    endtask
    
    // Тест 4: Чтение одного байта
    task test_read_one_byte;
        // Подготовка данных в памяти
        memory[32'h0040 >> 2] = 32'h000000BB;
        
        send_read_packet(32'h0040, 8'h01);
    endtask
    
    // Тест 5: Чтение четырех байт
    task test_read_four_bytes;
        // Подготовка данных в памяти
        memory[32'h0044 >> 2] = 32'hDDCCBBAA;
        
        send_read_packet(32'h0044, 8'h04);
    endtask
    
    // Тест 6: Чтение после записи
    task test_write_then_read;
        reg [7:0] write_data[];
        write_data = new[4];
        write_data[0] = 8'h11;
        write_data[1] = 8'h22;
        write_data[2] = 8'h33;
        write_data[3] = 8'h44;
        
        // Сначала запись
        send_write_packet(32'h0067, 8'h04, write_data);
        
        // Потом чтение
        send_read_packet(32'h0067, 8'h04);
    endtask
    
    // Тест 7: Пустой пакет (только адрес)
    task test_empty_packet;
        reg [7:0] no_data[];
        no_data = new[0];
        
        test_count = test_count + 1;
        $display("\n[TEST %0d] Empty packet (address only)", test_count);
        
        // Для записи
        copy_write = 1'b1;
        inp_packet_len = 8'h04;  // только адрес
        
        set_inp_byte(8'h00, 8'h00);
        set_inp_byte(8'h01, 8'h00);
        set_inp_byte(8'h02, 8'h10);
        set_inp_byte(8'h03, 8'h00);

        @(posedge clk);
        #1;
        copy_req = 1'b1;
        @(posedge clk);
        #1;
        copy_req = 1'b0;
        
        
        @(posedge clk);
        while (!copy_ready) @(posedge clk);
        #1;
        
        $display("  Empty packet OK");
    endtask
    
    // Тест 8: Последовательные операции
    task test_sequence;
        reg [7:0] data1[];
        reg [7:0] data2[];
        data1 = new[2];
        data2 = new[3];
        
        data1[0] = 8'hAA;
        data1[1] = 8'hBB;
        data2[0] = 8'hCC;
        data2[1] = 8'hDD;
        data2[2] = 8'hEE;
        
        $display("\n[TEST] Sequence of operations");
        
        // Запись 1
        send_write_packet(32'h0070, 8'h02, data1);
        // Запись 2
        send_write_packet(32'h0074, 8'h03, data2);
        // Чтение 1
        send_read_packet(32'h0070, 8'h02);
        // Чтение 2
        send_read_packet(32'h0074, 8'h03);
    endtask
    
    // Мониторинг таймаута
    initial begin
        #TIMEOUT;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
    // Главный тестовый процесс
    initial begin
        // Инициализация
        $display("\n=== DebugMemoryCopier Testbench ===");
        $dumpfile("DebugMemoryCopier_tb.vcd");
        $dumpvars(0, DebugMemoryCopier_tb);
        
        // Начальные значения
        arstn = 1'b0;
        copy_req = 1'b0;
        copy_write = 1'b0;
        inp_packet_len = 8'h00;
        inp_packet_data = 8'h00;
        data_ack = 1'b0;
        data_data = 32'h00000000;
        
        init_memory();
        error_count = 0;
        test_count = 0;
        
        // Сброс
        repeat (5) @(posedge clk);
        #1;
        arstn = 1'b1;
        repeat (5) @(posedge clk);
        #1;
        
        $display("\nReset complete, starting tests...\n");
        
        // Запуск тестов
        test_write_one_byte();
        #100;
        
        test_write_four_bytes();
        #100;
        
        test_write_max();
        #1000;

        test_read_max();
        #1000;
        
        test_read_one_byte();
        #100;
        
        test_read_four_bytes();
        #100;
        
        test_write_then_read();
        #200;
        
        test_empty_packet();
        #100;
        
        test_sequence();
        #500;
        
        // Итоги
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