// Let processor read events
module evrLogger #(
    parameter DEBUG = "false"
    ) (
    input         sysClk,
    input  [31:0] GPIO_OUT,
    input         csrStrobe,
    output [31:0] status,

    input       evrClk,
    input       evrCodeValid,
    input [7:0] evrCode);

///////////////////////////////////////////////////////////////////////////////
// System clock domain
(*mark_debug=DEBUG*) reg        sysReset = 0;
(*mark_debug=DEBUG*) wire       sysRdEnable;
(*mark_debug=DEBUG*) wire       sysRdEmpty;
(*mark_debug=DEBUG*) wire [7:0] sysRdData;
assign sysRdEnable = csrStrobe && GPIO_OUT[8];
always @(posedge sysClk) begin
    if (csrStrobe) begin
        sysReset <= GPIO_OUT[9];
    end
end
assign status = {22'b0, sysReset, sysRdEmpty, sysRdData};

`ifndef SIMULATE
evLogFIFO evLogFIFO (
  .rst(sysReset),
  .wr_clk(evrClk),
  .wr_en(evrCodeValid),
  .din(evrCode),
  .full(),
  .rd_clk(sysClk),
  .rd_en(sysRdEnable),
  .dout(sysRdData),
  .empty(sysRdEmpty));
`endif // `ifndef SIMULATE

endmodule
