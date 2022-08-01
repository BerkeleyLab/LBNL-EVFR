// Wrap MGT and small EVR

module evr #(
    parameter EVR_CLOCK_RATE = 125000000,
    parameter OUTPUT_COUNT   = 8,
    parameter DEBUG          = "false"
    ) (
    input         sysClk,
    input  [31:0] sysGPIO_OUT,
    input         sysActionStrobe,
    input         drpStrobe,
    output [31:0] drpStatus,
    output [31:0] mgtRxStatus,
    output [31:0] status,
    output [31:0] monitorSeconds,
    output [31:0] monitorTicks,
    output [31:0] todSeconds,
    input         refClk,

    output wire                    evrClk,
    output reg               [7:0] evrCode = 0,
    output reg                     evrCodeValid = 0,
    output wire [OUTPUT_COUNT-1:0] evrTriggerBus,
    output wire              [7:0] evrDistributedBus,
    output wire                    evrPPSmarker,

    input   mgtRefClk,
    input   MGT_RX_P,
    input   MGT_RX_N,
    output  MGT_TX_P,
    output  MGT_TX_N);

(*mark_debug=DEBUG*) wire [15:0] rxData;
(*mark_debug=DEBUG*) wire [1:0] rxIsK, rxNotInTable;

//////////////////////////////////////////////////////////////////////////////
// Receiver alignment detection
localparam COMMAS_NEEDED = 60;
localparam COMMA_COUNTER_RELOAD = COMMAS_NEEDED - 1;
localparam COMMA_COUNTER_WIDTH = $clog2(COMMA_COUNTER_RELOAD+1) + 1;
(*mark_debug=DEBUG*) reg [COMMA_COUNTER_WIDTH-1:0] commaCounter =
                                                           COMMA_COUNTER_RELOAD;
assign rxIsAligned = commaCounter[COMMA_COUNTER_WIDTH-1];
wire sysSlideRequest;
(*ASYNC_REG="true"*) reg slideRequest_m = 0;
reg slideRequest_d0 = 0, slideRequest_d1 = 0;
(*mark_debug=DEBUG*) reg bitSlide = 0;
always @(posedge evrClk) begin
    slideRequest_m  <= sysSlideRequest;
    slideRequest_d0 <= slideRequest_m;
    slideRequest_d1 <= slideRequest_d0;
    bitSlide <= slideRequest_d0 && !slideRequest_d1;
    if ((rxNotInTable != 0) || rxIsK[1]) begin
        commaCounter <= COMMA_COUNTER_RELOAD;
    end
    else if (!rxIsAligned && rxIsK[0] && (rxData[7:0] == 8'hBC)) begin
        commaCounter <= commaCounter - 1;
    end
end

//////////////////////////////////////////////////////////////////////////////
// Pass event codes out
wire goodCode = (rxIsAligned && (rxData[7:0] != 0) && !rxIsK[0]);
reg   [7:0] evrCode_d;
wire [63:0] evrTimestamp;
reg  [63:0] evrTimestamp_d;
always @(posedge evrClk) begin
    evrCode <= goodCode ? rxData[7:0] : 8'h00;
    evrCodeValid <= goodCode;
    evrCode_d <= evrCode;
    evrTimestamp_d <= evrTimestamp;
end

//////////////////////////////////////////////////////////////////////////////
// Monitor selected events
wire        evrMonitorFlag;
wire        evrMonitorFIFOfull;
wire [71:0] monitorFIFOout;
wire        monitorFIFOempty;
reg         monitorFIFOreset = 1;

always @(posedge sysClk) begin
    if (sysActionStrobe && sysGPIO_OUT[31] && sysGPIO_OUT[29]) begin
        monitorFIFOreset <= sysGPIO_OUT[28];
    end
end

`ifndef SIMULATE
eventMonitorFIFO eventMonitorFIFO (
    .rst(monitorFIFOreset),
    .wr_clk(evrClk),
    .din({evrTimestamp_d, evrCode_d}),
    .wr_en(evrMonitorFlag && !evrMonitorFIFOfull),
    .full(evrMonitorFIFOfull),
    .rd_clk(sysClk),
    .rd_en(sysActionStrobe && sysGPIO_OUT[31] && sysGPIO_OUT[30]),
    .dout(monitorFIFOout),
    .empty(monitorFIFOempty));
`endif

wire [7:0] monitorCode    = monitorFIFOout[0+:8];
assign     monitorTicks   = monitorFIFOout[8+:32];
assign     monitorSeconds = monitorFIFOout[40+:32];

//////////////////////////////////////////////////////////////////////////////
// Small EVR
(*MARK_DEBUG=DEBUG*) wire evrPPS;
smallEVR #(.ACTION_WIDTH(1+OUTPUT_COUNT),
           .DEBUG(DEBUG))
  smallEVR (
    .evrRxClk(evrClk),
    .evrRxWord(rxData),
    .evrCharIsK(rxIsK),
    .ppsMarker(evrPPS),
    .timestampValid(evrTimestampValid),
    .timestamp(evrTimestamp),
    .distributedDataBus(evrDistributedBus),
    .action({evrMonitorFlag, evrTriggerBus}),
    .sysClk(sysClk),
    .sysActionWriteEnable(sysActionStrobe && !sysGPIO_OUT[31]),
    .sysActionAddress(sysGPIO_OUT[7:0]),
    .sysActionData(sysGPIO_OUT[8+:1+OUTPUT_COUNT]));

//////////////////////////////////////////////////////////////////////////////
// Stretch heartbeat event to visible range
localparam HB_STRETCH_RELOAD = (EVR_CLOCK_RATE / 3) - 2;
localparam HB_STRETCH_WIDTH = $clog2(HB_STRETCH_RELOAD+1)+1;
reg [HB_STRETCH_WIDTH-1:0] evrHBstretch = -HB_STRETCH_RELOAD;
wire evrHBmarker = evrHBstretch[HB_STRETCH_WIDTH-1];
(*ASYNC_REG="true"*) reg hbMarker_m;
reg hbMarker;
always @(posedge evrClk) begin
    if ((rxData[7:0] == 8'd122) && !rxIsK[0]) begin
        evrHBstretch <= -HB_STRETCH_RELOAD;
    end
    else if (evrHBmarker) begin
        evrHBstretch <= evrHBstretch + 1;
    end
end
always @(posedge sysClk) begin
    hbMarker_m <= evrHBmarker;
    hbMarker   <= hbMarker_m;
end

assign status = { 1'b0, monitorFIFOempty, 6'b0, monitorCode,
                  14'b0, hbMarker, evrTimestampValid };

// Forward time-of-day seconds to system clock domain
forwardData #(.DATA_WIDTH(32))
  forwardSeconds (
    .inClk(evrClk),
    .inData(evrTimestamp[63:32]),
    .outClk(sysClk),
    .outData(todSeconds));

//////////////////////////////////////////////////////////////////////////////
// Stretch PPS event to marker easily seen in all clock domains
localparam PPS_STRETCH_RELOAD = (EVR_CLOCK_RATE / 2000000) - 2;
localparam PPS_STRETCH_WIDTH = $clog2(PPS_STRETCH_RELOAD+1)+1;
reg [PPS_STRETCH_WIDTH-1:0] evrPPSstretch = -PPS_STRETCH_RELOAD;
assign evrPPSmarker = evrPPSstretch[PPS_STRETCH_WIDTH-1];
always @(posedge evrClk) begin
    if (evrPPS) begin
        evrPPSstretch <= -PPS_STRETCH_RELOAD;
    end
    else if (evrPPSmarker) begin
        evrPPSstretch <= evrPPSstretch + 1;
    end
end

//////////////////////////////////////////////////////////////////////////////
// MGT dynamic reconfiguration port control/status
localparam DRP_DATA_WIDTH          = 16;
localparam DRP_ADDR_WIDTH          = 9;
localparam DRP_RESET_CONTROL_WIDTH = 6;
localparam DRP_RESET_STATUS_WIDTH  = 6;
wire                               drp_en, drp_we, drp_rdy;
wire          [DRP_ADDR_WIDTH-1:0] drp_addr;
wire          [DRP_DATA_WIDTH-1:0] drp_di, drp_do;
(*mark_debug=DEBUG*) wire [DRP_RESET_CONTROL_WIDTH-1:0] mgtControl;
(*mark_debug=DEBUG*) wire  [DRP_RESET_STATUS_WIDTH-1:0] mgtStatus;
assign sysSlideRequest = mgtControl[5];
assign mgtStatus[5] = rxIsAligned;
drpControl #(
    .DRP_DATA_WIDTH(DRP_DATA_WIDTH),
    .DRP_ADDR_WIDTH(DRP_ADDR_WIDTH),
    .RESET_CONTROL_WIDTH(DRP_RESET_CONTROL_WIDTH),
    .RESET_STATUS_WIDTH(DRP_RESET_STATUS_WIDTH))
  drpControl (
    .clk(sysClk),
    .strobe(drpStrobe),
    .dataIn(sysGPIO_OUT),
    .dataOut(drpStatus),
    .resetControl(mgtControl),
    .resetStatus(mgtStatus),
    .drp_en(drp_en),
    .drp_we(drp_we),
    .drp_rdy(drp_rdy),
    .drp_addr(drp_addr),
    .drp_di(drp_di),
    .drp_do(drp_do));

/////////////////////////////////////////////////////////////////////
// MGT (GTX)

wire rxoutclk;
BUFG evrClkBUFG (.I(rxoutclk), .O(evrClk));
wire txoutclk, evrTxClk;
BUFG evrTxClkBUFG (.I(txoutclk), .O(evrTxClk));

wire [4:0] rxPhaseMonitor, rxSlipMonitor;
assign mgtRxStatus = { 22'b0, rxSlipMonitor, rxPhaseMonitor };

localparam LOOPBACK = 3'd4; // 4 == Far end PMA loopback

evrmgt evrmgt_i (
    .sysclk_in(sysClk), // input wire sysclk_in
    .soft_reset_tx_in(mgtControl[0]), // input wire soft_reset_tx_in
    .soft_reset_rx_in(mgtControl[0]), // input wire soft_reset_rx_in
    .dont_reset_on_data_error_in(1'b1), // input wire dont_reset_on_data_error_in
    .gt0_tx_fsm_reset_done_out(mgtStatus[0]), // output wire gt0_tx_fsm_reset_done_out
    .gt0_rx_fsm_reset_done_out(mgtStatus[1]), // output wire gt0_rx_fsm_reset_done_out
    .gt0_data_valid_in(1'b1), // input wire gt0_data_valid_in

    //_________________________________________________________________________
    //GT0  (X0Y0)
    //____________________________CHANNEL PORTS________________________________
    //------------------------------- CPLL Ports -------------------------------
    .gt0_cpllfbclklost_out   (mgtStatus[2]), // output wire gt0_cpllfbclklost_out
    .gt0_cplllock_out        (mgtStatus[3]), // output wire gt0_cplllock_out
    .gt0_cplllockdetclk_in   (sysClk), // input wire gt0_cplllockdetclk_in
    .gt0_cpllreset_in        (mgtControl[1]), // input wire gt0_cpllreset_in
    //------------------------ Channel - Clocking Ports ------------------------
    .gt0_gtrefclk0_in        (mgtRefClk), // input wire gt0_gtrefclk0_in
    .gt0_gtrefclk1_in        (1'b0), // input wire gt0_gtrefclk1_in
    //-------------------------- Channel - DRP Ports  --------------------------
    //-------------------------- Channel - DRP Ports  --------------------------
    .gt0_drpaddr_in          (drp_addr), // input wire [8:0] gt0_drpaddr_in
    .gt0_drpclk_in           (sysClk), // input wire gt0_drpclk_in
    .gt0_drpdi_in            (drp_di), // input wire [15:0] gt0_drpdi_in
    .gt0_drpdo_out           (drp_do), // output wire [15:0] gt0_drpdo_out
    .gt0_drpen_in            (drp_en), // input wire gt0_drpen_in
    .gt0_drprdy_out          (drp_rdy), // output wire gt0_drprdy_out
    .gt0_drpwe_in            (drp_we), // input wire gt0_drpwe_in
    //------------------------- Digital Monitor Ports --------------------------
    .gt0_dmonitorout_out     (), // output wire [7:0] gt0_dmonitorout_out
    //----------------------------- Loopback Ports -----------------------------
    .gt0_loopback_in         (LOOPBACK), // input wire [2:0] gt0_loopback_in
    //------------------- RX Initialization and Reset Ports --------------------
    .gt0_eyescanreset_in     (1'b0), // input wire gt0_eyescanreset_in
    .gt0_rxuserrdy_in        (1'b1), // input wire gt0_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt0_eyescandataerror_out(), // output wire gt0_eyescandataerror_out
    .gt0_eyescantrigger_in   (1'b0), // input wire gt0_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt0_rxusrclk_in         (evrClk), // input wire gt0_rxusrclk_in
    .gt0_rxusrclk2_in        (evrClk), // input wire gt0_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt0_rxdata_out          (rxData), // output wire [15:0] gt0_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt0_rxdisperr_out       (), // output wire [1:0] gt0_rxdisperr_out
    .gt0_rxnotintable_out    (rxNotInTable), // output wire [1:0] gt0_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt0_gtxrxp_in           (MGT_RX_P), // input wire gt0_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt0_gtxrxn_in           (MGT_RX_N), // input wire gt0_gtxrxn_in
    //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
    .gt0_rxphmonitor_out     (rxPhaseMonitor), // output wire [4:0] gt0_rxphmonitor_out
    .gt0_rxphslipmonitor_out (rxSlipMonitor), // output wire [4:0] gt0_rxphslipmonitor_out
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt0_rxdfelpmreset_in    (1'b0), // input wire gt0_rxdfelpmreset_in
    .gt0_rxmonitorout_out    (), // output wire [6:0] gt0_rxmonitorout_out
    .gt0_rxmonitorsel_in     (2'b01), // input wire [1:0] gt0_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------

    .gt0_rxoutclk_out        (rxoutclk), // output wire gt0_rxoutclk_out
    .gt0_rxoutclkfabric_out  (), // output wire gt0_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt0_gtrxreset_in        (mgtControl[2]), // input wire gt0_gtrxreset_in
    .gt0_rxpmareset_in       (mgtControl[3]), // input wire gt0_rxpmareset_in
    //-------------------- Receive Ports - RX gearbox ports --------------------
    .gt0_rxslide_in          (bitSlide), // input wire gt0_rxslide_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt0_rxcharisk_out       (rxIsK), // output wire [1:0] gt0_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt0_rxresetdone_out     (mgtStatus[4]), // output wire gt0_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt0_gttxreset_in        (mgtControl[4]), // input wire gt0_gttxreset_in
    .gt0_txuserrdy_in        (1'b1), // input wire gt0_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt0_txusrclk_in         (evrTxClk), // input wire gt0_txusrclk_in
    .gt0_txusrclk2_in        (evrTxClk), // input wire gt0_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt0_txdata_in           (16'h0), // input wire [15:0] gt0_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt0_gtxtxn_out          (MGT_TX_N), // output wire gt0_gtxtxn_out
    .gt0_gtxtxp_out          (MGT_TX_P), // output wire gt0_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt0_txoutclk_out        (txoutclk), // output wire gt0_txoutclk_out
    .gt0_txoutclkfabric_out  (), // output wire gt0_txoutclkfabric_out
    .gt0_txoutclkpcs_out     (), // output wire gt0_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt0_txcharisk_in        (2'h0), // input wire [1:0] gt0_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt0_txresetdone_out     (), // output wire gt0_txresetdone_out

    //____________________________COMMON PORTS________________________________
    .gt0_qplloutclk_in(1'b0), // input wire gt0_qplloutclk_in
    .gt0_qplloutrefclk_in(1'b0) // input wire gt0_qplloutrefclk_in
);

///////////////////////////////////////////////////////////////////////////////
// Xilinx Answer Record 43339
// Instantiate a GTXE2_COMMON even though QPLL is unused.
// Needed to set BIAS_CFG properly.

localparam WRAPPER_SIM_GTRESET_SPEEDUP ="false";
localparam SIM_VERSION = "4.0";
localparam QPLL_FBDIV_IN = 10'b0000100000;
localparam QPLL_FBDIV_RATIO = 1'b1;

wire [15:0] tied_to_ground_vec_i = 0;
wire tied_to_ground_i = 0;
wire tied_to_vcc_i = 1;
wire GT0_GTREFCLK0_COMMON_IN = refClk;
wire GT0_QPLLLOCKDETCLK_IN = sysClk;
wire GT0_QPLLRESET_IN = mgtControl[1];
wire GT0_QPLLLOCK_OUT;
wire GT0_QPLLREFCLKLOST_OUT;

// This code copied verbatim from the answer record:

//_________________________________________________________________________
    //_________________________________________________________________________
    //_________________________GTXE2_COMMON____________________________________

    GTXE2_COMMON #
    (
            // Simulation attributes
            .SIM_RESET_SPEEDUP   (WRAPPER_SIM_GTRESET_SPEEDUP),
            .SIM_QPLLREFCLK_SEL  (3'b001),
            .SIM_VERSION         (SIM_VERSION),


           //----------------COMMON BLOCK Attributes---------------
            .BIAS_CFG                               (64'h0000040000001000),
            .COMMON_CFG                             (32'h00000000),
            .QPLL_CFG                               (27'h06801C1),
            .QPLL_CLKOUT_CFG                        (4'b0000),
            .QPLL_COARSE_FREQ_OVRD                  (6'b010000),
            .QPLL_COARSE_FREQ_OVRD_EN               (1'b0),
            .QPLL_CP                                (10'b0000011111),
            .QPLL_CP_MONITOR_EN                     (1'b0),
            .QPLL_DMONITOR_SEL                      (1'b0),
            .QPLL_FBDIV                             (QPLL_FBDIV_IN),
            .QPLL_FBDIV_MONITOR_EN                  (1'b0),
            .QPLL_FBDIV_RATIO                       (QPLL_FBDIV_RATIO),
            .QPLL_INIT_CFG                          (24'h000006),
            .QPLL_LOCK_CFG                          (16'h21E8),
            .QPLL_LPF                               (4'b1111),
            .QPLL_REFCLK_DIV                        (1)

    )
    gtxe2_common_0_i
    (
        //----------- Common Block  - Dynamic Reconfiguration Port (DRP) -----------
        .DRPADDR                        (tied_to_ground_vec_i[7:0]),
        .DRPCLK                         (tied_to_ground_i),
        .DRPDI                          (tied_to_ground_vec_i[15:0]),
        .DRPDO                          (),
        .DRPEN                          (tied_to_ground_i),
        .DRPRDY                         (),
        .DRPWE                          (tied_to_ground_i),
        //-------------------- Common Block  - Ref Clock Ports ---------------------
        .GTGREFCLK                      (tied_to_ground_i),
        .GTNORTHREFCLK0                 (tied_to_ground_i),
        .GTNORTHREFCLK1                 (tied_to_ground_i),
        .GTREFCLK0                      (GT0_GTREFCLK0_COMMON_IN),
        .GTREFCLK1                      (tied_to_ground_i),
        .GTSOUTHREFCLK0                 (tied_to_ground_i),
        .GTSOUTHREFCLK1                 (tied_to_ground_i),
        //----------------------- Common Block - QPLL Ports ------------------------
        .QPLLDMONITOR                   (),
        .QPLLFBCLKLOST                  (),
        .QPLLLOCK                       (GT0_QPLLLOCK_OUT),
        .QPLLLOCKDETCLK                 (GT0_QPLLLOCKDETCLK_IN),
        .QPLLLOCKEN                     (tied_to_vcc_i),
        .QPLLOUTCLK                     (gt0_qplloutclk_i),
        .QPLLOUTREFCLK                  (gt0_qplloutrefclk_i),
        .QPLLOUTRESET                   (tied_to_ground_i),
        .QPLLPD                         (tied_to_ground_i),
        .QPLLREFCLKLOST                 (GT0_QPLLREFCLKLOST_OUT),
        .QPLLREFCLKSEL                  (3'b001),
        .QPLLRESET                      (GT0_QPLLRESET_IN),
        .QPLLRSVD1                      (16'b0000000000000000),
        .QPLLRSVD2                      (5'b11111),
        .REFCLKOUTMONITOR               (),
        //--------------------------- Common Block Ports ---------------------------
        .BGBYPASSB                      (tied_to_vcc_i),
        .BGMONITORENB                   (tied_to_vcc_i),
        .BGPDB                          (tied_to_vcc_i),
        .BGRCALOVRD                     (5'b00000),
        .PMARSVD                        (8'b00000000),
        .RCALENB                        (tied_to_vcc_i)

    );

endmodule
