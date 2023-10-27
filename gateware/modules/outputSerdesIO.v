module outputSerdesIO #(
    parameter DIFFERENTIAL_OUPUT = "false",
    parameter DATA_WIDTH = 4
    ) (
    input  [DATA_WIDTH-1:0] dataIn,      // Parallel input data
    output                  dataOutP,    // Differential positive or single-ended pin
    output                  dataOutN,    // Differential negative pin
    input                   serialClk,   // Serial-side clock
    input                   parallelClk, // Parallel-side clock
    input                   clockEnable, // Clock enable
    input                   reset);      // Async assertion, sync deassertion

    // OUTPUT BUFFER ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    wire oserdesOuput;
	generate
    case(DIFFERENTIAL_OUPUT)
    "true": begin
        OBUFDS #(.IOSTANDARD ("LVDS_25"))
        obufds_inst (
            .O          (dataOutP),
            .OB         (dataOutN),
            .I          (oserdesOuput)
            );
        end
    "false": begin
        OBUF #(.IOSTANDARD ("LVCMOS25"))
        obuf_inst (
            .O          (dataOutP),
            .I          (oserdesOuput)
            );
        end
    default: begin // block syntesis otherwise
        DIFFERENTIAL_OUPUT_HAS_WRONG_VALUE();
    end
    endcase
    endgenerate

    // OUTPUT SERDES ||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
    wire [7:0] oserdesInput;
    genvar in_count;
    for (in_count = 0; in_count < DATA_WIDTH; in_count = in_count + 1)
    begin
        assign oserdesInput[in_count] = dataIn[in_count];
    end

    OSERDESE2 # (
        .DATA_RATE_OQ   ("SDR"),
        .DATA_RATE_TQ   ("SDR"),
        .DATA_WIDTH     (DATA_WIDTH),
        .TRISTATE_WIDTH (1),
        .SERDES_MODE    ("MASTER"))
    oserdese2_master (
        .D1             (oserdesInput[0]),
        .D2             (oserdesInput[1]),
        .D3             (oserdesInput[2]),
        .D4             (oserdesInput[3]),
        .D5             (oserdesInput[4]),
        .D6             (oserdesInput[5]),
        .D7             (oserdesInput[6]),
        .D8             (oserdesInput[7]),
        .T1             (1'b0),
        .T2             (1'b0),
        .T3             (1'b0),
        .T4             (1'b0),
        .SHIFTIN1       (1'b0),
        .SHIFTIN2       (1'b0),
        .SHIFTOUT1      (),
        .SHIFTOUT2      (),
        .OCE            (clockEnable),
        .CLK            (serialClk),
        .CLKDIV         (parallelClk),
        .OQ             (oserdesOuput),
        .TQ             (),
        .OFB            (),
        .TFB            (),
        .TBYTEIN        (1'b0),
        .TBYTEOUT       (),
        .TCE            (1'b0),
        .RST            (reset));

endmodule

