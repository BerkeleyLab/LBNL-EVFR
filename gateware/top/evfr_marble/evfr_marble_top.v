/*
 * Event fanout/receiver top level module
 */
module evfr_marble_top #(
   // Include file is machine generated from C header
    `include "gpioIDX.vh"
    parameter SYSCLK_FREQUENCY        = 100000000,
    // Each receiver and transmitter counts as a firefly, so must divide by 2.
    parameter EVIO_FIREFLY_SELECT_WIDTH = (CFG_EVIO_FIREFLY_COUNT + 1) / 2
    ) (
    input  DDR_REF_CLK_P, DDR_REF_CLK_N,
    output VCXO_EN,
    output PHY_RSTN,

    output wire BOOT_CS_B,
    output wire BOOT_MOSI,
    input       BOOT_MISO,

    input            RGMII_RX_CLK,
    input            RGMII_RX_CTRL,
    input      [3:0] RGMII_RXD,
    output wire      RGMII_TX_CLK,
    output wire      RGMII_TX_CTRL,
    output wire[3:0] RGMII_TXD,

    input  MGT_CLK_P, MGT_CLK_N,
    input  MGT_RX_P, MGT_RX_N,
    output MGT_TX_P, MGT_TX_N,

`ifdef KICKER_DRIVER
    output [CFG_KD_OUTPUT_COUNT-1:0] DRIVER_P,
    output [CFG_KD_OUTPUT_COUNT-1:0] DRIVER_N,
    // FIXME: Do we need pretrigger outputs on some PMOD lines too?
`else
    // FMC1 EVIO (only in event fanout)
    input   [CFG_EVIO_HARDWARE_TRIGGER_COUNT-1:0] FMC1_hwTrigger,
    input                                         FMC1_auxInput,
    input            [CFG_EVIO_DIAG_IN_COUNT-1:0] FMC1_diagnosticIn,
    output wire     [CFG_EVIO_DIAG_OUT_COUNT-1:0] FMC1_diagnosticOut,
    input            [CFG_EVIO_FIREFLY_COUNT-1:0] FMC1_fireflyPresent_n,
    output         [CFG_EVIO_FIREFLY_COUNT/2-1:0] FMC1_fireflySelect_n,
    output                                        FMC1_sysReset_n,
    inout                                         FMC1_EVIO_SCL,
    inout                                         FMC1_EVIO_SDA,
    input                                         FMC1_FAN1_TACH,
    input                                         FMC1_FAN2_TACH,

    // FMC2 EVRIO (only in event receiver)
    // FIXME: For now we're using a UTIO board here
    //        Hopefully the EVRIO board will be backwards compatible....
    input          UTIO_PLL_OUT_P,
    input          UTIO_PLL_OUT_N,
    output         UTIO_PLL_REF_P,
    output         UTIO_PLL_REF_N,
    output   [2:0] UTIO_PATTERN_P,
    output   [2:0] UTIO_PATTERN_N,
    output         UTIO_TRIGGER_P,
    output         UTIO_TRIGGER_N,
    output         UTIO_PLL_RESET_N,
    input    [7:0] UTIO_SWITCHES,
    output   [1:0] UTIO_LED,
    output         UTIO_EVR_HB,
    output         UTIO_PWR_EN,
    input          UTIO_5V1_PG,
    input          UTIO_5V2_PG,
    inout          UTIO_SCL,
    inout          UTIO_SDA,
`endif

    // SPI between FPGA and microcontroller
    input  FPGA_SCLK,
    input  FPGA_CSB,
    input  FPGA_MOSI,
    output FPGA_MISO,

    // Front panel display and switches
    output PMOD1_0,
    output PMOD1_1,
    input  PMOD1_2,
    input  PMOD1_3,
    output PMOD1_4,
    output PMOD1_5,
    output PMOD1_6,
    output PMOD1_7,

    // FIXME: Test points (maybe kicker pretrigger someday?)
    output PMOD2_0,
    output PMOD2_1,
    output PMOD2_2,
    output PMOD2_3,
    output PMOD2_4,
    output PMOD2_5,
    input  PMOD2_6,
    input  PMOD2_7,

    // Test points -- FIXME: THESE ARE FOR THE FMC-DBG FOR TEMPORARY TESTING
    output FMC1_CLK1_M2C_P,
    output FMC1_CLK1_M2C_N,

    output TWI_SCL,
    inout  TWI_SDA,

    // The RxD and TxD directions are with respect
    // to the USB/UART chip, not the FPGA!
    output FPGA_RxD,
    input  FPGA_TxD);

`include "firmwareBuildDate.v"

///////////////////////////////////////////////////////////////////////////////
// Static outputs
assign VCXO_EN = 1'b0;
assign PHY_RSTN = 1'b1;
assign PMOD2_0 = 1'b0;
assign PMOD2_1 = 1'b0;
assign PMOD2_2 = 1'b0;
assign PMOD2_3 = 1'b0;
assign PMOD2_4 = 1'b0;
assign PMOD2_5 = 1'b0;
assign UTIO_PWR_EN = 1'b1;
assign UTIO_LED = 2'h0;

///////////////////////////////////////////////////////////////////////////////
// Clocks
wire sysClk, refClk125, refClk125d90, refClk200;
wire evrClk, evrBitClk;
wire ethernetRxClk, ethernetTxClk;

wire mgtRefClk, mgtRefClkMonitor;
IBUFDS_GTE2 mgtRef (.I(MGT_CLK_P),
                    .IB(MGT_CLK_N),
                    .CEB(1'b0),
                    .O(mgtRefClk),
                    .ODIV2());
BUFG mgtRefBUFG (.I(mgtRefClk), .O(mgtRefClkMonitor));

///////////////////////////////////////////////////////////////////////////////
// Resets
wire sysReset;
assign FMC1_sysReset_n  = !sysReset;

//////////////////////////////////////////////////////////////////////////////
// General-purpose I/O block
wire                    [31:0] GPIO_IN[0:GPIO_IDX_COUNT-1];
wire                    [31:0] GPIO_OUT;
wire      [GPIO_IDX_COUNT-1:0] GPIO_STROBES;
wire [(GPIO_IDX_COUNT*32)-1:0] GPIO_IN_FLATTENED;
genvar i;
generate
for (i = 0 ; i < GPIO_IDX_COUNT ; i = i + 1) begin : gpio_flatten
    assign GPIO_IN_FLATTENED[ (i*32)+31 : (i*32)+0 ] = GPIO_IN[i];
end
endgenerate
assign GPIO_IN[GPIO_IDX_FIRMWARE_BUILD_DATE] = FIRMWARE_BUILD_DATE;

//////////////////////////////////////////////////////////////////////////////
// Front panel controls

frontPanelSwitches #(
    .CLK_RATE(SYSCLK_FREQUENCY),
    .DEBOUNCE_MS(30),
    .DEBUG("false"))
  frontPanelSwitches (
    .clk(sysClk),
    .GPIO_OUT(GPIO_OUT),
    .status(GPIO_IN[GPIO_IDX_USER_GPIO_CSR]),
    .displaySwitch_n(PMOD1_3),
    .resetSwitch_n(PMOD1_2));

/////////////////////////////////////////////////////////////////////////////
// Display
ssd1331 #(.CLK_RATE(SYSCLK_FREQUENCY),
          .DEBUG("false"))
  ssd1331 (
    .clk(sysClk),
    .GPIO_OUT(GPIO_OUT),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_DISPLAY]),
    .status(GPIO_IN[GPIO_IDX_DISPLAY]),
    .SPI_CLK(PMOD1_7),
    .SPI_CSN(PMOD1_4),
    .SPI_D_CN(PMOD1_1),
    .SPI_DOUT(PMOD1_5),
    .VP_ENABLE(PMOD1_6),
    .RESETN(PMOD1_0));

//////////////////////////////////////////////////////////////////////////////
// Timekeeping
clkIntervalCounters #(.CLK_RATE(SYSCLK_FREQUENCY))
  clkIntervalCounters (
    .clk(sysClk),
    .microsecondsSinceBoot(GPIO_IN[GPIO_IDX_MICROSECONDS_SINCE_BOOT]),
    .secondsSinceBoot(GPIO_IN[GPIO_IDX_SECONDS_SINCE_BOOT]),
    .PPS());

//////////////////////////////////////////////////////////////////////////////
// Boot Flash
wire spiFlashClk;
`ifndef SIMULATE
STARTUPE2 aspiClkPin(.USRCCLKO(spiFlashClk), .USRCCLKTS(1'b0));
`endif // `ifndef SIMULATE
// Trivial bit-banging connection to bootstrap flash memory
spiFlashBitBang #(.DEBUG("false"))
  spiFlash_i (
    .sysClk(sysClk),
    .sysGPIO_OUT(GPIO_OUT),
    .sysCSRstrobe(GPIO_STROBES[GPIO_IDX_QSPI_FLASH_CSR]),
    .sysStatus(GPIO_IN[GPIO_IDX_QSPI_FLASH_CSR]),
    .spiFlashClk(spiFlashClk),
    .spiFlashMOSI(BOOT_MOSI),
    .spiFlashCS_B(BOOT_CS_B),
    .spiFlashMISO(BOOT_MISO));

///////////////////////////////////////////////////////////////////////////////
// Microcontroller I/O
mmcMailbox #(.DEBUG("false"))
  mmcMailbox (
    .clk(sysClk),
    .GPIO_OUT(GPIO_OUT),
    .GPIO_STROBE(GPIO_STROBES[GPIO_IDX_MMC_MAILBOX]),
    .csr(GPIO_IN[GPIO_IDX_MMC_MAILBOX]),
    .SCLK(FPGA_SCLK),
    .CSB(FPGA_CSB),
    .MOSI(FPGA_MOSI),
    .MISO(FPGA_MISO));

/////////////////////////////////////////////////////////////////////////////
// Event receiver
wire evrPPSmarker;
wire [CFG_EVR_OUTPUT_COUNT-1:0] evrTriggerBus;
wire [7:0] evrCode;
wire       evrCodeValid;
evr #(.EVR_CLOCK_RATE(CFG_EVR_CLOCK_RATE),
      .OUTPUT_COUNT(CFG_EVR_OUTPUT_COUNT),
      .DEBUG("false"))
  evr (
    .sysClk(sysClk),
    .sysGPIO_OUT(GPIO_OUT),
    .sysActionStrobe(GPIO_STROBES[GPIO_IDX_EVR_MONITOR_CSR]),
    .drpStrobe(GPIO_STROBES[GPIO_IDX_EVR_MGT_DRP_CSR]),
    .drpStatus(GPIO_IN[GPIO_IDX_EVR_MGT_DRP_CSR]),
    .mgtRxStatus(GPIO_IN[GPIO_IDX_EVR_MGT_STATUS]),
    .status(GPIO_IN[GPIO_IDX_EVR_MONITOR_CSR]),
    .monitorSeconds(GPIO_IN[GPIO_IDX_EVR_MONITOR_SECONDS]),
    .monitorTicks(GPIO_IN[GPIO_IDX_EVR_MONITOR_TICKS]),
    .todSeconds(GPIO_IN[GPIO_IDX_EVR_SECONDS]),
    .refClk(refClk200),
    .evrClk(evrClk),
    .evrCode(evrCode),
    .evrCodeValid(evrCodeValid),
    .evrTriggerBus(evrTriggerBus),
    .evrDistributedBus(),
    .evrPPSmarker(evrPPSmarker),
    .mgtRefClk(mgtRefClk),
    .MGT_RX_P(MGT_RX_P),
    .MGT_RX_N(MGT_RX_N),
    .MGT_TX_P(MGT_TX_P),
    .MGT_TX_N(MGT_TX_N));

/////////////////////////////////////////////////////////////////////////////
// Pass events to processor
evrLogger #(.DEBUG("false"))
  evrLogger (
    .sysClk(sysClk),
    .GPIO_OUT(GPIO_OUT),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_EVR_LOG_CSR]),
    .status(GPIO_IN[GPIO_IDX_EVR_LOG_CSR]),
    .evrClk(evrClk),
    .evrCode(evrCode),
    .evrCodeValid(evrCodeValid));

//////////////////////////////////////////////////////////////////////////////
// I2C
// Three channel version a holdover from Marble Mini layout, but keep
// the extra two channels as dummies until the IIC command table has
// been updated.
wire [2:0] sda_drive, sda_sense;
wire [3:0] iic_proc_o;
wire [1:0] sclUnused;
i2cHandler #(.CLK_RATE(SYSCLK_FREQUENCY),
             .CHANNEL_COUNT(3),
             .DEBUG("false"))
  i2cHandler (
    .clk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_I2C_CHUNK_CSR]),
    .GPIO_OUT(GPIO_OUT),
    .status(GPIO_IN[GPIO_IDX_I2C_CHUNK_CSR]),
    .scl({sclUnused[1], sclUnused[0], scl0}),
    .sda_drive(sda_drive),
    .sda_sense(sda_sense));
IOBUF sdaIO0 (.I(1'b0),
              .IO(TWI_SDA),
              .O(sda_sense[0]),
              .T(iic_proc_o[2] ? iic_proc_o[1] : sda_drive[0]));
assign sda_sense[2:1] = 0;
assign TWI_SCL = iic_proc_o[2] ? iic_proc_o[0] : scl0;
wire [3:0] iic_proc_i = { sda_sense[0], iic_proc_o[2:0] };

/////////////////////////////////////////////////////////////////////////////
// Measure clock rates
frequencyCounters #(.NF(5),
                    .CLK_RATE(SYSCLK_FREQUENCY),
                    .DEBUG("false"))
  frequencyCounters (
    .clk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_FREQ_MONITOR_CSR]),
    .GPIO_OUT(GPIO_OUT),
    .status(GPIO_IN[GPIO_IDX_FREQ_MONITOR_CSR]),
    .unknownClocks({ethernetRxClk,
                    ethernetTxClk,
                    evrClk,
                    mgtRefClkMonitor,
                    sysClk}),
    .ppsMarker_a(evrPPSmarker));

///////////////////////////////////////////////////////////////////////////////
// Ethernet
badger badger (
    .sysClk(sysClk),
    .sysGPIO_OUT(GPIO_OUT),
    .sysConfigStrobe(GPIO_STROBES[GPIO_IDX_NET_CONFIG_CSR]),
    .sysTxStrobe(GPIO_STROBES[GPIO_IDX_NET_TX_CSR]),
    .sysRxStrobe(GPIO_STROBES[GPIO_IDX_NET_RX_CSR]),
    .sysTxStatus(GPIO_IN[GPIO_IDX_NET_TX_CSR]),
    .sysRxStatus(GPIO_IN[GPIO_IDX_NET_RX_CSR]),
    .sysRxDataStrobe(GPIO_STROBES[GPIO_IDX_NET_RX_DATA]),
    .sysRxData(GPIO_IN[GPIO_IDX_NET_RX_DATA]),
    .refClk125(refClk125),
    .refClk125d90(refClk125d90),
    .rx_clk(ethernetRxClk),
    .tx_clk(ethernetTxClk),
    .RGMII_RX_CLK(RGMII_RX_CLK),
    .RGMII_RX_CTRL(RGMII_RX_CTRL),
    .RGMII_RXD(RGMII_RXD),
    .RGMII_TX_CLK(RGMII_TX_CLK),
    .RGMII_TX_CTRL(RGMII_TX_CTRL),
    .RGMII_TXD(RGMII_TXD));

`ifdef KICKER_DRIVER
// FIXME: If pretrigger is needed, add programmable pulse generator and use leading edge of to generate it and trailing edge to drive evrGateStrobe -- or use two trigger bus lines and individual pretrigger/trigger event codes.
/////////////////////////////////////////////////////////////////////////////
// Gate driver clocks
wire kgdClk, kgdBitClk, kgdGateStrobe;
wire sysIdelayControlReset;
kickerDriverClockGenerator #(.DEBUG("false"))
  kickerDriverClockGenerator (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_CONFIG_KD_GATE_DRIVER]),
    .sysGPIO_OUT(GPIO_OUT),
    .sysStatus(GPIO_IN[GPIO_IDX_CONFIG_KD_GATE_DRIVER]),
    .evrClk(evrClk),
    .evrGateStrobe(evrTriggerBus[0]),
    .refClk200(refClk200),
    .sysIdelayControlReset(sysIdelayControlReset),
    .kgdClk(kgdClk),
    .kgdBitClk(kgdBitClk),
    .kgdGateStrobe(kgdGateStrobe));
assign FMC1_CLK1_M2C_P = evrTriggerBus[0];
assign FMC1_CLK1_M2C_N = kgdGateStrobe;
assign FMC1_FAN1_TACH = PMOD2_6;
assign FMC2_FAN1_TACH = PMOD2_7;

/////////////////////////////////////////////////////////////////////////////
// Gate drivers
generate
for (i = 0 ; i < CFG_KD_OUTPUT_COUNT ; i = i + 1) begin : gateDrivers
  gateDriver #(.ADDRESS(i))
   gateDriver (
    .sysClk(sysClk),
    .sysCsrStrobe(GPIO_STROBES[GPIO_IDX_CONFIG_KD_GATE_DRIVER]),
    .sysGPIO_OUT(GPIO_OUT),
    .kgdClk(kgdClk),
    .kgdBitClk(kgdBitClk),
    .kgdStrobe(kgdGateStrobe),
    .P(DRIVER_P[i]),
    .N(DRIVER_N[i]));
end
endgenerate

// Instantiate a delay control block for each bank
(* IODELAY_GROUP = "DLYGRP_0" *)
IDELAYCTRL idelayControl0 (
    .REFCLK(refClk200),
    .RST(sysIdelayControlReset),
    .RDY());
(* IODELAY_GROUP = "DLYGRP_1" *)
IDELAYCTRL idelayControl1 (
    .REFCLK(refClk200),
    .RST(sysIdelayControlReset),
    .RDY());
(* IODELAY_GROUP = "DLYGRP_2" *)
IDELAYCTRL idelayControl2 (
    .REFCLK(refClk200),
    .RST(sysIdelayControlReset),
    .RDY());

assign GPIO_IN[GPIO_IDX_FMC1_FIREFLY] = {1'b1,
                                         {32-1-CFG_EVIO_FIREFLY_COUNT{1'b0}},
                                         {CFG_EVIO_FIREFLY_COUNT{1'b1}}};

`else
///////////////////////////////////////////////////////////////////////////////
// IIC to FMC1 components
(*MARK_DEBUG="false"*) wire evio_iic_scl_i, evio_iic_scl_t;
(*MARK_DEBUG="false"*) wire evio_iic_sda_i, evio_iic_sda_t;
(*MARK_DEBUG="false"*) wire [EVIO_FIREFLY_SELECT_WIDTH:0] evio_iic_gpo;

IOBUF FMC1_SCL_IOBUF (.I(1'b0),
                      .IO(FMC1_EVIO_SCL),
                      .O(evio_iic_scl_i),
                      .T(evio_iic_scl_t));
IOBUF FMC1_SDA_IOBUF (.I(1'b0),
                      .IO(FMC1_EVIO_SDA),
                      .O(evio_iic_sda_i),
                      .T(evio_iic_sda_t));

assign FMC1_fireflySelect_n = ~evio_iic_gpo[1+:EVIO_FIREFLY_SELECT_WIDTH];

assign GPIO_IN[GPIO_IDX_FMC1_FIREFLY] = {{32-CFG_EVIO_FIREFLY_COUNT{1'b0}},
                                         FMC1_fireflyPresent_n };

// IIC to FMC2 components
(*MARK_DEBUG="false"*) wire fmc2_iic_scl_i, fmc2_iic_scl_t;
(*MARK_DEBUG="false"*) wire fmc2_iic_sda_i, fmc2_iic_sda_t;

IOBUF FMC2_SCL_IOBUF (.I(1'b0),
                      .IO(UTIO_SCL),
                      .O(fmc2_iic_scl_i),
                      .T(fmc2_iic_scl_t));
IOBUF FMC2_SDA_IOBUF (.I(1'b0),
                      .IO(UTIO_SDA),
                      .O(fmc2_iic_sda_i),
                      .T(fmc2_iic_sda_t));

///////////////////////////////////////////////////////////////////////////////
// Output driver bit clock generation
outputDriverMMCM outputDriverMMCM (
    .clk_in1(evrClk),
    .reset(sysReset),
    .clk_out2(evrBitClk));

///////////////////////////////////////////////////////////////////////////////
// EVR outputs
// FIXME: UTIO for now -- EVRIO someday
wire [CFG_EVR_OUTPUT_COUNT-1:0] utioPatternP, utioPatternN;
reg [CFG_EVR_OUTPUT_COUNT-1:0] outputSelect;
always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_EVR_SELECT_OUTPUT]) begin
        outputSelect <= GPIO_OUT[CFG_EVR_OUTPUT_COUNT-1:0];
    end
end
genvar o;
generate
for (o = 0 ; o < CFG_EVR_OUTPUT_COUNT ; o = o + 1) begin
  wire csrStrobe = GPIO_STROBES[GPIO_IDX_EVR_CONFIG_OUTPUT] & outputSelect[o];
  wire [CFG_EVR_OUTPUT_SERDES_WIDTH-1:0] serdesPattern;
  outputDriver #(.SERDES_WIDTH(CFG_EVR_OUTPUT_SERDES_WIDTH),
                 .COARSE_DELAY_WIDTH(CFG_EVR_DELAY_WIDTH),
                 .COARSE_WIDTH_WIDTH(CFG_EVR_WIDTH_WIDTH),
                 .PATTERN_ADDRESS_WIDTH(CFG_EVR_OUTPUT_PATTERN_ADDR_WIDTH),
                 .DEBUG("false"))
  outputDriver (
    .sysClk(sysClk),
    .sysCsrStrobe(csrStrobe),
    .sysGPIO_OUT(GPIO_OUT),
    .evrClk(evrClk),
    .triggerStrobe(evrTriggerBus[o]),
    .serdesPattern(serdesPattern));

  outputDriverSelectIO outputSERDES (
    .data_out_from_device(serdesPattern),
    .data_out_to_pins_p(utioPatternP[o]),
    .data_out_to_pins_n(utioPatternN[o]),
    .clk_in(evrBitClk),
    .clk_div_in(evrClk),
    .io_reset(sysReset));
end
for (o = 0 ; o < CFG_EVR_OUTPUT_COUNT - 1 ; o = o + 1) begin
    assign UTIO_PATTERN_P[o] = utioPatternP[o];
    assign UTIO_PATTERN_N[o] = utioPatternN[o];
end
endgenerate
assign UTIO_TRIGGER_P = utioPatternP[CFG_EVR_OUTPUT_COUNT-1];
assign UTIO_TRIGGER_N = utioPatternN[CFG_EVR_OUTPUT_COUNT-1];
OBUFDS utioPllRefOBUFDS (.I(evrClk), .O(UTIO_PLL_REF_P), .OB(UTIO_PLL_REF_N));
assign UTIO_EVR_HB = evrPPSmarker;

// Steal a bit from the output selection bitmap for use as PLL reset
reg utioPLLreset = 1'b0;
always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_EVR_SELECT_OUTPUT]) begin
        utioPLLreset <= GPIO_OUT[31];
    end
end
assign UTIO_PLL_RESET_N = ~utioPLLreset;
assign GPIO_IN[GPIO_IDX_EVR_SELECT_OUTPUT] = { utioPLLreset, 5'b0,
                                               UTIO_5V2_PG, UTIO_5V1_PG, 24'b0};

//////////////////////////////////////////////////////////////////////////////
// This firmware is used for EVIO card validation.
//    All EVIO hardware inputs readable by CPU.
//    Diagnostic outputs driven by first CFG_EVIO_DIAG_OUT_COUNT trigger inputs.
assign GPIO_IN[GPIO_IDX_EVIO_HW_IN] = { {32-1-CFG_EVIO_DIAG_IN_COUNT-
                                       CFG_EVIO_HARDWARE_TRIGGER_COUNT{1'b0}},
                                        !FMC1_auxInput,
                                        FMC1_diagnosticIn,
                                        FMC1_hwTrigger };
for (i = 0 ; i < CFG_EVIO_DIAG_OUT_COUNT ; i = i + 1) begin : diag_out
    assign FMC1_diagnosticOut[i] = FMC1_hwTrigger[i];
end
`endif

/////////////////////////////////////////////////////////////////////////////
// Measure fan speeds
fanTach #(.CLK_FREQUENCY(SYSCLK_FREQUENCY),
          .FAN_COUNT(CFG_FAN_COUNT))
  fanTachs (
    .clk(sysClk),
    .csrStrobe(GPIO_STROBES[GPIO_IDX_FAN_TACHOMETERS]),
    .GPIO_OUT(GPIO_OUT),
    .value(GPIO_IN[GPIO_IDX_FAN_TACHOMETERS]),
    .tachs_a({FMC1_FAN2_TACH, FMC1_FAN1_TACH}));

// Make this a black box for simulation
`ifndef SIMULATE
///////////////////////////////////////////////////////////////////////////////
// Block design
bd bd_i (
    .clkSrc125_clk_p(DDR_REF_CLK_P),
    .clkSrc125_clk_n(DDR_REF_CLK_N),
    .ext_reset_in_n(1'b1),

    .sysClk(sysClk),
    .sysReset(sysReset),
    .refClk125(refClk125),
    .refClk125d90(refClk125d90),
    .refClk200(refClk200),

    .GPIO_IN(GPIO_IN_FLATTENED),
    .GPIO_OUT(GPIO_OUT),
    .GPIO_STROBES(GPIO_STROBES),

    .iic_proc_gpio_tri_i(iic_proc_i),
    .iic_proc_gpio_tri_o(iic_proc_o),
    .iic_proc_gpio_tri_t(),

    .evio_iic_scl_i(evio_iic_scl_i),
    .evio_iic_scl_o(),
    .evio_iic_scl_t(evio_iic_scl_t),
    .evio_iic_sda_i(evio_iic_sda_i),
    .evio_iic_sda_o(),
    .evio_iic_sda_t(evio_iic_sda_t),
    .evio_iic_gpo(evio_iic_gpo),

    .fmc2_iic_scl_i(fmc2_iic_scl_i),
    .fmc2_iic_scl_o(),
    .fmc2_iic_scl_t(fmc2_iic_scl_t),
    .fmc2_iic_sda_i(fmc2_iic_sda_i),
    .fmc2_iic_sda_o(),
    .fmc2_iic_sda_t(fmc2_iic_sda_t),

    // Yes, these assignments look reversed.  See comment on port declarations.
    .console_rxd(FPGA_TxD),
    .console_txd(FPGA_RxD));
`endif // `ifndef SIMULATE

endmodule
