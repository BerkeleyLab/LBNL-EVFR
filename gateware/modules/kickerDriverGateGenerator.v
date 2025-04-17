// Generate kicker gate driver bit and byte clocks from
// delayed version of event receiver clock.

module kickerDriverGateGenerator #(
    parameter DEBUG = "false"
    ) (
    input         sysClk,
    input         sysCsrStrobe,
    input  [31:0] sysGPIO_OUT,
    output [31:0] sysStatus,

    input                      evrClk,
    (*mark_debug=DEBUG*) input evrGateStrobe,

    input            kgdClk,
    output reg       kgdGateStrobe = 0);

localparam CLOCK_DELAY_WIDTH = 12;

///////////////////////////////////////////////////////////////////////////////
// System clock domain
reg [CLOCK_DELAY_WIDTH-1:0] sysDelay = 0;
reg sysNewDelayToggle = 0;
always @(posedge sysClk) begin
    if (sysCsrStrobe && (sysGPIO_OUT[31-:8] == 8'hFF)) begin
        if (sysGPIO_OUT[15]) begin
            sysDelay <= sysGPIO_OUT[0+:CLOCK_DELAY_WIDTH];
            sysNewDelayToggle <= !sysNewDelayToggle;
        end
    end
end

assign sysStatus = { {16 {1'b0}},
                     {16 - CLOCK_DELAY_WIDTH{1'b0}},
                     sysDelay };

///////////////////////////////////////////////////////////////////////////////
// Fixed delay on gate strobe (~2.5 ns)
wire kgdGateStrobe_w;
(* IODELAY_GROUP = "DLYGRP_1" *)
IDELAYE2 #(.IDELAY_TYPE("FIXED"),
           .IDELAY_VALUE(31),
           .DELAY_SRC("DATAIN"),
           .SIGNAL_PATTERN("DATA"))
  evrGateStrobeDelay (
    .C(1'b0),
    .REGRST(1'b0),
    .LD(1'b0),
    .CE(1'b0),
    .INC(1'b0),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'b0),
    .IDATAIN(),
    .DATAIN(evrGateStrobe),
    .LDPIPEEN(1'b0),
    .CNTVALUEOUT(),
    .DATAOUT(kgdGateStrobe_w));

///////////////////////////////////////////////////////////////////////////////
// Coarse delay generation
localparam CLOCK_COUNTER_WIDTH = CLOCK_DELAY_WIDTH  + 1;
(*ASYN_REG="true"*) reg newDelayToggle_m = 0;
(*mark_debug=DEBUG*) reg newDelayToggle = 0;
(*mark_debug=DEBUG*) reg newDelayToggle_d = 0;
(*mark_debug=DEBUG*) reg [CLOCK_COUNTER_WIDTH-1:0] delayCounterReload = 0;
(*mark_debug=DEBUG*) reg [CLOCK_COUNTER_WIDTH-1:0] delayCounter = 0;
wire delayCounterActive = delayCounter[CLOCK_COUNTER_WIDTH-1];
reg delayCounterActive_d = 0;
always @(posedge kgdClk) begin
    newDelayToggle_m <= sysNewDelayToggle;
    newDelayToggle   <= newDelayToggle_m;
    newDelayToggle_d <= newDelayToggle;
    if (newDelayToggle != newDelayToggle_d) begin
        delayCounterReload <= {1'b1, {CLOCK_COUNTER_WIDTH-1{1'b0}}} +
                                                               {1'b0, sysDelay};
    end
    delayCounterActive_d <= delayCounterActive;
    kgdGateStrobe <= (!delayCounterActive && delayCounterActive_d);
    if (delayCounterActive) begin
        delayCounter <= delayCounter - 1;
    end
    else if (kgdGateStrobe_w) begin
        delayCounter <= delayCounterReload;
    end
end

endmodule
