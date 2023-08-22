// MGT wrapper for EVF

module evfMgtWrapper #(
    parameter DEBUG          = "false"
    ) (
    input           sysClk,
    input   [31:0]  sysGPIO_OUT,
    input           drpStrobe,
    output  [31:0]  drpStatus,
    output reg      mgtReady = 0,
    input           refClk,
    input           txInClk,
    input           rxInClk,
    output          txOutClk,
    output          rxOutClk,
    input   [15:0]  txCode,
    input    [1:0]  dataIsK,
    output          MGT_TX_P, MGT_TX_N,
    input           MGT_RX_P, MGT_RX_N);

//////////////////////////////////////////////////////////////////////////////
// MGT dynamic reconfiguration port control/status
localparam DRP_DATA_WIDTH          = 16;
localparam DRP_ADDR_WIDTH          = 9;
localparam DRP_RESET_CONTROL_WIDTH = 6;
localparam DRP_RESET_STATUS_WIDTH  = 7;
wire                               drp_en, drp_we, drp_rdy;
wire          [DRP_ADDR_WIDTH-1:0] drp_addr;
wire          [DRP_DATA_WIDTH-1:0] drp_di, drp_do;
(*mark_debug=DEBUG*) wire [DRP_RESET_CONTROL_WIDTH-1:0] mgtControl;
(*mark_debug=DEBUG*) wire  [DRP_RESET_STATUS_WIDTH-1:0] mgtStatus;

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
wire rxoutclk, txoutclk;
BUFG evfRxOutBUFG (.I(rxoutclk), .O(rxOutClk));
BUFG evfTxOutBUFG (.I(txoutclk), .O(txOutClk));

/* MGT control signals table
 ___________________________________________________________________
| GPIO INDEX   |  HEX VALUE   | MGT INDEX     | MGT CONNECTIONS     |
|--------------|--------------|---------------|---------------------|
| GPIO_OUT[30] | (0x40000000) | MGTcontrol[5] | sysSlideRequest	    |
| GPIO_OUT[29] | (0x20000000) | MGTcontrol[4] | gttxreset           |
| GPIO_OUT[28] | (0x10000000) | MGTcontrol[3] | rxpmareset          |
| GPIO_OUT[27] | (0x08000000) | MGTcontrol[2] | gtrxreset           |
| GPIO_OUT[26] | (0x04000000) | MGTcontrol[1] | cpllreset 		    |
| GPIO_OUT[25] | (0x02000000) | MGTcontrol[0] | soft reset tx / rx  |
'-------------------------------------------------------------------' */
wire sysSlideRequest, gttxreset, rxpmareset, gtrxreset, cpllreset, softreset;
assign {sysSlideRequest,
        gttxreset,
        rxpmareset,
        gtrxreset,
        cpllreset,
        softreset} = mgtControl;

/* MGT status signals table
___________________________________________________________________
| GPIO INDEX  |  HEX VALUE   | MGT INDEX    | MGT CONNECTIONS      |
|-------------|--------------|--------------|----------------------|
| GPIO_IN[30] | (0x40000000) | mgtStatus[6] | rxIsAligned          |
| GPIO_IN[29] | (0x20000000) | mgtStatus[5] | rxresetdone          |
| GPIO_IN[28] | (0x10000000) | mgtStatus[4] | cplllock             |
| GPIO_IN[27] | (0x08000000) | mgtStatus[3] | cpllfbclklost        |
| GPIO_IN[26] | (0x04000000) | mgtStatus[2] | rx_fsm_reset_done    |
| GPIO_IN[25] | (0x02000000) | mgtStatus[1] | tx_fsm_reset_done    |
| GPIO_IN[24] | (0x01000000) | mgtStatus[0] | txresetdone          |
'------------------------------------------------------------------' */
wire rxIsAligned, txresetdone, rxresetdone, cplllock, cpllfbclklost, rx_fsm_reset_done, tx_fsm_reset_done;
assign mgtStatus = {rxIsAligned,
                    rxresetdone,
                    cplllock,
                    cpllfbclklost,
                    rx_fsm_reset_done,
                    tx_fsm_reset_done,
                    txresetdone};

always @(posedge txInClk) begin
    mgtReady <=  cplllock & txresetdone;
end

evrmgt evrmgt_i (
    .sysclk_in(sysClk), // input wire sysclk_in
    .soft_reset_tx_in(softreset), // input wire soft_reset_tx_in
    .soft_reset_rx_in(softreset), // input wire soft_reset_rx_in
    .dont_reset_on_data_error_in(1'b1), // input wire dont_reset_on_data_error_in
    .gt0_tx_fsm_reset_done_out(tx_fsm_reset_done), // output wire gt0_tx_fsm_reset_done_out
    .gt0_rx_fsm_reset_done_out(rx_fsm_reset_done), // output wire gt0_rx_fsm_reset_done_out
    .gt0_data_valid_in(1'b1), // input wire gt0_data_valid_in

    //_________________________________________________________________________
    //GT0  (X0Y0)
    //____________________________CHANNEL PORTS________________________________
    //------------------------------- CPLL Ports -------------------------------
    .gt0_cpllfbclklost_out   (cpllfbclklost), // output wire gt0_cpllfbclklost_out
    .gt0_cplllock_out        (cplllock), // output wire gt0_cplllock_out
    .gt0_cplllockdetclk_in   (sysClk), // input wire gt0_cplllockdetclk_in
    .gt0_cpllreset_in        (cpllreset), // input wire gt0_cpllreset_in
    //------------------------ Channel - Clocking Ports ------------------------
    .gt0_gtrefclk0_in        (refClk), // input wire gt0_gtrefclk0_in
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
    .gt0_loopback_in         (3'b0), // input wire [2:0] gt0_loopback_in
    //------------------- RX Initialization and Reset Ports --------------------
    .gt0_eyescanreset_in     (1'b0), // input wire gt0_eyescanreset_in
    .gt0_rxuserrdy_in        (1'b1), // input wire gt0_rxuserrdy_in
    //------------------------ RX Margin Analysis Ports ------------------------
    .gt0_eyescandataerror_out(), // output wire gt0_eyescandataerror_out
    .gt0_eyescantrigger_in   (1'b0), // input wire gt0_eyescantrigger_in
    //---------------- Receive Ports - FPGA RX Interface Ports -----------------
    .gt0_rxusrclk_in         (rxOutClk), // input wire gt0_rxusrclk_in
    .gt0_rxusrclk2_in        (rxOutClk), // input wire gt0_rxusrclk2_in
    //---------------- Receive Ports - FPGA RX interface Ports -----------------
    .gt0_rxdata_out          (), // output wire [15:0] gt0_rxdata_out
    //---------------- Receive Ports - RX 8B/10B Decoder Ports -----------------
    .gt0_rxdisperr_out       (), // output wire [1:0] gt0_rxdisperr_out
    .gt0_rxnotintable_out    (), // output wire [1:0] gt0_rxnotintable_out
    //------------------------- Receive Ports - RX AFE -------------------------
    .gt0_gtxrxp_in           (MGT_RX_P), // input wire gt0_gtxrxp_in
    //---------------------- Receive Ports - RX AFE Ports ----------------------
    .gt0_gtxrxn_in           (MGT_RX_N), // input wire gt0_gtxrxn_in
    //----------------- Receive Ports - RX Buffer Bypass Ports -----------------
    .gt0_rxphmonitor_out     (), // output wire [4:0] gt0_rxphmonitor_out
    .gt0_rxphslipmonitor_out (), // output wire [4:0] gt0_rxphslipmonitor_out
    //------------------- Receive Ports - RX Equalizer Ports -------------------
    .gt0_rxdfelpmreset_in    (1'b0), // input wire gt0_rxdfelpmreset_in
    .gt0_rxmonitorout_out    (), // output wire [6:0] gt0_rxmonitorout_out
    .gt0_rxmonitorsel_in     (2'b01), // input wire [1:0] gt0_rxmonitorsel_in
    //------------- Receive Ports - RX Fabric Output Control Ports -------------

    .gt0_rxoutclk_out        (rxoutclk), // output wire gt0_rxoutclk_out
    .gt0_rxoutclkfabric_out  (), // output wire gt0_rxoutclkfabric_out
    //----------- Receive Ports - RX Initialization and Reset Ports ------------
    .gt0_gtrxreset_in        (gtrxreset), // input wire gt0_gtrxreset_in
    .gt0_rxpmareset_in       (), // input wire gt0_rxpmareset_in
    //-------------------- Receive Ports - RX gearbox ports --------------------
    .gt0_rxslide_in          (1'b0), // input wire gt0_rxslide_in
    //----------------- Receive Ports - RX8B/10B Decoder Ports -----------------
    .gt0_rxcharisk_out       (), // output wire [1:0] gt0_rxcharisk_out
    //------------ Receive Ports -RX Initialization and Reset Ports ------------
    .gt0_rxresetdone_out     (rxresetdone), // output wire gt0_rxresetdone_out
    //------------------- TX Initialization and Reset Ports --------------------
    .gt0_gttxreset_in        (gttxreset), // input wire gt0_gttxreset_in
    .gt0_txuserrdy_in        (1'b1), // input wire gt0_txuserrdy_in
    //---------------- Transmit Ports - FPGA TX Interface Ports ----------------
    .gt0_txusrclk_in         (txInClk), // input wire gt0_txusrclk_in
    .gt0_txusrclk2_in        (txInClk), // input wire gt0_txusrclk2_in
    //---------------- Transmit Ports - TX Data Path interface -----------------
    .gt0_txdata_in           (txCode), // input wire [15:0] gt0_txdata_in
    //-------------- Transmit Ports - TX Driver and OOB signaling --------------
    .gt0_gtxtxn_out          (MGT_TX_N), // output wire gt0_gtxtxn_out
    .gt0_gtxtxp_out          (MGT_TX_P), // output wire gt0_gtxtxp_out
    //--------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
    .gt0_txoutclk_out        (txoutclk), // output wire gt0_txoutclk_out
    .gt0_txoutclkfabric_out  (), // output wire gt0_txoutclkfabric_out
    .gt0_txoutclkpcs_out     (), // output wire gt0_txoutclkpcs_out
    //------------------- Transmit Ports - TX Gearbox Ports --------------------
    .gt0_txcharisk_in        (dataIsK), // input wire [1:0] gt0_txcharisk_in
    //----------- Transmit Ports - TX Initialization and Reset Ports -----------
    .gt0_txresetdone_out     (txresetdone), // output wire gt0_txresetdone_out

    //____________________________COMMON PORTS________________________________
    .gt0_qplloutclk_in(1'b0), // input wire gt0_qplloutclk_in
    .gt0_qplloutrefclk_in(1'b0) // input wire gt0_qplloutrefclk_in
);

endmodule
