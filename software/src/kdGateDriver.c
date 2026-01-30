/*
 * Kicker gate driver control
 */
#include <stdio.h>
#include <stdint.h>
#include "iicEVIO.h"
#include "kdGateDriver.h"
#include "gpio.h"
#include "util.h"


#define REG_GATE(base,chan)         ((base) + (GPIO_IDX_CONFIG_KD_GATE * (chan)))
#define REG_GATE_DRIVER(base,chan)  ((base) + (GPIO_IDX_PER_KD_GATE_DRIVER * (chan)))

static void
setGroupDelay(unsigned int idx, int clocks, int iDelayTarget)
{
    if (debugFlags & DEBUGFLAG_KICKER_DRIVER) {
        printf("  i%-1d Group delay clocks:%d, iDelay:%d\n",
                idx, clocks, iDelayTarget);
    }

    for (;;) {
        int iDelayCount = GPIO_READ(GPIO_IDX_CONFIG_KD_CLOCK);
        if (iDelayTarget > iDelayCount) {
            GPIO_WRITE(GPIO_IDX_CONFIG_KD_CLOCK,
                    KD_CLOCK_CSR_GROUP_VALUE |
                    KD_CLOCK_CSR_GROUP_IDELAY_STEP |
                    KD_CLOCK_CSR_GROUP_IDELAY_INC);
        }
        else if (iDelayTarget < iDelayCount) {
            GPIO_WRITE(GPIO_IDX_CONFIG_KD_CLOCK,
                    KD_CLOCK_CSR_GROUP_VALUE |
                    KD_CLOCK_CSR_GROUP_IDELAY_STEP);
        }
        else {
            break;
        }
    }

    GPIO_WRITE(REG(GPIO_IDX_CONFIG_KD_GATE, idx),
            KD_GATE_CSR_GROUP_VALUE |
            KD_GATE_CSR_GROUP_SET_DELAY |
            KD_GATE_CSR_GROUP_DELAY_W(clocks));
}

void
kdGateDriverUpdate(unsigned int idx, uint32_t *driverControl)
{
    int g;
    int groupDelayBuckets, groupDelayODELAY;
    static int firstTime = 1;

    if (idx >= EVF_PROTOCOL_KD_COUNT) {
        return;
    }

    // FIXME -- need to inhibit triggers here?
    // FIXME -- for now we'll let the client deal with inhibiting triggers around an update
    if (firstTime) {
        GPIO_WRITE(GPIO_IDX_CONFIG_KD_CLOCK, KD_CLOCK_CSR_GROUP_VALUE |
                KD_CLOCK_CSR_GROUP_IDELAY_RST);
        GPIO_WRITE(GPIO_IDX_CONFIG_KD_CLOCK, KD_CLOCK_CSR_GROUP_VALUE | 0);
        firstTime = 0;
    }
    for (g = 0 ; g < CFG_KD_OUTPUT_COUNT ; g++) {
        if (debugFlags & DEBUGFLAG_KICKER_DRIVER) {
            printf("  i%-1d g%-3d %06X\n", idx, g, *driverControl);
        }

        GPIO_WRITE(REG(GPIO_IDX_CONFIG_KD_GATE_DRIVER, idx),
                KD_CSR_ADDRESS_W(g) |
                KD_CSR_CONFIG_W(*driverControl));
        driverControl++;
    }
    groupDelayBuckets = *driverControl >> 4;
    groupDelayODELAY = *driverControl & 0xF;
    setGroupDelay(idx, groupDelayBuckets, groupDelayODELAY);
    // FIXME -- need to (re)enable triggers here?
}

/*
 * Kicker driver monitoring
 */
struct i2cInfo {
    uint8_t branchAndI2Cindex;
    uint8_t activeBits;
};
static struct i2cInfo i2cInfo[] = {
    /* FMC 1 -- Eight back panel cards */
    { 0x00, 0xFF },
    { 0x01, 0xFF },
    { 0x02, 0xFF },
    { 0x03, 0xFF },
    { 0x04, 0xFF },
    { 0x05, 0xFF },
    { 0x06, 0xFF },
    { 0x07, 0x03 },

    /* FMC 2 -- Five back panel cards */
    { 0x10, 0xFF },
    { 0x11, 0xFF },
    { 0x12, 0xFF },
    { 0x13, 0xFF },
    { 0x14, 0x03 },

    /* SODIMM -- Seven back panel cards */
    { 0x20, 0xFF },
    { 0x21, 0xFF },
    { 0x22, 0xFF },
    { 0x23, 0xFF },
    { 0x24, 0xFF },
    { 0x25, 0xFF },
    { 0x26, 0x1F },
};
#define I2C_INFO_COUNT (sizeof i2cInfo / sizeof i2cInfo[0])

/*
 * Check for drivers stuck at 0 or 1
 */
int
kdGateDriverGetMonitorStatus(uint32_t *driverStatus)
{
    uint32_t *stuckLow = driverStatus;
    uint32_t *stuckHigh = driverStatus + ((CFG_KD_OUTPUT_COUNT + 31) / 32);
    struct i2cInfo *i2c;
    uint32_t bufBit = 0x1;
    for (i2c = i2cInfo ; i2c < &i2cInfo[I2C_INFO_COUNT] ; i2c++) {
        int branch = i2c->branchAndI2Cindex >> 4;
        int address7 = 0x21 + ((i2c->branchAndI2Cindex & 0x7) << 2);
        uint8_t b, cbuf[2];
        iicEVIOsetGPO(0x1 << branch);
        iicEVIOrecv(address7, 0, cbuf, 2);
        for (b = 0x1 ; b != 0 ; b <<= 1) {
            if (i2c->activeBits & b) {
                int neverLow = ((cbuf[0] & b) != 0);
                int neverHigh = ((cbuf[1] & b) != 0);
                if (bufBit == 0x1) {
                    *stuckLow++ = 0;
                    *stuckHigh++ = 0;
                }
                if (neverHigh) {
                    stuckLow[-1] |= bufBit;
                }
                if (neverLow) {
                    stuckHigh[-1] |= bufBit;
                }
                if (bufBit == 0x80000000) {
                    bufBit = 0x1;
                }
                else {
                    bufBit <<= 1;
                }
            }
        }
    }
    return 2 * ((CFG_KD_OUTPUT_COUNT + 31) / 32);
}

void
kdGateDriverInitMonitorStatus(void)
{
    unsigned char c;
    /*
     * Send general call to all brances -- initializes all gate driver monitors
     */
    c = 0x01;
    iicEVIOsetGPO(0x7);
    iicEVIOsend(0, -1, &c, 1);

    /*
     * Remove general call from all branches -- activates all monitors
     */
    c = 0x08;
    iicEVIOsend(0, -1, &c, 1);
    iicEVIOsetGPO(0x1);
}
