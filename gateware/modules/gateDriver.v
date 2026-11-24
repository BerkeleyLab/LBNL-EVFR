// Drives a single output pinfrom multiple possible events
// Nets with names beginning with sys are in the system clock domain.
// All others are in the kicker gate driver clock domain.

module gateDriver #(
    parameter NUM_GATES          = 2,
    parameter DIFFERENTIAL_OUPUT = "true",
    parameter ADDRESS            = -1,
    parameter SERDES_POLARITY    = "ACTIVE_LOW"
    ) (
    input wire                  sysClk,
    input wire           [31:0] sysGPIO_OUT,

    input wire  [NUM_GATES-1:0] sysCsrStrobe,
    input wire  [NUM_GATES-1:0] sysCsr2Strobe,

    input wire                  kgdClk,
    input wire                  kgdReset,
    input wire                  kgdBitClk,
    input wire  [NUM_GATES-1:0] kgdStrobe,
    output wire [NUM_GATES-1:0] kgdBusy,

    output wire P,
    output wire N);

localparam ADDRESS_WIDTH = $clog2(NUM_GATES);

generate
if (DIFFERENTIAL_OUPUT != "true" && DIFFERENTIAL_OUPUT != "false") begin
    DIFFERENTIAL_OUPUT_can_only_be_true_or_false error();
end
endgenerate

localparam SERDES_WIDTH = 10;

wire busySingle [0:NUM_GATES-1];
wire [4:0] odelayValueSingle [0:NUM_GATES-1];
wire odelayLoadSingle [0:NUM_GATES-1];
wire [SERDES_WIDTH-1:0] patternSingle [0:NUM_GATES-1];

genvar i;
generate
for (i = 0; i < NUM_GATES; i = i + 1) begin
   gateDriverSingle #(
     .ADDRESS(ADDRESS),
     .SERDES_WIDTH(SERDES_WIDTH),
     .SERDES_POLARITY(SERDES_POLARITY)
    ) gateDriverSingle (
        .sysClk(sysClk),
        .sysGPIO_OUT(sysGPIO_OUT),

        .sysCsrStrobe(sysCsrStrobe[i]),
        .sysCsr2Strobe(sysCsr2Strobe[i]),

        .kgdClk(kgdClk),
        .kgdStrobe(kgdStrobe[i]),

        .busy(busySingle[i]),
        .odelayValue(odelayValueSingle[i]),
        .odelayLoad(odelayLoadSingle[i]),
        .pattern(patternSingle[i]));

    assign kgdBusy[i] = busySingle[i];
end
endgenerate


//////////////////////////////////////////////////////////////
// Priority encoder to determine which channel will be used
// to drive the SERDES
//////////////////////////////////////////////////////////////

// Priority encoder. We select the based on "busy" form the gate itself
if (NUM_GATES != 2) begin
    NUM_GATES_can_only_be_2 error();
end

wire [ADDRESS_WIDTH-1:0] priorityBitnum = busySingle[0] ? 0 :
                                          busySingle[1] ? 1 : 0;
reg [ADDRESS_WIDTH-1:0] priorityBitnumLoaded = 0;

always @(posedge kgdClk) begin
    priorityBitnumLoaded <= priorityBitnum;
end

wire [4:0] odelayValue = odelayValueSingle[priorityBitnum];

wire odelayLoad = odelayLoadSingle[priorityBitnum] ||
                  (priorityBitnum != priorityBitnumLoaded);

wire [SERDES_WIDTH-1:0] pattern = patternSingle[priorityBitnum];

//////////////////////////////////////////////////////////////
// Output SERDES stage
//////////////////////////////////////////////////////////////

generate
if (ADDRESS < 92) begin
    gateDriverSerdesIO #(
        .DIFFERENTIAL_OUPUT(DIFFERENTIAL_OUPUT),
        .DATA_WIDTH(SERDES_WIDTH),
        .WITH_ODELAY("false"))
      gateDriverSerdesIO (
        .serialClk(kgdBitClk),
        .parallelClk(kgdClk),
        .reset(kgdReset),
        .clockEnable(1'b1),

        .delayReset(1'b0),
        .delayClockEnable(1'b0),
        .delayInc(1'b0),
        .delayInValue(0),

        .dataIn(pattern),
        .dataOutP(P),
        .dataOutN(N));
end
else begin
    gateDriverSerdesIO #(
        .DIFFERENTIAL_OUPUT(DIFFERENTIAL_OUPUT),
        .DATA_WIDTH(SERDES_WIDTH),
        .WITH_ODELAY("true"))
      gateDriverSerdesIO (
        .serialClk(kgdBitClk),
        .parallelClk(kgdClk),
        .reset(kgdReset),
        .clockEnable(1'b1),

        .delayReset(odelayLoad),
        .delayClockEnable(1'b0),
        .delayInc(1'b0),
        .delayInValue(odelayValue),

        .dataIn(pattern),
        .dataOutP(P),
        .dataOutN(N));
end
endgenerate

endmodule
