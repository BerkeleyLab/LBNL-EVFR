/*
 * Configuration parameters shared between software and firmware
 * The restrictions noted in gpio.h apply here, too.
 */

#ifndef _CONFIG_H_
#define _CONFIG_H_

/*
 *  Nominal event receiver clock rate
 */
#define CFG_EVR_CLOCK_RATE      125000000

/*
 * Number of internal fans
 */
#define CFG_FAN_COUNT   2

/*
 * EVIO hardware (event fanout)
 */
#define CFG_EVIO_FIREFLY_COUNT          6
#define CFG_EVIO_HARDWARE_TRIGGER_COUNT 6
#define CFG_EVIO_DIAG_IN_COUNT          1
#define CFG_EVIO_DIAG_OUT_COUNT         2

/*
 * EVRIO hardware (event receiver)
 */
#define CFG_EVR_OUTPUT_COUNT                12 // Number of trigger and pattern output
#define CFG_EVR_OUTPUT_PATTERN_COUNT        4  // Number of pattern output
#define CFG_EVR_OUTPUT_SERDES_WIDTH         4  // Width of DPRAM used to feed OutputDriver SERDES
#define CFG_EVR_OUTPUT_PATTERN_ADDR_WIDTH   12
#define CFG_EVR_DELAY_WIDTH                 22
#define CFG_EVR_WIDTH_WIDTH                 22

/*
 * Kicker driver configuration
 */
#define CFG_KD_OUTPUT_COUNT                 145

/*
 * QSFP Fanout for testing
 */
#define CFG_NUM_GTX_QSFP_FANOUT      3

#endif /* _CONFIG_H_ */
