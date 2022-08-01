/*
 * Event receiver I/O
 */
#include <stdio.h>
#include <stdint.h>
#include "evfrProtocol.h"
#include "evrio.h"
#include "gpio.h"
#include "util.h"

#define CSR_W_OPCODE_SET_MODE       0x00000000
#define CSR_W_OPCODE_SET_DELAY      0x40000000
#define CSR_W_OPCODE_SET_WIDTH      0x80000000
#define CSR_W_OPCODE_SET_PATTERN    0xC0000000

#define CSR_PATTERN_ADDRESS_MASK  ((1<<(CFG_EVR_OUTPUT_PATTERN_ADDR_WIDTH))-1)
#define CSR_PATTERN_DATA_MASK     ((1<<(CFG_EVR_OUTPUT_SERDES_WIDTH))-1)
#define CSR_PATTERN_ADDRESS_SHIFT    10

#define MODE_MASK    0x3
#define MODE_PATTERN 0x2
#define PATTERN_MASK ((1 << CFG_EVR_OUTPUT_SERDES_WIDTH) - 1)

struct pulseInfo {
    int delay;
    int width;
    int mode;
};
static struct pulseInfo pulseInfo[CFG_EVR_OUTPUT_COUNT];

static void
updatePulse(int output)
{
    struct pulseInfo *pulse = &pulseInfo[output];
    int delay = pulse->delay;
    int leadingZeroCount, coarseDelayCount, leadingOnesCount, widthRemaining;
    int coarseWidthCount;
    int firstPattern, lastPattern;

    if (pulseInfo->mode == MODE_PATTERN) {
        delay = delay - (delay % CFG_EVR_OUTPUT_SERDES_WIDTH);
    }
    leadingZeroCount = delay % CFG_EVR_OUTPUT_SERDES_WIDTH;
    coarseDelayCount = delay / CFG_EVR_OUTPUT_SERDES_WIDTH;
    leadingOnesCount = CFG_EVR_OUTPUT_SERDES_WIDTH - leadingZeroCount;
    widthRemaining = pulse->width - leadingOnesCount;
    if (widthRemaining <= 0) {
        coarseWidthCount = 0;
        firstPattern = ((1 << pulse->width) - 1) << leadingZeroCount;
        lastPattern = 0;
    }
    else {
        int trailingOnesCount = widthRemaining % CFG_EVR_OUTPUT_SERDES_WIDTH;
        coarseWidthCount = widthRemaining / CFG_EVR_OUTPUT_SERDES_WIDTH;
        firstPattern = (PATTERN_MASK << leadingZeroCount) & PATTERN_MASK;
        lastPattern = (1 << trailingOnesCount) - 1;
    }
    GPIO_WRITE(GPIO_IDX_EVR_SELECT_OUTPUT, 1 << output);
    GPIO_WRITE(GPIO_IDX_EVR_CONFIG_OUTPUT, CSR_W_OPCODE_SET_DELAY |
                             (coarseDelayCount << CFG_EVR_OUTPUT_SERDES_WIDTH) |
                             firstPattern);
    GPIO_WRITE(GPIO_IDX_EVR_CONFIG_OUTPUT, CSR_W_OPCODE_SET_WIDTH |
                             (coarseWidthCount << CFG_EVR_OUTPUT_SERDES_WIDTH) |
                             lastPattern);
    GPIO_WRITE(GPIO_IDX_EVR_CONFIG_OUTPUT, CSR_W_OPCODE_SET_MODE | pulse->mode);
}

void
evrioSetMode(int output, int mode)
{
    if ((output < 0)
     || (output >= CFG_EVR_OUTPUT_COUNT)
     || ((mode & MODE_MASK) != mode)) {
        return;
    }
    pulseInfo[output].mode = mode;
    updatePulse(output);
}

void
evrioSetDelay(int output, int delay)
{
    if ((output < 0)
     || (output >= CFG_EVR_OUTPUT_COUNT)
     || (delay < 0)
     || ((delay / CFG_EVR_OUTPUT_SERDES_WIDTH) >= (1UL<<CFG_EVR_DELAY_WIDTH))) {
        return;
    }
    pulseInfo[output].delay = delay;
    updatePulse(output);
}

void
evrioSetWidth(int output, int width)
{
    if ((output < 0)
     || (output >= CFG_EVR_OUTPUT_COUNT)
     || (width < 0)
     || ((width / CFG_EVR_OUTPUT_SERDES_WIDTH) >= (1UL<<CFG_EVR_WIDTH_WIDTH))) {
        return;
    }
    pulseInfo[output].width = width;
    updatePulse(output);
}

void
evrioSetPattern(int output, int count, uint32_t *pattern)
{
    struct pulseInfo *pulse;
    int shift = 0;
    int index = 0;
    int i;
    if ((output < 0)
    || (output >= CFG_EVR_OUTPUT_COUNT)
    || (count <= 0)
    || (((count + 31) / 32) >= EVF_PROTOCOL_ARG_CAPACITY)) {
        return;
    }
    pulse = &pulseInfo[output];
    GPIO_WRITE(GPIO_IDX_EVR_SELECT_OUTPUT, (1 << output));
    for (i = 0 ; (i < count) && (index <= CSR_PATTERN_ADDRESS_MASK) ;
                                    i += CFG_EVR_OUTPUT_SERDES_WIDTH, index++) {
        int bits = (*pattern >> shift) & CSR_PATTERN_DATA_MASK;
        shift += CFG_EVR_OUTPUT_SERDES_WIDTH;
        if ((shift + CFG_EVR_OUTPUT_SERDES_WIDTH) > 32) {
            shift = 0;
            pattern++;
        }
        GPIO_WRITE(GPIO_IDX_EVR_CONFIG_OUTPUT, CSR_W_OPCODE_SET_PATTERN |
                                 (index << CSR_PATTERN_ADDRESS_SHIFT) | bits);
    }
    GPIO_WRITE(GPIO_IDX_EVR_CONFIG_OUTPUT, CSR_W_OPCODE_SET_MODE | pulse->mode);
}
