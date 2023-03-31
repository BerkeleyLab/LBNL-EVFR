module ODELAYE2 (
    output [4:0] CNTVALUEOUT,
    output reg DATAOUT,
    input C,
    input CE,
    input CINVCTRL,
    input CLKIN,
    input [4:0] CNTVALUEIN,
    input INC,
    input LD,
    input LDPIPEEN,
    input ODATAIN,
    input REGRST
);

parameter CINVCTRL_SEL = "FALSE";
parameter DELAY_SRC = "ODATAIN";
parameter HIGH_PERFORMANCE_MODE    = "FALSE";
parameter [0:0] IS_C_INVERTED = 1'b0;
parameter [0:0] IS_ODATAIN_INVERTED = 1'b0;
parameter ODELAY_TYPE  = "FIXED";
parameter integer ODELAY_VALUE = 0;
parameter PIPE_SEL = "FALSE";
parameter real REFCLK_FREQUENCY = 200.0;
parameter SIGNAL_PATTERN    = "DATA";

// To get a bit more than 360 degree range
localparam real TAP_DEL = (1.0 / REFCLK_FREQUENCY * 1000 / 31);

reg [4:0] cntValue = 5'h0;
assign CNTVALUEOUT = cntValue;

always @(posedge C) begin
    if(LD) begin
        cntValue <= CNTVALUEIN;
    end
end

reg [31:0] shiftReg = 32'h0;
always begin
    #(TAP_DEL);
    shiftReg = { shiftReg[30:0], ODATAIN };
    DATAOUT = shiftReg[cntValue];
end

endmodule
