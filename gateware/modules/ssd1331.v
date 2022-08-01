/*
 * Wrapper to provide register access to SolomonSystech display controller
 */
module ssd1331 #(
    parameter CLK_RATE = -1,
    parameter DEBUG    = "false"
    ) (
    input                              clk,
    (*mark_debug=DEBUG*) input  [31:0] GPIO_OUT,
    (*mark_debug=DEBUG*) input         csrStrobe,
                         output [31:0] status,

    (*mark_debug=DEBUG*) output SPI_CLK,
    (*mark_debug=DEBUG*) output SPI_CSN,
    (*mark_debug=DEBUG*) output SPI_D_CN,
    (*mark_debug=DEBUG*) output SPI_DOUT,
    (*mark_debug=DEBUG*) output VP_ENABLE,
    (*mark_debug=DEBUG*) output RESETN);

reg [15:0] TDATA = 0;
reg        TVALID = 0;
reg        TLAST = 0;
wire       TREADY;

assign status = {6'b0, VP_ENABLE, !RESETN, 7'b0, TREADY, TDATA};

always @(posedge clk) begin
    if (csrStrobe) begin
        TDATA <= GPIO_OUT[15:0];
        TLAST <= GPIO_OUT[16];
        TVALID <= 1;
    end
    else if (TREADY) begin
        TVALID <= 0;
    end
end

solomonSystechSPI #(.CLK_RATE(CLK_RATE))
  solomonSystechSPI (
    .clk(clk),
    .TDATA(TDATA),
    .TVALID(TVALID),
    .TLAST(TLAST),
    .TREADY(TREADY),
    .SPI_CLK(SPI_CLK),
    .SPI_CSN(SPI_CSN),
    .SPI_D_CN(SPI_D_CN),
    .SPI_DOUT(SPI_DOUT),
    .VP_ENABLE(VP_ENABLE),
    .RESETN(RESETN));

endmodule
