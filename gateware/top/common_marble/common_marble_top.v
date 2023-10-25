/*
 * Event fanout/receiver top level module
 */
module common_marble_top #(
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
    output MGT_TX_2_P, MGT_TX_2_N,
    input  MGT_RX_2_P, MGT_RX_2_N,

`ifdef QSFP_FANOUT
    // Additional MGT used for fanout via QSFP
    output MGT_TX_1_P, MGT_TX_1_N,
    input  MGT_RX_1_P, MGT_RX_1_N,
    output MGT_TX_3_P, MGT_TX_3_N,
    input  MGT_RX_3_P, MGT_RX_3_N,
    output MGT_TX_4_P, MGT_TX_4_N,
    input  MGT_RX_4_P, MGT_RX_4_N,
`endif

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
    input          EVRIO_PLL_OUT_P,  // Not used
    input          EVRIO_PLL_OUT_N,  // Not used
    output         EVRIO_PLL_REF_P,
    output         EVRIO_PLL_REF_N,
    output   [3:0] EVRIO_PATTERN_P,
    output   [3:0] EVRIO_PATTERN_N,
    output   [7:0] EVRIO_TRIGGER,
    output         EVRIO_PLL_RESET_N,
    output         EVRIO_PWR_EN,
    input          EVRIO_5V1_PG,
    input          EVRIO_4V5_PG,
    inout          EVRIO_SCL,
    inout          EVRIO_SDA,
    output         EVRIO_VCXO_EN,
`endif

    // SPI between FPGA and microcontroller
    input  FPGA_SCLK,
    input  FPGA_CSB,
    input  FPGA_MOSI,
    output FPGA_MISO,

    // FIXME: Test points (maybe kicker pretrigger someday?)
    output PMOD1_0,
    output PMOD1_1,
    output PMOD1_2,
    output PMOD1_3,
    output PMOD1_4,
    output PMOD1_5,
    input  PMOD1_6,
    input  PMOD1_7,

    // Front panel display and switches
    output PMOD2_0, // Case select
    inout  PMOD2_1, // SDA (Bidirectional data transfer)
    output PMOD2_2, // Enable display backlight driver
    output PMOD2_3, // SCLK
    output PMOD2_4, // RESET
    output PMOD2_5, // D/C
    input  PMOD2_6, // Reset button
    input  PMOD2_7, // Display button

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
assign PMOD1_0 = 1'b0;
assign PMOD1_1 = 1'b0;
assign PMOD1_2 = 1'b0;
assign PMOD1_3 = 1'b0;
assign PMOD1_4 = 1'b0;
assign PMOD1_5 = 1'b0;
assign EVRIO_PWR_EN = 1'b1;
assign EVRIO_VCXO_EN = 1'b0;

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
    .displaySwitch_n(PMOD2_7),
    .resetSwitch_n(PMOD2_6));

/////////////////////////////////////////////////////////////////////////////
// Display
    wire DISPLAY_SPI_SDA_O, DISPLAY_SPI_SDA_T, DISPLAY_SPI_SDA_I;
    IOBUF DISPLAY_MOSI_Buf(.IO(PMOD2_1),
                            .I(DISPLAY_SPI_SDA_O),
                            .T(DISPLAY_SPI_SDA_T),
                            .O(DISPLAY_SPI_SDA_I));
    st7789v #(.CLK_RATE(SYSCLK_FREQUENCY),
                .COMMAND_QUEUE_ADDRESS_WIDTH(11),
                .DEBUG("false"))

        st7789v (.clk(sysClk),
            .csrStrobe(GPIO_STROBES[GPIO_IDX_DISPLAY_CSR]),
            .dataStrobe(GPIO_STROBES[GPIO_IDX_DISPLAY_DATA]),
            .gpioOut(GPIO_OUT),
            .status(GPIO_IN[GPIO_IDX_DISPLAY_CSR]),
            .readData(GPIO_IN[GPIO_IDX_DISPLAY_DATA]),
            .DISPLAY_BACKLIGHT_ENABLE(PMOD2_2),
            .DISPLAY_RESET_N(PMOD2_4),
            .DISPLAY_CMD_N(PMOD2_5),
            .DISPLAY_CLK(PMOD2_3),
            .DISPLAY_CS_N(PMOD2_0),
            .DISPLAY_SDA_O(DISPLAY_SPI_SDA_O),
            .DISPLAY_SDA_T(DISPLAY_SPI_SDA_T),
            .DISPLAY_SDA_I(DISPLAY_SPI_SDA_I));

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
wire [15:0] rxCode;
wire [7:0] evrDistributedBus;
wire       evrPPSmarker;
wire [CFG_EVR_OUTPUT_COUNT-1:0] evrTriggerBus;
wire [7:0] evrCode;
wire       evrCodeValid, evrAligned;
wire [1:0] evrCharIsK;
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
    .evrClk(evrClk),
    .evrCode(evrCode),
    .rawRxCode(rxCode),
    .evrCodeValid(evrCodeValid),
    .evrCharIsK(evrCharIsK),
    .evrTriggerBus(evrTriggerBus),
    .evrDistributedBus(evrDistributedBus),
    .evrPPSmarker(evrPPSmarker),
    .mgtAligned(evrAligned),
    .mgtRefClk(mgtRefClk),
    .MGT_TX_P(MGT_TX_2_P),
    .MGT_TX_N(MGT_TX_2_N),
    .MGT_RX_P(MGT_RX_2_P),
    .MGT_RX_N(MGT_RX_2_N));

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

`ifdef QSFP_FANOUT
/////////////////////////////////////////////////////////////////////////////
// Event Fanout
assign GPIO_IN[GPIO_IDX_MGT_HW_CONFIG] = 1; //{{31{1'b0}},1'b1};
wire evfClk;
// I/O MGT Pins
wire [2:0] rxPpins = {MGT_RX_1_P, MGT_RX_3_P, MGT_RX_4_P};
wire [2:0] rxNpins = {MGT_RX_1_N, MGT_RX_3_N, MGT_RX_4_N};
wire [2:0] txPpins;
assign {MGT_TX_1_P, MGT_TX_3_P, MGT_TX_4_P} = txPpins;
wire [2:0] txNpins;
assign {MGT_TX_1_N, MGT_TX_3_N, MGT_TX_4_N} = txNpins;
// Data & Clocks
wire [15:0] txCode;
wire [2:0] evfTxInClks, evfTxOutClks, evfRxInClks, evfRxOutClks, evfReady;
wire [1:0] evfCharIsK;
assign evfClk = evfTxOutClks[0];
assign evfTxInClks = {CFG_NUM_GTX_QSFP_FANOUT{evfClk}}; // loopback TXOUTCLK

generate
for (i = 0 ; i < CFG_NUM_GTX_QSFP_FANOUT; i = i + 1) begin
localparam integer rOff = i * GPIO_IDX_PER_MGTWRAPPER;
evfMgtWrapper #(
    .DEBUG("false"))
    evfmgt(
        .sysClk(sysClk) ,
        .sysGPIO_OUT(GPIO_OUT),
        .drpStrobe(GPIO_STROBES[GPIO_IDX_EVF_MGT_DRP_CSR+rOff]),
        .drpStatus(GPIO_IN[GPIO_IDX_EVF_MGT_DRP_CSR+rOff]),
        .mgtReady(evfReady[i]),
        .refClk(mgtRefClk),
        .txInClk(evfTxInClks[i]),
        .txOutClk(evfTxOutClks[i]),
        .rxInClk(evfRxInClks[i]),
        .rxOutClk(evfRxOutClks[i]),
        .txCode(txCode),
        .dataIsK(evfCharIsK),
        .MGT_TX_P(txPpins[i]),
        .MGT_TX_N(txNpins[i]),
        .MGT_RX_P(rxPpins[i]),
        .MGT_RX_N(rxNpins[i]));
end
endgenerate

// FIFO Control signals
wire [8:0] fifo_wr_count, fifo_rd_count;
wire fifo_we, fifo_re, fifo_full, fifo_empty;
assign fifo_we = evrAligned & ~fifo_full;
assign fifo_re = evfReady=={CFG_NUM_GTX_QSFP_FANOUT{1'b1}} & ~fifo_empty;

fifo_2c #(.dw(18))
    EVFdataFifo (
    .wr_clk(evrClk),
    .we(fifo_we),
    .din({evrCharIsK, rxCode}),
    .wr_count(fifo_wr_count),
    .full(fifo_full),
    .rd_clk(evfClk),
    .re(fifo_re),
    .dout({evfCharIsK, txCode}),
    .rd_count(fifo_rd_count),
    .empty(fifo_empty));
`else
    assign GPIO_IN[GPIO_IDX_MGT_HW_CONFIG] = 0;
`endif
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
                      .IO(EVRIO_SCL),
                      .O(fmc2_iic_scl_i),
                      .T(fmc2_iic_scl_t));
IOBUF FMC2_SDA_IOBUF (.I(1'b0),
                      .IO(EVRIO_SDA),
                      .O(fmc2_iic_sda_i),
                      .T(fmc2_iic_sda_t));

///////////////////////////////////////////////////////////////////////////////
// CDC for evr reset signal
reg evrioReset_m0 = 0, evrioReset_m2 = 0;
(*ASYNC_REG="true"*) reg evrioReset_m1 = 0;
wire evrioReset;
always @(posedge sysClk) begin
    evrioReset_m0 <= sysReset | evrioPLLreset;
end
always @(posedge evrClk) begin
    evrioReset_m1 <= evrioReset_m0;
    evrioReset_m2 <= evrioReset_m1;
end
assign evrioReset = evrioReset_m2 | ~evrAligned;

///////////////////////////////////////////////////////////////////////////////
// Output driver bit clock generation
wire evrClkInterface;
outputDriverMMCM outputDriverMMCM (
    .clk_in1(evrClk),
    .reset(evrioReset),
    .clk_out1(evrClkInterface),
    .clk_out2(evrBitClk));

///////////////////////////////////////////////////////////////////////////////
// EVR outputs
// FIXME: UTIO for now -- EVRIO someday
wire [CFG_EVR_OUTPUT_COUNT-1:0] evrioOutputP, evrioOutputN;
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

    if(o < CFG_EVR_OUTPUT_PATTERN_COUNT) begin
        outputSerdesIO #(.DIFFERENTIAL_OUPUT("true")) // Pattern output are differential
        outputSERDESdiff_inst (
            .data_in(serdesPattern),
            .data_out0(evrioOutputP[o]),
            .data_out1(evrioOutputN[o]),
            .clk_in(evrBitClk),
            .clk_div_in(evrClkInterface),
            .clock_en(1'b1),
            .reset(evrioReset));
    end else begin
        outputSerdesIO #(.DIFFERENTIAL_OUPUT("false")) // Trigger output are signle-ended
        outputSERDESse_inst (
            .data_in(serdesPattern),
            .data_out0(evrioOutputP[o]),
            .data_out1(),
            .clk_in(evrBitClk),
            .clk_div_in(evrClkInterface),
            .clock_en(1'b1),
            .reset(evrioReset));
    end
end
for (o = 0 ; o < CFG_EVR_OUTPUT_COUNT ; o = o + 1) begin
    if(o < CFG_EVR_OUTPUT_PATTERN_COUNT) begin
        assign EVRIO_PATTERN_P[o] = evrioOutputP[o];
        assign EVRIO_PATTERN_N[o] = evrioOutputN[o];
    end else begin
        assign EVRIO_TRIGGER[o-CFG_EVR_OUTPUT_PATTERN_COUNT] = evrioOutputP[o];
    end
end
endgenerate
OBUFDS evrioPllRefOBUFDS (.I(evrClk), .O(EVRIO_PLL_REF_P), .OB(EVRIO_PLL_REF_N));

// Steal a bit from the output selection bitmap for use as PLL reset
reg evrioPLLreset = 1'b0;
always @(posedge sysClk) begin
    if (GPIO_STROBES[GPIO_IDX_EVR_SELECT_OUTPUT]) begin
        evrioPLLreset <= GPIO_OUT[31];
    end
end
assign EVRIO_PLL_RESET_N = ~evrioPLLreset;
assign GPIO_IN[GPIO_IDX_EVR_SELECT_OUTPUT] = { evrioPLLreset, 5'b0,
                                               EVRIO_4V5_PG, EVRIO_5V1_PG, 24'b0};

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
