//
// Forward data from one clock domain to another
//
module forwardData #(
    parameter DATA_WIDTH = 32
    ) (
    input                       inClk,
    input      [DATA_WIDTH-1:0] inData,
    input                       outClk,
    output reg [DATA_WIDTH-1:0] outData = 0);

// Flags
reg inReq = 0, inAck = 0;
reg outReq = 0, outReq_d = 0;

//
// Input clock domain
//
reg [DATA_WIDTH-1:0] inLatch;
(*ASYNC_REG="true"*) reg inAck_m = 0;

always @(posedge inClk) begin
    if (inReq == inAck) begin
        inReq <= !inReq;
        inLatch <= inData;
    end
    inAck_m <= outReq_d;
    inAck <= inAck_m;
end

//
// Output clock domain
//
(*ASYNC_REG="true"*) reg outReq_m = 0;
always @(posedge outClk) begin
    outReq_m <= inReq;
    outReq <= outReq_m;
    outReq_d <= outReq;
    if (outReq != outReq_d) begin
        outData <= inLatch;
    end
end

endmodule
