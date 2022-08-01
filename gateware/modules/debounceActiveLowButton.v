// Debounce an active-low button

module debounceActiveLowButton #(
    parameter CLK_RATE            = -1,
    parameter MINIMUM_INACTIVE_MS = 20
    ) (
    input  clk,
    input  inputActiveLow_a,
    output debouncedActiveHigh);

localparam COUNTER_RELOAD = -(((CLK_RATE / 1000) * MINIMUM_INACTIVE_MS) - 1);
localparam COUNTER_WIDTH = $clog2((-COUNTER_RELOAD)+1) + 1;
reg [COUNTER_WIDTH-1:0] counter = 0;
assign debouncedActiveHigh = counter[COUNTER_WIDTH-1];

(*ASYNC_REG="true"*) reg inputActiveLow_m = 1;
reg inputActiveLow = 1;

always @(posedge clk) begin
    inputActiveLow_m <= inputActiveLow_a;
    inputActiveLow   <= inputActiveLow_m;
    if (inputActiveLow == 0) begin
        counter <= COUNTER_RELOAD;
    end
    else if (debouncedActiveHigh) begin
        counter <= counter + 1;
    end
end
endmodule
