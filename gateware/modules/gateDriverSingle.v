// Drive a single output pin
// Nets with names beginning with sys are in the system clock domain.
// All others are in the kicker gate driver clock domain.

module gateDriverSingle #(
    parameter ADDRESS            = -1,
    parameter SERDES_WIDTH       = 10
    ) (
    input wire sysClk,
    input wire sysCsrStrobe,
    input wire [31:0] sysGPIO_OUT,

    input wire kgdClk,
    input wire kgdStrobe,

    output reg busy = 0,
    output wire [4:0] odelayValue,
    output wire [SERDES_WIDTH-1:0] pattern);

localparam ADDRESS_WIDTH       = 8;
localparam DELAY_COUNT_WIDTH   = 4;
localparam WIDTH_COUNT_WIDTH   = 4;
localparam PATTERN_SHIFT_WIDTH = $clog2(SERDES_WIDTH);
localparam ODELAY_WIDTH        = 5;
localparam PULSE_INFO_WIDTH = 1 + ODELAY_WIDTH +
                                  PATTERN_SHIFT_WIDTH + WIDTH_COUNT_WIDTH +
                                  PATTERN_SHIFT_WIDTH + DELAY_COUNT_WIDTH;

////////////////////// System clock domain //////////////////////////////////
reg [PULSE_INFO_WIDTH-1:0] sysPulseInfo;
reg                        sysInfoToggle = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe && (sysGPIO_OUT[24+:ADDRESS_WIDTH] == ADDRESS)) begin
        sysPulseInfo <= sysGPIO_OUT[PULSE_INFO_WIDTH-1:0];
        sysInfoToggle <= !sysInfoToggle;
    end
end

///////////////// Kicker Gate Driver Clock Domain /////////////////////////////
(* ASYNC_REG="TRUE" *) reg infoToggle_m = 0;
reg infoToggle = 0, infoMatch = 0;
reg [PULSE_INFO_WIDTH-1:0] pulseInfo;

// Split stored value into pulse parameters
wire [DELAY_COUNT_WIDTH-1:0] delayCount =
                            pulseInfo[0+:DELAY_COUNT_WIDTH];
wire [PATTERN_SHIFT_WIDTH-1:0] leadingZeroCount =
                            pulseInfo[DELAY_COUNT_WIDTH+:PATTERN_SHIFT_WIDTH];
wire [WIDTH_COUNT_WIDTH-1:0] widthCount =
                            pulseInfo[(DELAY_COUNT_WIDTH +
                                       PATTERN_SHIFT_WIDTH)+:WIDTH_COUNT_WIDTH];
wire [PATTERN_SHIFT_WIDTH-1:0] trailingZeroCount =
                            pulseInfo[(DELAY_COUNT_WIDTH +
                                       PATTERN_SHIFT_WIDTH +
                                       WIDTH_COUNT_WIDTH)+:PATTERN_SHIFT_WIDTH];
wire [ODELAY_WIDTH-1:0] odelayValue =
                            pulseInfo[(DELAY_COUNT_WIDTH +
                                       PATTERN_SHIFT_WIDTH +
                                       WIDTH_COUNT_WIDTH +
                                       PATTERN_SHIFT_WIDTH)+:ODELAY_WIDTH];
wire enable = pulseInfo[(ODELAY_WIDTH +
                         DELAY_COUNT_WIDTH +
                         PATTERN_SHIFT_WIDTH +
                         WIDTH_COUNT_WIDTH  +
                         PATTERN_SHIFT_WIDTH)];

// Initial and final SERDES patterns
// SERDES sends LSB first
reg [SERDES_WIDTH-1:0] firstPattern = {SERDES_WIDTH{1'b1}};
reg [SERDES_WIDTH-1:0] lastPattern = {SERDES_WIDTH{1'b1}};

// Pattern to OSERDES
reg [SERDES_WIDTH-1:0] pattern = {SERDES_WIDTH{1'b1}};

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
    if (infoToggle != infoMatch) begin
        infoMatch <= infoToggle;
        pulseInfo <= sysPulseInfo;
    end
    case (state)
    S_IDLE: begin
        busy <= 1'b0;
        pattern <= {SERDES_WIDTH{1'b1}};
        delayCounter <= {1'b0, delayCount} - 1;
        widthCounter <= {1'b0, widthCount} - 1;
        firstPattern <= ~({SERDES_WIDTH{1'b1}} << leadingZeroCount);
        lastPattern <= ~({SERDES_WIDTH{1'b1}} >> trailingZeroCount);
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
        pattern <= {SERDES_WIDTH{1'b0}};
        widthCounter <= widthCounter - 1;
        if (widthCounterDone) begin
            state <= S_SEND_LAST;
        end
    end
    S_SEND_LAST: begin
        pattern <= lastPattern;
        state <= S_IDLE;
    end
    default: state <= S_IDLE;
    endcase
end

endmodule
