module UartMemInit(
    input   logic           clk,
    input   logic           arstn,

    output  logic [31:0]    mem_addr,
    output  logic [31:0]    mem_write_data,
    output  logic           mem_we,
    input   logic [31:0]    mem_read_data,

    input   logic [7:0]     from_uart_data,
    input   logic           from_uart_valid,
    output  logic           from_uart_ready,

    output  logic [7:0]     to_uart_data,
    input   logic           to_uart_ready,
    output  logic           to_uart_valid,

    output  logic [2:0]     state_dbg
);

typedef enum logic [2:0] {
    S_CMD,
    S_ADDR,
    S_DATA,
    S_EXEC,
    S_MEMREAD,
    S_MEMWRITE
} state_t;

state_t                     state;
logic [1:0]                 data_cnt;
logic [7:0]                 cmd;

always_ff @(posedge clk or negedge arstn) begin
    if (~arstn) begin
        state <= S_CMD;
        data_cnt <= '0;
        mem_addr <= '0;
        mem_write_data <= '0;
        mem_we <= '0;
        to_uart_data <= '0;
        to_uart_valid <= '0;
        cmd <= '0;
    end
    else begin
        mem_we <= '0;
        to_uart_valid <= '0;

        case (state)
        S_CMD: begin
            if (from_uart_valid) begin
                state <= S_ADDR;
                cmd <= from_uart_data;
            end
        end
        S_ADDR: begin
            if (from_uart_valid) begin
                mem_addr <= { mem_addr[23:0], from_uart_data };

                if (data_cnt == 2'd3) begin
                    data_cnt <= '0;

                    if (cmd[0]) begin
                        state <= S_EXEC;
                    end
                    else begin
                        state <= S_DATA;
                    end
                end
                else begin
                    data_cnt <= data_cnt + 2'd1;
                end
            end
        end
        S_DATA: begin
            if (from_uart_valid) begin
                mem_write_data <= { mem_write_data[23:0], from_uart_data };

                if (data_cnt == 2'd3) begin
                    data_cnt <= '0;
                    state <= S_EXEC;
                end
                else begin
                    data_cnt <= data_cnt + 2'd1;
                end
            end
        end
        S_EXEC: begin
            if (cmd[0]) begin
                state <= S_MEMREAD;
            end
            else begin
                state <= S_MEMWRITE;
            end
        end
        S_MEMREAD: begin
            if (to_uart_ready) begin    
                to_uart_valid <= '1;

                case (data_cnt)
                2'd0: to_uart_data <= mem_read_data[31:24];
                2'd1: to_uart_data <= mem_read_data[23:16];
                2'd2: to_uart_data <= mem_read_data[15:8];
                2'd3: to_uart_data <= mem_read_data[7:0];
                endcase
                
                if (data_cnt == 2'd3) begin
                    data_cnt <= '0;
                    state <= S_CMD;
                end
                else begin
                    data_cnt <= data_cnt + 2'd1;
                end
            end
        end
        S_MEMWRITE: begin
            mem_we <= '1;
            state <= S_CMD;
        end
        endcase
    end
end

always_comb begin
    case (state)
        S_CMD, S_ADDR, S_DATA: from_uart_ready = '1;
        default:               from_uart_ready = '0;
    endcase
    state_dbg = state;
end

endmodule