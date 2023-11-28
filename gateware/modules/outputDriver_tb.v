`timescale 1ns / 1ns

module outputDriver_tb #(
    parameter CSR_DATA_BUS_WIDTH                  = 32,
    parameter CSR_STROBE_BUS_WIDTH                = 1,
    parameter EVR_TRIGGER_PERIOD                  = 128,
    parameter CFG_EVR_OUTPUT_SERDES_WIDTH         = 4,
    parameter CFG_EVR_OUTPUT_PATTERN_ADDR_WIDTH   = 12,
    parameter CFG_EVR_DELAY_WIDTH                 = 22,
    parameter CFG_EVR_WIDTH_WIDTH                 = 22
);

// color printing defines
`define display_blue(s)     `set_blue_text; $display(s); `clear_text_color;
`define set_blue_text       $write("%c[1;34m",27);
`define set_red_text        $write("%c[1;31m", 27)
`define set_green_text      $write("%c[1;32m", 27)
`define set_yellow_text     $write("%c[1;33m", 27)
`define set_cyan_text       $write("%c[1;36m",27);
`define set_bold_text       $write("%c[1;30m",27);
`define clear_text_color    $write("%c[0m",27);

// GPIO Register offsets
localparam WR_REG_OFFSET_CSR         = 0;
localparam CSR_PATTERN_ADDRESS_SHIFT = 10;

// OPCODE CSR offset values
localparam CSR_W_OPCODE_SET_MODE       = 'h00000000,
           CSR_W_OPCODE_SET_DELAY      = 'h40000000,
           CSR_W_OPCODE_SET_WIDTH      = 'h80000000,
           CSR_W_OPCODE_SET_PATTERN    = 'hC0000000;

// Operating modes
localparam M_DISABLED        = 2'd0,
           M_PULSE           = 2'd1,
           M_PATTERN_SINGLE  = 2'd2,
           M_PATTERN_LOOP    = 2'd3;

////////////////////////////////////////////////////////////////////////////////
// TB signals
////////////////////////////////////////////////////////////////////////////////
reg module_done = 0;
reg module_ready = 0;
reg module_accepting_trigger = 0;
integer errors = 0;

initial begin
    if ($test$plusargs("vcd")) begin
        $dumpfile("outputDriver.vcd");
        $dumpvars(0, outputDriver_tb);
    end
    wait(module_done);
    $display("%s",errors==0?"# PASS":"# FAIL");
    $finish();
end
// sysClk 100 MHz
integer cc;
reg clk = 0;
initial begin
    clk = 0;
    for (cc = 0; cc < 3000; cc = cc+1) begin
        clk = 0; #5;
        clk = 1; #5;
    end
end
// evrClk 125 MHz
integer evr_cc;
reg evrClk = 0, evrTrigger = 0;
initial begin
    evrClk = 0;
    for (evr_cc = 0; evr_cc < 3750; evr_cc = evr_cc+1) begin
        evrClk = 0; #4;
        evrClk = 1; #4;
    end
end
// event trigger signal
initial begin
    repeat(100) begin
        wait(CSR0.ready==1 && (evr_cc%(EVR_TRIGGER_PERIOD))==0)
        @(posedge evrClk); evrTrigger <= 1'b1;
        @(posedge evrClk); evrTrigger <= 1'b0;
    end
end

////////////////////////////////////////////////////////////////////////////////
// CSR
////////////////////////////////////////////////////////////////////////////////
csrTestMaster # (
    .CSR_DATA_BUS_WIDTH(CSR_DATA_BUS_WIDTH),
    .CSR_STROBE_BUS_WIDTH(CSR_STROBE_BUS_WIDTH)
) CSR0 (
    .clk(clk)
);
wire [CSR_STROBE_BUS_WIDTH-1:0] GPIO_STROBES = CSR0.csr_stb_o;
wire [CSR_DATA_BUS_WIDTH-1:0] GPIO_OUT = CSR0.csr_data_o;

////////////////////////////////////////////////////////////////////////////////
// DUT
////////////////////////////////////////////////////////////////////////////////
wire [CFG_EVR_OUTPUT_SERDES_WIDTH-1:0] serdesPattern;
outputDriver #(
    .SERDES_WIDTH(CFG_EVR_OUTPUT_SERDES_WIDTH),
    .COARSE_DELAY_WIDTH(CFG_EVR_DELAY_WIDTH),
    .COARSE_WIDTH_WIDTH(CFG_EVR_WIDTH_WIDTH),
    .PATTERN_ADDRESS_WIDTH(CFG_EVR_OUTPUT_PATTERN_ADDR_WIDTH),
    .DEBUG("false"))
DUT(
    .sysClk(clk),
    .sysCsrStrobe(GPIO_STROBES),
    .sysGPIO_OUT(GPIO_OUT),
    .evrClk(evrClk),
    .triggerStrobe(evrTrigger),
    .serdesPattern(serdesPattern));

////////////////////////////////////////////////////////////////////////////////
// stimulus
////////////////////////////////////////////////////////////////////////////////

// Pulse parameters
parameter coarseWidthCount = 'hA, //10
          coarseDelayCount = 'h0,
          firstPattern     = 'hF,
          lastPattern      = 'hF;

// Pattern parameters
parameter PATTERN_BITSTRING = {{11{1'b0}},{5{1'b1}}},
          PATTERN_SIZE = $bits(PATTERN_BITSTRING),
          PATTERN_BITMASK = {CFG_EVR_OUTPUT_SERDES_WIDTH{1'b1}};
wire [$bits(PATTERN_BITSTRING)-1:0] patternBits = PATTERN_BITSTRING;
integer bitcount;

initial begin
    wait(CSR0.ready);
    @(posedge clk);
    //// DUT initialization ////
    module_done = 0;
    @(posedge clk);
    `set_cyan_text; $display("@%0d: ##### Module initialization #####", $time); `clear_text_color;
    `set_yellow_text; $display("Pattern string: %b (%4d)", patternBits, $bits(patternBits)); `clear_text_color;
    if ($bits(patternBits)%CFG_EVR_OUTPUT_SERDES_WIDTH) begin
        `set_red_text;
        $display("[!] ERROR lenght not integer multiple of SERDES output width");
        `clear_text_color;
    end

    // Set pulse delay
    CSR0.write32(WR_REG_OFFSET_CSR, CSR_W_OPCODE_SET_DELAY |
                                    (coarseDelayCount << CFG_EVR_OUTPUT_SERDES_WIDTH) |
                                    firstPattern);
    @(posedge clk);
    // Set pulse width
    CSR0.write32(WR_REG_OFFSET_CSR, CSR_W_OPCODE_SET_WIDTH |
                                    (coarseWidthCount << CFG_EVR_OUTPUT_SERDES_WIDTH) |
                                    lastPattern);
    @(posedge clk);
    // Set pattern bit string
    for (bitcount=0; bitcount<PATTERN_SIZE/CFG_EVR_OUTPUT_SERDES_WIDTH; bitcount=bitcount+1) begin
        CSR0.write32(WR_REG_OFFSET_CSR, CSR_W_OPCODE_SET_PATTERN |
                                        bitcount<<CSR_PATTERN_ADDRESS_SHIFT |
                                        (PATTERN_BITMASK & (patternBits>>(bitcount*CFG_EVR_OUTPUT_SERDES_WIDTH))));
        @(posedge clk);
    end
    // Set pattern mode
    CSR0.write32(WR_REG_OFFSET_CSR, CSR_W_OPCODE_SET_MODE | M_PATTERN_LOOP);
    @(posedge clk);

    `set_cyan_text; $display("@%0d: ##### Module initialization complete #####", $time);  `clear_text_color;

    // waits for mode changing
    repeat(1000) begin
        @(posedge evrClk);
    end
    CSR0.write32(WR_REG_OFFSET_CSR, CSR_W_OPCODE_SET_MODE | M_PATTERN_SINGLE);

    repeat(100) begin
        @(posedge evrClk);
    end
    CSR0.write32(WR_REG_OFFSET_CSR, CSR_W_OPCODE_SET_MODE | M_PATTERN_SINGLE);

    repeat(100) begin
        @(posedge evrClk);
    end
    CSR0.write32(WR_REG_OFFSET_CSR, CSR_W_OPCODE_SET_MODE | M_PULSE);

    repeat(100) begin
        @(posedge evrClk);
    end
    CSR0.write32(WR_REG_OFFSET_CSR, CSR_W_OPCODE_SET_MODE | M_PATTERN_LOOP);

    repeat(100) begin
        @(posedge evrClk);
    end
    CSR0.write32(WR_REG_OFFSET_CSR, CSR_W_OPCODE_SET_MODE | M_PULSE);
end

endmodule
