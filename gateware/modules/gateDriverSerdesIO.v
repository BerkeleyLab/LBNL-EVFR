module gateDriverSerdesIO #(
    parameter DIFFERENTIAL_OUPUT = "false",
    parameter DATA_WIDTH = 10,
    parameter WITH_ODELAY = "false"
    ) (
    input                   serialClk,   // Serial-side clock
    input                   parallelClk, // Parallel-side clock

    input                   reset,       // Async assertion, sync deassertion

    input                   clockEnable, // Clock enable

    input  [DATA_WIDTH-1:0] dataIn,      // Parallel input data
    output                  dataOutP,    // Differential positive or single-ended pin
    output                  dataOutN,    // Differential negative pin

    input                   delayReset,
    input                   delayClockEnable,
    input                   delayInc,
    input             [4:0] delayInValue,
    output            [4:0] delayOutValue);

generate
if (DATA_WIDTH != 10) begin
    DATA_WIDTH_can_only_be_set_to_10();
end
endgenerate

/////////////////////////
// Output SERDES
/////////////////////////

wire [13:0] oserdesInput;
genvar in_count;
for (in_count = 0; in_count < DATA_WIDTH; in_count = in_count + 1)
begin
    assign oserdesInput[14-in_count-1] = dataIn[in_count];
end

wire ocascade_sm_d;
wire ocascade_sm_t;
wire oserdesPredelayOQ;
wire oserdesPredelayOFB;

OSERDESE2
  #(
    .DATA_RATE_OQ   ("DDR"),
    .DATA_RATE_TQ   ("SDR"),
    .DATA_WIDTH     (10),
    .TRISTATE_WIDTH (1),
    .SERDES_MODE    ("MASTER"))
  oserdese2_master (
    .D1             (oserdesInput[13]),
    .D2             (oserdesInput[12]),
    .D3             (oserdesInput[11]),
    .D4             (oserdesInput[10]),
    .D5             (oserdesInput[9]),
    .D6             (oserdesInput[8]),
    .D7             (oserdesInput[7]),
    .D8             (oserdesInput[6]),
    .T1             (1'b0),
    .T2             (1'b0),
    .T3             (1'b0),
    .T4             (1'b0),
    .SHIFTIN1       (ocascade_sm_d),
    .SHIFTIN2       (ocascade_sm_t),
    .SHIFTOUT1      (),
    .SHIFTOUT2      (),
    .OCE            (clockEnable),
    .CLK            (serialClk),
    .CLKDIV         (parallelClk),
    .OQ             (oserdesPredelayOQ),
    .TQ             (),
    .OFB            (oserdesPredelayOFB),
    .TFB            (),
    .TBYTEIN        (1'b0),
    .TBYTEOUT       (),
    .TCE            (1'b0),
    .RST            (reset));

OSERDESE2
  #(
    .DATA_RATE_OQ   ("DDR"),
    .DATA_RATE_TQ   ("SDR"),
    .DATA_WIDTH     (10),
    .TRISTATE_WIDTH (1),
    .SERDES_MODE    ("SLAVE"))
  oserdese2_slave (
    .D1             (1'b0),
    .D2             (1'b0),
    .D3             (oserdesInput[5]),
    .D4             (oserdesInput[4]),
    .D5             (oserdesInput[3]),
    .D6             (oserdesInput[2]),
    .D7             (oserdesInput[1]),
    .D8             (oserdesInput[0]),
    .T1             (1'b0),
    .T2             (1'b0),
    .T3             (1'b0),
    .T4             (1'b0),
    .SHIFTOUT1      (ocascade_sm_d),
    .SHIFTOUT2      (ocascade_sm_t),
    .SHIFTIN1       (1'b0),
    .SHIFTIN2       (1'b0),
    .OCE            (clockEnable),
    .CLK            (serialClk),
    .CLKDIV         (parallelClk),
    .OQ             (),
    .TQ             (),
    .OFB            (),
    .TFB            (),
    .TBYTEIN        (1'b0),
    .TBYTEOUT       (),
    .TCE            (1'b0),
    .RST            (reset));

/////////////////////////
// ODELAY
/////////////////////////

generate
case(WITH_ODELAY)

"true": begin
    ODELAYE2
      # (
        .CINVCTRL_SEL           ("FALSE"),
        .DELAY_SRC              ("ODATAIN"),
        .HIGH_PERFORMANCE_MODE  ("FALSE"),
        .ODELAY_TYPE            ("VAR_LOAD"),
        .ODELAY_VALUE           (0),
        .REFCLK_FREQUENCY       (200.0),
        .PIPE_SEL               ("FALSE"),
        .SIGNAL_PATTERN         ("DATA")
        )
      odelaye2_bus (
        .DATAOUT                (oserdesOutput),
        .CLKIN                  (1'b0),
        .C                      (parallelClk),
        .CE                     (clockEnable),
        .INC                    (delayInc),
        .ODATAIN                (oserdesPredelayOFB),
        .LD                     (delayReset),
        .REGRST                 (reset),
        .LDPIPEEN               (1'b0),
        .CNTVALUEIN             (delayInValue),
        .CNTVALUEOUT            (delayOutValue),
        .CINVCTRL               (1'b0)
        );
end

"false": begin

assign oserdesOutput = oserdesPredelayOQ;

end

default: begin // block syntesis otherwise
    WITH_ODELAY_can_only_be_true_or_false();
end

endcase
endgenerate

/////////////////////////
// Output Buffer
/////////////////////////

wire oserdesOutput;
generate
case(DIFFERENTIAL_OUPUT)

"true": begin
    OBUFDS #(.IOSTANDARD ("DEFAULT"))
    obufds_inst (
        .O          (dataOutP),
        .OB         (dataOutN),
        .I          (oserdesOutput)
        );
    end
"false": begin
    OBUF #(.IOSTANDARD ("DEFAULT"))
    obuf_inst (
        .O          (dataOutP),
        .I          (oserdesOutput)
        );
    end
default: begin // block syntesis otherwise
    DIFFERENTIAL_OUPUT_HAS_WRONG_VALUE();
end

endcase
endgenerate

endmodule
