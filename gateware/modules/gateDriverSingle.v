// Drive a single output pin
// Nets with names beginning with sys are in the system clock domain.
// All others are in the kicker gate driver clock domain.

module gateDriverSingle #(
    parameter ADDRESS            = -1,
    parameter SERDES_WIDTH       = 10,
    parameter SERDES_POLARITY    = "ACTIVE_LOW",
    // DON'T CHANGE THIS
    parameter ODELAY_WIDTH       = 5
    ) (
    input wire sysClk,
    input wire [31:0] sysGPIO_OUT,

    input wire sysCsrStrobe,
    input wire sysCsr2Strobe,

    input wire kgdClk,
    input wire kgdStrobe,

    output reg busy = 0,
    output wire [4:0] odelayValue,
    output reg odelayLoad = 0,
    output reg  [SERDES_WIDTH-1:0] pattern = (SERDES_POLARITY == "ACTIVE_LOW") ?
                                             {SERDES_WIDTH{1'b1}} : {SERDES_WIDTH{1'b0}}
);

generate
if (SERDES_POLARITY != "ACTIVE_LOW" && SERDES_POLARITY != "ACTIVE_HIGH") begin
    SERDES_POLARITY_can_only_be_active_low_or_active_high error();
end
endgenerate

localparam integer ADDRESS_WIDTH       = 8;
localparam integer DELAY_COUNT_WIDTH   = 12;

localparam integer PULSE_INFO_WIDTH = 1 + ODELAY_WIDTH +
                                          DELAY_COUNT_WIDTH;

localparam integer WIDTH_COUNT_WIDTH   = 12;
localparam integer PATTERN_SHIFT_WIDTH = $clog2(SERDES_WIDTH);

localparam integer PULSE_INFO_2_WIDTH = PATTERN_SHIFT_WIDTH + WIDTH_COUNT_WIDTH +
                                PATTERN_SHIFT_WIDTH;

////////////////////// System clock domain //////////////////////////////////
reg [PULSE_INFO_WIDTH-1:0] sysPulseInfo;
reg                        sysInfoToggle = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe && (sysGPIO_OUT[24+:ADDRESS_WIDTH] == ADDRESS)) begin
        sysPulseInfo <= sysGPIO_OUT[PULSE_INFO_WIDTH-1:0];
        sysInfoToggle <= !sysInfoToggle;
    end
end

reg [PULSE_INFO_2_WIDTH-1:0] sysPulseInfo2;
reg                        sysInfo2Toggle = 0;

always @(posedge sysClk) begin
    if (sysCsr2Strobe && (sysGPIO_OUT[24+:ADDRESS_WIDTH] == ADDRESS)) begin
        sysPulseInfo2 <= sysGPIO_OUT[PULSE_INFO_2_WIDTH-1:0];
        sysInfo2Toggle <= !sysInfo2Toggle;
    end
end

///////////////// Kicker Gate Driver Clock Domain /////////////////////////////
(* ASYNC_REG="TRUE" *) reg infoToggle_m = 0;
reg infoToggle = 0, infoMatch = 0;
reg [PULSE_INFO_WIDTH-1:0] pulseInfo = 0;

(* ASYNC_REG="TRUE" *) reg info2Toggle_m = 0;
reg info2Toggle = 0, info2Match = 0;
reg [PULSE_INFO_2_WIDTH-1:0] pulseInfo2 = 0;

// Split stored value into pulse parameters
wire [DELAY_COUNT_WIDTH-1:0] delayCount =
                            pulseInfo[0+:DELAY_COUNT_WIDTH];
assign odelayValue = pulseInfo[DELAY_COUNT_WIDTH+:ODELAY_WIDTH];
wire enable = pulseInfo[ODELAY_WIDTH +
                         DELAY_COUNT_WIDTH];

wire [PATTERN_SHIFT_WIDTH-1:0] leadingZeroCount =
                            pulseInfo2[0+:PATTERN_SHIFT_WIDTH];
wire [WIDTH_COUNT_WIDTH-1:0] widthCount =
                            pulseInfo2[PATTERN_SHIFT_WIDTH+:WIDTH_COUNT_WIDTH];
wire [PATTERN_SHIFT_WIDTH-1:0] trailingZeroCount =
                            pulseInfo2[(PATTERN_SHIFT_WIDTH + WIDTH_COUNT_WIDTH)+:
                                PATTERN_SHIFT_WIDTH];

localparam [SERDES_WIDTH-1:0] SERDES_IDLE_PATTERN = (SERDES_POLARITY == "ACTIVE_LOW") ?
                                            {SERDES_WIDTH{1'b1}} : {SERDES_WIDTH{1'b0}};
localparam [SERDES_WIDTH-1:0] SERDES_ACTIVE_PATTERN = ~SERDES_IDLE_PATTERN;

wire [SERDES_WIDTH-1:0] firstPatternComb = (SERDES_POLARITY == "ACTIVE_LOW") ?
    ~({SERDES_WIDTH{1'b1}} << leadingZeroCount) : ({SERDES_WIDTH{1'b1}} << leadingZeroCount);
wire [SERDES_WIDTH-1:0] lastPatternComb = (SERDES_POLARITY == "ACTIVE_LOW") ?
    ~({SERDES_WIDTH{1'b1}} >> trailingZeroCount) : ({SERDES_WIDTH{1'b1}} >> trailingZeroCount);

// Initial and final SERDES patterns
// SERDES sends LSB first
reg [SERDES_WIDTH-1:0] firstPattern = SERDES_IDLE_PATTERN;
reg [SERDES_WIDTH-1:0] lastPattern = SERDES_IDLE_PATTERN;

// Pulse counters
reg [DELAY_COUNT_WIDTH:0] delayCounter = 0;
wire delayCounterDone = delayCounter[DELAY_COUNT_WIDTH];
reg [WIDTH_COUNT_WIDTH:0] widthCounter = 0;
wire widthCounterDone = widthCounter[WIDTH_COUNT_WIDTH];

// Pulse generator state machine
localparam S_IDLE       = 3'd0,
           S_DELAY      = 3'd1,
           S_SEND_FIRST = 3'd2,
           S_SEND_FILL  = 3'd3,
           S_SEND_LAST  = 3'd4;
reg [2:0] state = S_IDLE;

// Pulse generator
always @(posedge kgdClk) begin
    infoToggle_m <= sysInfoToggle;
    infoToggle   <= infoToggle_m;
    odelayLoad <= 1'b0;
    if (infoToggle != infoMatch) begin
        infoMatch <= infoToggle;
        pulseInfo <= sysPulseInfo;
        odelayLoad <= 1'b1;
    end

    info2Toggle_m <= sysInfo2Toggle;
    info2Toggle   <= info2Toggle_m;
    if (info2Toggle != info2Match) begin
        info2Match <= info2Toggle;
        pulseInfo2 <= sysPulseInfo2;
    end

    case (state)
    S_IDLE: begin
        busy <= 1'b0;
        pattern <= SERDES_IDLE_PATTERN;
        delayCounter <= {1'b0, delayCount} - 1;
        widthCounter <= {1'b0, widthCount} - 1;
        firstPattern <= firstPatternComb;
        lastPattern <= lastPatternComb;
        if (kgdStrobe && enable) begin
            busy <= 1'b1;
            state <= S_DELAY;
        end
    end

    S_DELAY: begin
        delayCounter <= delayCounter - 1;
        if (delayCounterDone) begin
            state <= S_SEND_FIRST;
        end
    end

    S_SEND_FIRST: begin
        pattern <= firstPattern;
        state <= S_SEND_FILL;
    end

    S_SEND_FILL: begin
        pattern <= SERDES_ACTIVE_PATTERN;
        widthCounter <= widthCounter - 1;
        if (widthCounterDone) begin
            state <= S_SEND_LAST;
        end
    end

    S_SEND_LAST: begin
        pattern <= lastPattern;
        state <= S_IDLE;
    end

    default: begin
        state <= S_IDLE;
    end

    endcase
end

endmodule
