// Generate kicker gate driver bit and byte clocks from
// delayed version of event receiver clock.

module kickerDriverClockGenerator #(
    parameter DEBUG = "false"
    ) (
    input         sysClk,
    input         sysCsrStrobe,
    input  [31:0] sysGPIO_OUT,
    output [31:0] sysStatus,

    input                      evrClk,
    (*mark_debug=DEBUG*) input evrGateStrobe,

    input            refClk200,
    output reg       sysIdelayControlReset = 0,

    output           kgdClk,
    output           kgdBitClk,
    output reg       kgdGateStrobe = 0);

localparam IDELAY_COUNT_WIDTH = 5;
localparam CLOCK_DELAY_WIDTH = 12;

///////////////////////////////////////////////////////////////////////////////
// System clock domain
reg [CLOCK_DELAY_WIDTH-1:0] sysDelay = 0;
reg sysNewDelayToggle = 0;
reg sysKickerClockIdelayCE = 0, sysKickerClockIdelayINC = 0;
always @(posedge sysClk) begin
    if (sysCsrStrobe && (sysGPIO_OUT[31-:8] == 8'hFF)) begin
        sysIdelayControlReset <= sysGPIO_OUT[23];
        if (sysGPIO_OUT[16]) begin
            sysKickerClockIdelayCE <= 1;
            sysKickerClockIdelayINC <= sysGPIO_OUT[17];
        end
        if (sysGPIO_OUT[15]) begin
            sysDelay <= sysGPIO_OUT[0+:CLOCK_DELAY_WIDTH];
            sysNewDelayToggle <= !sysNewDelayToggle;
        end
    end
    else begin
        sysKickerClockIdelayCE <= 0;
    end
end

wire [IDELAY_COUNT_WIDTH-1:0] sysKickerClockIdelayCount;
assign sysStatus = { 1'b0, sysIdelayControlReset,
                     {32 -2 - IDELAY_COUNT_WIDTH{1'b0}},
                     sysKickerClockIdelayCount };

///////////////////////////////////////////////////////////////////////////////
// Fine delay generation

// Delay control block shared by IDELAY blocks
(* IODELAY_GROUP = "KD_DELAYS" *)
IDELAYCTRL idelayControl (
    .REFCLK(refClk200),
    .RST(sysIdelayControlReset),
    .RDY());

// Programmable delay on clock (0 to ~800 ps)
wire evrClkDelayed, evrClkDelayedBUF;
(* IODELAY_GROUP = "DLYGRP_1" *)
IDELAYE2 #(.IDELAY_TYPE("VARIABLE"),
           .DELAY_SRC("DATAIN"),
           .SIGNAL_PATTERN("CLOCK"))
  evrClkDelay (
    .C(sysClk),
    .REGRST(1'b0),
    .LD(1'b0),
    .CE(sysKickerClockIdelayCE),
    .INC(sysKickerClockIdelayINC),
    .CINVCTRL(1'b0),
    .CNTVALUEIN(5'b0),
    .IDATAIN(),
    .DATAIN(evrClk),
    .LDPIPEEN(1'b0),
    .CNTVALUEOUT(sysKickerClockIdelayCount),
    .DATAOUT(evrClkDelayed));
BUFG evrClkDelayedBUFG (.I(evrClkDelayed), .O(evrClkDelayedBUF));

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
// Generate bit and byte clocks from delayed reference
kdOutputDriverMMCM gateDriverMMCM (
    .clk_in1(evrClkDelayedBUF),
    .reset(1'b0),
    .clk_out1(kgdClk),
    .clk_out2(kgdBitClk));

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
