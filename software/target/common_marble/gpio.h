/*
 * Indices into the big general purpose I/O block.
 * Used to generate Verilog parameter statements too, so be careful with
 * the syntax:
 *     Spaces only (no tabs).
 *     Index defines must be valid Verilog parameter expressions.
 */

#ifndef _GPIO_H_
#define _GPIO_H_

#define GPIO_IDX_COUNT 64

#define GPIO_IDX_FIRMWARE_BUILD_DATE      0 // Firmware build POSIX seconds (R)
#define GPIO_IDX_MICROSECONDS_SINCE_BOOT  1 // Microseconds since boot (R)
#define GPIO_IDX_SECONDS_SINCE_BOOT       2 // Seconds since boot (R)
#define GPIO_IDX_USER_GPIO_CSR            3 // Front panel switches (R)
#define GPIO_IDX_QSPI_FLASH_CSR           4 // Bootstrap flash
#define GPIO_IDX_MMC_MAILBOX              5 // Microcontroller communication
#define GPIO_IDX_I2C_CHUNK_CSR            6 // IIC state machine control/status
#define GPIO_IDX_IIC_PROC                 7 // On-board IIC components
#define GPIO_IDX_FAN_TACHOMETERS          8 // Monitor internal fans
#define GPIO_IDX_EVR_MGT_DRP_CSR          9 // EVR MGT control/status
#define GPIO_IDX_EVR_MGT_STATUS          10 // Additional MGT status (R)
#define GPIO_IDX_EVR_MONITOR_CSR         11 // EVR control/status
#define GPIO_IDX_EVR_MONITOR_SECONDS     12 // EVR monitor seconds (POSIX)
#define GPIO_IDX_EVR_MONITOR_TICKS       13 // EVR monitor ticks (RF/4)
#define GPIO_IDX_EVR_SECONDS             14 // EVR time of day (POSIX)
#define GPIO_IDX_EVR_DISP_LOG_CSR        15 // EVR log
#define GPIO_IDX_FMC1_FIREFLY            16 // Firefly reset/enable
#define GPIO_IDX_FREQ_MONITOR_CSR        17 // Frequency measurement CSR
#define GPIO_IDX_NET_CONFIG_CSR          18 // Network configuration
#define GPIO_IDX_NET_TX_CSR              19 // Network data transmission
#define GPIO_IDX_NET_RX_CSR              20 // Network data reception
#define GPIO_IDX_NET_RX_DATA             21 // Network data reception
#define GPIO_IDX_DISPLAY_CSR             22 // LCD CSR
#define GPIO_IDX_DISPLAY_DATA            23 // LCD Data
#define GPIO_IDX_EVIO_HW_IN              24 // EVIO hardware inputs
#define GPIO_IDX_CONFIG_KD_GATE_DRIVER   28 // Configure kicker driver outputs
#define GPIO_IDX_EVR_SELECT_OUTPUT       29 // Choose EVR output
#define GPIO_IDX_EVR_CONFIG_OUTPUT       30 // Configure EVR output
#define GPIO_IDX_GITHASH                 31 // Git 32-bit hash
#define GPIO_IDX_EVR_TLOG_CSR            32 // EVR tlog event logger control
#define GPIO_IDX_EVR_TLOG_TICKS          33 // EVR tlog event logger ticks

// QSFP Fanout
#define GPIO_IDX_MGT_HW_CONFIG           50 // MGT hardware configuration
#define GPIO_IDX_EVF_MGT_DRP_CSR         51 // EVF MGT control/status
#define GPIO_IDX_PER_MGTWRAPPER           1 // EVF MGT register offset

#include <xil_io.h>
#include <xparameters.h>
#include "config.h"

#define GPIO_READ(i)    Xil_In32(XPAR_GENERIC_REG_BASEADDR+(4*(i)))
#define GPIO_WRITE(i,x) Xil_Out32(XPAR_GENERIC_REG_BASEADDR+(4*(i)),(x))
#define MICROSECONDS_SINCE_BOOT()   GPIO_READ(GPIO_IDX_MICROSECONDS_SINCE_BOOT)

#endif
