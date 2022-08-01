// Pretrigger delay
// Event receiver clock domain

module pretrigger #(
    parameter   CFG_POST_PRETRIGGER_DELAY_TICKS = 100
    ) (
    input       evrClk,
    input       evrPretrigger,
    output wire evrGateDriverStrobe);

localparam DELAY_RELOAD = (CFG_POST_PRETRIGGER_DELAY_TICKS >= 2) ?
                                        CFG_POST_PRETRIGGER_DELAY_TICKS - 2 : 0;

localparam DELAY_COUNTER_WIDTH = $clog2(DELAY_RELOAD+1);
wire [DELAY_COUNTER_WIDTH-1:0] cfgDelayReload = DELAY_RELOAD;
wire [DELAY_COUNTER_WIDTH:0] counterReload = {1'b0, cfgDelayReload};

reg evrPretrigger_d;
reg [DELAY_COUNTER_WIDTH:0] evrDelayCounter = 0;
reg evrDelayActive = 0;
assign evrGateDriverStrobe = evrDelayCounter[DELAY_COUNTER_WIDTH];

always @(posedge evrClk) begin
    evrPretrigger_d <= evrPretrigger;
    if (evrDelayActive) begin
        if (evrGateDriverStrobe) begin
            evrDelayCounter <= cfgDelayReload;
            evrDelayActive <= 0;
        end
        else begin
            evrDelayCounter <= evrDelayCounter - 1;
        end
    end
    else if (!evrPretrigger && evrPretrigger_d) begin
        evrDelayCounter <= cfgDelayReload;
        evrDelayActive <= 1;
    end
end

endmodule
