// The Reset/RecoveryMode switch is debounced in software.

module frontPanelSwitches #(
    parameter CLK_RATE    = 100000000,
    parameter DEBOUNCE_MS = 10,
    parameter DEBUG       = "false"
    ) (
    input  wire        clk,
    input  wire [31:0] GPIO_OUT,
    output wire [31:0] status,

    (*MARK_DEBUG=DEBUG*) input wire displaySwitch_n,
    (*MARK_DEBUG=DEBUG*) input wire resetSwitch_n);

(*ASYNC_REG="true"*) reg resetRecoveryModeSwitch_m;
(*MARK_DEBUG=DEBUG*) reg resetRecoveryModeSwitch;
(*MARK_DEBUG=DEBUG*) wire displaySwitch;

always @(posedge clk) begin
    resetRecoveryModeSwitch_m <= !resetSwitch_n;
    resetRecoveryModeSwitch   <= resetRecoveryModeSwitch_m;
end

assign status = { resetRecoveryModeSwitch, displaySwitch, 30'b0 };

debounceSwitch #(.CLK_RATE(CLK_RATE),
                .DEBOUNCE_MS(DEBOUNCE_MS))
  debounceDisplay (
    .clk(clk),
    .switch_a(!displaySwitch_n),
    .switch_o(displaySwitch));

endmodule

module debounceSwitch #(
    parameter CLK_RATE    = 100000000,
    parameter DEBOUNCE_MS = 10
    ) (
    input  wire clk,
    input  wire switch_a,
    output reg  switch_o = 0);

localparam DEBOUNCE_COUNTER_RELOAD = (((CLK_RATE+999)/1000)*DEBOUNCE_MS) - 2;
localparam DEBOUNCE_COUNTER_WIDTH = $clog2(DEBOUNCE_COUNTER_RELOAD+1)+1;
reg [DEBOUNCE_COUNTER_WIDTH-1:0] debounceCounter = DEBOUNCE_COUNTER_RELOAD;
wire debounceCounterDone = debounceCounter[DEBOUNCE_COUNTER_WIDTH-1];

(*ASYNC_REG="true"*) reg switch_m = 0;
reg switch_d0 = 0, switch_d1 = 0;

always @(posedge clk) begin
    switch_m  <= switch_a;
    switch_d0 <= switch_m;
    switch_d1 <= switch_d0;
    if (switch_d0 != switch_d1) begin
        debounceCounter <= DEBOUNCE_COUNTER_RELOAD;
    end
    else if (!debounceCounterDone) begin
        debounceCounter <= debounceCounter - 1;
    end
    else begin
        switch_o <= switch_d0;
    end
end
endmodule
