module kickerDriverClockGateGenerator #(
    parameter DEBUG       = "false",
    parameter NUM_GATES   = 2
    ) (
    input                       sysClk,

    input                       sysClockCsrStrobe,
    input       [NUM_GATES-1:0] sysGateCsrStrobe,
    output               [31:0] sysClockStatus,
    output   [NUM_GATES*32-1:0] sysGateStatus,
    input                [31:0] sysGPIO_OUT,

    input                    evrClk,
    (*mark_debug=DEBUG*) input [NUM_GATES-1:0] evrGateStrobe,

    input         refClk200,
    output        sysIdelayControlReset,

    output        kgdClk,
    output        kgdReset,
    output        kgdBitClk,
    (*mark_debug=DEBUG*) output [NUM_GATES-1:0] kgdGateStrobe);

kickerDriverClockGenerator #(
    .DEBUG(DEBUG))
  kickerDriverClockGenerator (
    .sysClk(sysClk),
    .sysCsrStrobe(sysClockCsrStrobe),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysClockStatus),

    .evrClk(evrClk),

    .refClk200(refClk200),
    .sysIdelayControlReset(sysIdelayControlReset),

    .kgdClk(kgdClk),
    .kgdReset(kgdReset),
    .kgdBitClk(kgdBitClk));

genvar i;
generate
for (i = 0; i < NUM_GATES; i = i + 1) begin

kickerDriverGateGenerator #(
    .DEBUG(DEBUG))
  kickerDriverGateGenerator (
    .sysClk(sysClk),
    .sysCsrStrobe(sysGateCsrStrobe[i]),
    .sysGPIO_OUT(sysGPIO_OUT),
    .sysStatus(sysGateStatus[i*32+:32]),

    .evrClk(evrClk),
    .evrGateStrobe(evrGateStrobe[i]),

    .kgdClk(kgdClk),
    .kgdGateStrobe(kgdGateStrobe[i]));

end
endgenerate

endmodule
