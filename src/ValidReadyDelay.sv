module ValidReadyDelay #(
    parameter NUM_TICKS = 10
) (
    input   logic           clk,
    input   logic           arstn,
    
    input   logic           master_valid,
    output  logic           master_ready,

    output  logic           slave_valid,
    input   logic           slave_ready
);

generate
    if (NUM_TICKS == 0) begin : gen_no_delay
        assign slave_valid = master_valid;
        assign master_ready = slave_ready;
    end
    else begin : gen_delay
        localparam COUNTER_WIDTH = $clog2(NUM_TICKS + 1);
        logic [COUNTER_WIDTH-1:0]               counter;
        logic                                   pass_en;

        assign pass_en = ~|counter;

        always_ff @(posedge clk or negedge arstn) begin
            if (~arstn) begin
                counter <= '0;
            end
            else begin
                if (pass_en) begin
                    if (master_ready & master_valid) begin
                        counter <= NUM_TICKS[COUNTER_WIDTH-1:0];
                    end
                end
                else begin
                    counter <= counter - 1'b1;
                end
            end
        end

        always_comb begin
            if (pass_en) begin
                slave_valid = master_valid;
                master_ready = slave_ready;
            end
            else begin
                slave_valid = '0;
                master_ready = '0;
            end
        end
    end
endgenerate

endmodule