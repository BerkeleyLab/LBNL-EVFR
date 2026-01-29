// Drives a single output pinfrom multiple possible events
// Nets with names beginning with sys are in the system clock domain.
// All others are in the kicker gate driver clock domain.

module gateDriver #(
    parameter NUM_GATES          = 2,
    parameter DIFFERENTIAL_OUPUT = "true",
    parameter ADDRESS            = -1
    ) (
    input wire                  sysClk,
    input wire  [NUM_GATES-1:0] sysCsrStrobe,
    input wire           [31:0] sysGPIO_OUT,

    input wire                 kgdClk,
    input wire                 kgdBitClk,
    input wire [NUM_GATES-1:0] kgdStrobe,

    output wire P,
    output wire N);

generate
if (DIFFERENTIAL_OUPUT != "true" && DIFFERENTIAL_OUPUT != "false") begin
    DIFFERENTIAL_OUPUT_can_only_be_true_or_false error();
end
endgenerate

localparam SERDES_WIDTH = 10;

wire busy [0:NUM_GATES-1];
wire [4:0] odelayValue [0:NUM_GATES-1];
wire [SERDES_WIDTH-1:0] pattern [0:NUM_GATES-1];

genvar i;
generate
for (i = 0; i < NUM_GATES; i = i + 1) begin
   gateDriverSingle #(
     .ADDRESS(ADDRESS),
     .SERDES_WIDTH(SERDES_WIDTH)
    ) gateDriverSingle (
        .sysClk(sysClk),
        .sysCsrStrobe(sysCsrStrobe[i]),
        .sysGPIO_OUT(sysGPIO_OUT),

        .kgdClk(kgdClk),
        .kgdStrobe(kgdStrobe[i]),

        .busy(busy[i])
        .odelayValue(odelayValue[i]),
        .pattern(pattern[i]));
end
endgenerate

// Switch among the multiple gate drivers
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

generate
if (ADDRESS < 92) begin

    if (DIFFERENTIAL_OUPUT == "true") begin
        // Instantiate pin driver OSERDES
        gateDriverSERDES gateDriverSERDES (
           .data_out_from_device(pattern),
           .data_out_to_pins_p(P),
           .data_out_to_pins_n(N),
           .clk_in(kgdBitClk),
           .clk_div_in(kgdClk),
           .io_reset(1'b0));
    end

    if (DIFFERENTIAL_OUPUT == "false") begin
        // Instantiate pin driver OSERDES
        gateDriverSERDES_SE gateDriverSERDES (
           .data_out_from_device(pattern),
           .data_out_to_pins(P),
           .clk_in(kgdBitClk),
           .clk_div_in(kgdClk),
           .io_reset(1'b0));

        assign N = 1'b0;
    end
end
else begin
    if (DIFFERENTIAL_OUPUT == "true") begin
        // Instantiate pin driver OSERDES with ODELAY
        gateDriverSERDES_ODELAY gateDriverSERDES (
            .data_out_from_device(pattern),
            .data_out_to_pins_p(P),
            .data_out_to_pins_n(N),
            .out_delay_reset(1'b0),
            .out_delay_data_ce(1'b0),
            .out_delay_data_inc(1'b0),
            .out_delay_tap_in(odelayValue),
            .out_delay_tap_out(),
            .clk_in(kgdBitClk),
            .clk_div_in(kgdClk),
            .io_reset(1'b0));
    end

    if (DIFFERENTIAL_OUPUT == "false") begin
        // Instantiate pin driver OSERDES with ODELAY
        gateDriverSERDES_ODELAY_SE gateDriverSERDES (
            .data_out_from_device(pattern),
            .data_out_to_pins(P),
            .out_delay_reset(1'b0),
            .out_delay_data_ce(1'b0),
            .out_delay_data_inc(1'b0),
            .out_delay_tap_in(odelayValue),
            .out_delay_tap_out(),
            .clk_in(kgdBitClk),
            .clk_div_in(kgdClk),
            .io_reset(1'b0));

        assign N = 1'b0;
    end
end

endgenerate

endmodule
