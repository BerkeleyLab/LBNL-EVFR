// Drive a single output pin
// Nets with names beginning with sys are in the system clock domain.  All
// others are in the EVR clock domain (SERDES parallel clock).

module outputDriver #(
    parameter SERDES_WIDTH          = 4,
    parameter COARSE_DELAY_WIDTH    = 22,
    parameter COARSE_WIDTH_WIDTH    = 20,
    parameter PATTERN_ADDRESS_WIDTH = 13,
    parameter DEBUG                 = "false"
    ) (
    input         sysClk,
    input         sysCsrStrobe,
    input  [31:0] sysGPIO_OUT,

    input                                              evrClk,
    input                                              evrHBstrobe,
    (*mark_debug=DEBUG*) input  wire                   triggerStrobe,
    (*mark_debug=DEBUG*) output reg [SERDES_WIDTH-1:0] serdesPattern = 0);

localparam DELAY_INFO_WIDTH = COARSE_DELAY_WIDTH + SERDES_WIDTH;
localparam WIDTH_INFO_WIDTH = COARSE_WIDTH_WIDTH + SERDES_WIDTH;

// Data destinatin
localparam OP_SET_MODE    = 2'd0,
           OP_SET_DELAY   = 2'd1,
           OP_SET_WIDTH   = 2'd2,
           OP_SET_PATTERN = 2'd3;

// Operating modes
localparam M_DISABLED        = 2'd0,
           M_PULSE           = 2'd1,
           M_PATTERN_SINGLE  = 2'd2,
           M_PATTERN_LOOP    = 2'd3;

// Clock domain crossing
reg sysInfoToggle = 0;
(* ASYNC_REG="TRUE" *) reg infoToggle_m = 0;
reg infoToggle = 0, infoMatch = 0;
(* ASYNC_REG="TRUE" *) reg sysInfoMatch_m = 0;
reg sysInfoMatch = 0;

reg [SERDES_WIDTH-1:0] dpram [0:(1<<PATTERN_ADDRESS_WIDTH)-1], dpramQ;

////////////////////// System clock domain //////////////////////////////////
reg [DELAY_INFO_WIDTH-1:0] sysDelayInfo = 0;
reg [WIDTH_INFO_WIDTH-1:0] sysWidthInfo = 0;
reg                  [1:0] sysMode = M_PULSE;

wire [SERDES_WIDTH-1:0] sysWritePattern = sysGPIO_OUT[0+:SERDES_WIDTH];
wire [PATTERN_ADDRESS_WIDTH-1:0] sysWriteAddress =
                                         sysGPIO_OUT[10+:PATTERN_ADDRESS_WIDTH];
reg [PATTERN_ADDRESS_WIDTH-1:0] sysLastWriteAddress = 0;

always @(posedge sysClk) begin
    if (sysCsrStrobe) begin
        case (sysGPIO_OUT[31:30])
        OP_SET_MODE: begin
            sysMode <= sysGPIO_OUT[1:0];
            sysInfoToggle <= !sysInfoToggle;
        end
        OP_SET_DELAY: begin
            sysDelayInfo <= sysGPIO_OUT[DELAY_INFO_WIDTH-1:0];
        end
        OP_SET_WIDTH: begin
            sysWidthInfo <= sysGPIO_OUT[WIDTH_INFO_WIDTH-1:0];
        end
        OP_SET_PATTERN: begin
            dpram[sysWriteAddress] <= sysWritePattern;
            sysLastWriteAddress <= sysWriteAddress;
        end
        default: ;
        endcase
    end
    sysInfoMatch_m <= infoMatch;
    sysInfoMatch   <= sysInfoMatch_m;
end

// Split stored write data into pulse parameters
// Initial and final SERDES patterns -- SERDES sends LSB first
wire [SERDES_WIDTH-1:0] sysFirstPattern = sysDelayInfo[0+:SERDES_WIDTH];
wire [COARSE_DELAY_WIDTH-1:0] sysCoarseDelay = sysDelayInfo[SERDES_WIDTH+:
                                                            COARSE_DELAY_WIDTH];
wire [SERDES_WIDTH-1:0] sysLastPattern = sysWidthInfo[0+:SERDES_WIDTH];
wire [COARSE_WIDTH_WIDTH-1:0] sysCoarseWidth = sysWidthInfo[SERDES_WIDTH+:
                                                            COARSE_WIDTH_WIDTH];

////////////////////// EVR clock domain //////////////////////////////////
localparam DELAY_COUNT_WIDTH = COARSE_DELAY_WIDTH + 1;
reg  [COARSE_DELAY_WIDTH-1:0] coarseDelay;
(*mark_debug=DEBUG*) reg  [DELAY_COUNT_WIDTH-1:0] coarseDelayCount;
wire coarseDelayDone = coarseDelayCount[DELAY_COUNT_WIDTH - 1];

localparam WIDTH_COUNT_WIDTH = COARSE_WIDTH_WIDTH + 1;
reg [COARSE_WIDTH_WIDTH-1:0] coarseWidth;
(*mark_debug=DEBUG*) reg [WIDTH_COUNT_WIDTH-1:0] coarseWidthCount;
wire coarseWidthDone = coarseWidthCount[WIDTH_COUNT_WIDTH - 1];

(*mark_debug=DEBUG*) reg [SERDES_WIDTH-1:0] lastPattern, firstPattern;

reg [PATTERN_ADDRESS_WIDTH-1:0] lastWriteAddress = 0;
(*mark_debug=DEBUG*) reg [PATTERN_ADDRESS_WIDTH-1:0] readAddress = 0;
(*mark_debug=DEBUG*) reg [PATTERN_ADDRESS_WIDTH:0] patternCount = 0;
wire patternDone = patternCount[PATTERN_ADDRESS_WIDTH];

localparam S_IDLE             = 3'd0,
           S_COARSE_DELAY     = 3'd1,
           S_SEND_PULSE       = 3'd2,
           S_DELAY_PATTERN    = 3'd3,
           S_SEND_PATTERN     = 3'd4;
(*mark_debug=DEBUG*) reg [2:0] state = S_IDLE;
reg [1:0] mode = M_PULSE;

always @(posedge evrClk) begin
    dpramQ <= dpram[readAddress];

    infoToggle_m <= sysInfoToggle;
    infoToggle   <= infoToggle_m;

    case (state)
    S_IDLE: begin
        serdesPattern <= {SERDES_WIDTH{1'b0}};
        coarseWidthCount <= {1'b0, coarseWidth} - 1;
        coarseDelayCount <= {1'b0, coarseDelay} - 1;
        patternCount <= {1'b0, lastWriteAddress} - 1;
        readAddress <= 0;
        if (infoToggle != infoMatch) begin
            mode <= sysMode;
            firstPattern <= sysFirstPattern;
            lastPattern <= sysLastPattern;
            coarseDelay <= sysCoarseDelay;
            coarseWidth <= sysCoarseWidth;
            lastWriteAddress <= sysLastWriteAddress;
            infoMatch <= infoToggle;
        end
        if (triggerStrobe) begin
            case (mode)
            M_PULSE: begin
                state <= S_COARSE_DELAY;
            end
            M_PATTERN_SINGLE, M_PATTERN_LOOP: begin
                state <= S_DELAY_PATTERN;
            end
            default: ;
            endcase
        end
    end
    S_COARSE_DELAY: begin
        coarseDelayCount <= coarseDelayCount - 1;
        if (coarseDelayDone) begin
            serdesPattern <= firstPattern;
            state <= S_SEND_PULSE;
        end
    end
    S_SEND_PULSE: begin
        coarseWidthCount <= coarseWidthCount - 1;
        if (coarseWidthDone) begin
            serdesPattern <= lastPattern;
            state <= S_IDLE;
        end
        else begin
            serdesPattern <= {SERDES_WIDTH{1'b1}};
        end
    end
    S_DELAY_PATTERN: begin
        coarseDelayCount <= coarseDelayCount - 1;
        if (coarseDelayDone) begin
            readAddress <= 1;
            state <= S_SEND_PATTERN;
        end
    end
    S_SEND_PATTERN: begin
        serdesPattern <= dpramQ;
        readAddress <= readAddress + 1;
        patternCount <= patternCount - 1;
        case (mode) // exit condition
        M_PATTERN_SINGLE: begin
            if (patternDone) begin
                state <= S_IDLE;
            end
        end
        M_PATTERN_LOOP: begin
            if (evrHBstrobe) begin
                state <= S_IDLE;
            end
            if (patternDone) begin
                state <= S_DELAY_PATTERN;
                coarseDelayCount <= {1'b0, coarseDelay} - 1;
                patternCount <= {1'b0, lastWriteAddress} - 1;
                readAddress <= 0;
            end
        end
        default: state <= S_IDLE;
        endcase
    end
    default: state <= S_IDLE;
    endcase
end

endmodule
