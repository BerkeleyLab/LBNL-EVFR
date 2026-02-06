// Generate kicker gate bit and byte clocks from
// delayed version of event receiver clock.

module kickerDriverClockGenerator #(
    parameter DEBUG = "false"
    ) (
    input         sysClk,
    input         sysCsrStrobe,
    input  [31:0] sysGPIO_OUT,
    output [31:0] sysStatus,

    input         evrClk,

    input         refClk200,
    output reg    sysIdelayControlReset = 0,

    output        kgdClk,
    output        kgdReset,
    output        kgdBitClk);

localparam IDELAY_COUNT_WIDTH = 5;

///////////////////////////////////////////////////////////////////////////////
// System clock domain
reg sysKickerClockIdelayCE = 0, sysKickerClockIdelayINC = 0;
always @(posedge sysClk) begin
    if (sysCsrStrobe && (sysGPIO_OUT[31-:8] == 8'hFF)) begin
        sysIdelayControlReset <= sysGPIO_OUT[23];
        if (sysGPIO_OUT[16]) begin
            sysKickerClockIdelayCE <= 1;
            sysKickerClockIdelayINC <= sysGPIO_OUT[17];
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

BUFG evrClkDelayedBUFG (
    .I(evrClkDelayed),
    .O(evrClkDelayedBUF));

///////////////////////////////////////////////////////////////////////////////
// Generate bit and byte clocks from delayed reference
// See "kickerDriverGateGenerator", but the clock has
// to be advanced by -112.5o to compensate the effect
// of removing the 2.5ns delay on the gate strobe
wire mmcmLocked;
kdOutputDriverMMCM gateDriverMMCM (
    .clk_in1(evrClkDelayedBUF),
    .reset(1'b0),
    .clk_out1(kgdClk),
    .clk_out2(kgdBitClk),
    .locked(mmcmLocked));

localparam MMCM_RESET_COUNTER_WIDTH = 8+1;
(*ASYNC_REG="true"*) reg mmcmLocked_m0 = 0, mmcmLocked_r = 0;
reg [MMCM_RESET_COUNTER_WIDTH-1:0] mmcmResetCounter = {MMCM_RESET_COUNTER_WIDTH{1'b1}};

always @(posedge evrClkDelayedBUF) begin
    mmcmLocked_m0 <= mmcmLocked;
    mmcmLocked_r <= mmcmLocked_m0;
    if (!mmcmLocked_r) begin
        mmcmResetCounter <= {MMCM_RESET_COUNTER_WIDTH{1'b1}};
    end
    else if (kgdReset) begin
        mmcmResetCounter <= mmcmResetCounter - 1;
    end
end

assign kgdReset = mmcmResetCounter[MMCM_RESET_COUNTER_WIDTH-1];

endmodule
