// Emit pulse with specified delay and width
module evrProgrammablePulse (
    input  wire        sysClk,
    input  wire        sysSetDelayStrobe,
    input  wire        sysSetWidthStrobe,
    input  wire [31:0] sysData,

    input  wire clk,
    input  wire trigger,
    output wire pulse);

localparam SETTINGS_WIDTH = 30;
reg [SETTINGS_WIDTH-1:0] sysDelay = 0, sysWidth = 0;
reg sysNewDelayToggle = 0, sysNewWidthToggle = 0;
(*ASYNC_REG="true"*) reg newDelaytoggle_m;
(*ASYNC_REG="true"*) reg newWidthtoggle_m;
reg newDelayToggle = 0, newWidthToggle = 0;
reg newDelayToggle_d = 0, newWidthToggle_d = 0;

localparam COUNTER_WIDTH = SETTINGS_WIDTH + 1;
reg [COUNTER_WIDTH-1:0] delayReload = ~0, widthReload = 0;
reg [COUNTER_WIDTH-1:0] delayCounter = 0, widthCounter = 0;
wire delayDone = delayCounter[COUNTER_WIDTH-1];
wire noDelay = delayReload[COUNTER_WIDTH-1];
wire hasWidth = widthReload[COUNTER_WIDTH-1];
assign pulse = widthCounter[COUNTER_WIDTH-1];
reg trigger_d = 1;
reg delaying = 0;
reg delayDone_d = 0;

always @(posedge sysClk) begin
    if (sysSetDelayStrobe) begin
        sysDelay <= sysData[SETTINGS_WIDTH-1:0];
        sysNewDelayToggle <= !sysNewDelayToggle;
    end
    if (sysSetWidthStrobe) begin
        sysWidth <= sysData[SETTINGS_WIDTH-1:0];
        sysNewWidthToggle <= !sysNewWidthToggle;
    end
end

always @(posedge clk) begin
    newDelaytoggle_m <= sysNewDelayToggle;
    newDelayToggle   <= newDelaytoggle_m;
    newDelayToggle_d <= newDelayToggle;
    if (newDelayToggle != newDelayToggle_d) begin
        delayReload <= {1'b0, sysDelay} - 1;
    end

    newWidthtoggle_m <= sysNewWidthToggle;
    newWidthToggle   <= newWidthtoggle_m;
    newWidthToggle_d <= newWidthToggle;
    if (newWidthToggle != newWidthToggle_d) begin
        widthReload <= {1'b0, {SETTINGS_WIDTH{1'b1}}} + {1'b0, sysWidth};
    end
    
    trigger_d <= trigger;
    if (hasWidth) begin
        if (pulse) begin
            widthCounter <= widthCounter - 1;
        end
        else if (!delayDone) begin
            delayCounter <= delayCounter - 1;
        end
        else if (delaying) begin
            widthCounter <= widthReload;
            delaying <= 0;
        end
        else if (trigger && !trigger_d) begin
            delayCounter <= delayReload - 1;
            if (noDelay) begin
                widthCounter <= widthReload;
            end
            else begin
                delaying <= 1;
            end
        end
    end
    else begin
        widthCounter <= 0;
    end
end
endmodule
