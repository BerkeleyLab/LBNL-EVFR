/*
 * Kicker gate driver control
 */
#include <stdio.h>
#include <stdint.h>
#include "iicEVIO.h"
#include "kdGateDriver.h"
#include "gpio.h"
#include "util.h"

#define CSR_W_ADDR_SET_GROUP_VALUE  0xFF000000
#define CSR_W_GROUP_IDELAY_RESET    0x00800000
#define CSR_W_GROUP_IDELAY_INC      0x00020000
#define CSR_W_GROUP_IDELAY_STEP     0x00010000
#define CSR_W_GROUP_SET_DELAY       0x00008000

#define CSR_W_ADDRESS_SHIFT 24
#define CSR_W_CONFIG_MASK   0xFFFFFF
#define CSR_R_IDELAY_MASK   0x1F

#define CSR_WRITE(x) GPIO_WRITE(GPIO_IDX_CONFIG_KD_GATE_DRIVER, (x))
#define CSR_READ() GPIO_READ(GPIO_IDX_CONFIG_KD_GATE_DRIVER)
static void
setGroupDelay(int clocks, int iDelayTarget)
{
    if (debugFlags & DEBUGFLAG_KICKER_DRIVER) {
        printf("  Group delay clocks:%d, iDelay:%d\n", clocks, iDelayTarget);
    }
    for (;;) {
        int iDelayCount = CSR_READ();
        if (iDelayTarget > iDelayCount) {
            CSR_WRITE( CSR_W_ADDR_SET_GROUP_VALUE | CSR_W_GROUP_IDELAY_STEP |
                                                    CSR_W_GROUP_IDELAY_INC);
        }
        else if (iDelayTarget < iDelayCount) {
            CSR_WRITE( CSR_W_ADDR_SET_GROUP_VALUE | CSR_W_GROUP_IDELAY_STEP);
        }
        else {
            break;
        }
    }
    CSR_WRITE(CSR_W_ADDR_SET_GROUP_VALUE | CSR_W_GROUP_SET_DELAY | clocks);
}

void
kdGateDriverUpdate(uint32_t *driverControl)
{
    int g;
    int groupDelayBuckets, groupDelayODELAY = *driverControl & 0xF;
    static int firstTime = 1;
        
    // FIXME -- need to inhibit triggers here?
    // FIXME -- for now we'll let the client deal with inhibiting triggers around an update
    if (firstTime) {
        CSR_WRITE(CSR_W_ADDR_SET_GROUP_VALUE | CSR_W_GROUP_IDELAY_RESET);
        CSR_WRITE(CSR_W_ADDR_SET_GROUP_VALUE | 0);
        firstTime = 0;
    }
    for (g = 0 ; g < CFG_KD_OUTPUT_COUNT ; g++) {
        if (debugFlags & DEBUGFLAG_KICKER_DRIVER) {
            printf("  g%-3d %06X\n", g, *driverControl);
        }
        CSR_WRITE((g << CSR_W_ADDRESS_SHIFT) |
                                        (*driverControl++ & CSR_W_CONFIG_MASK));
    }
    groupDelayBuckets = *driverControl >> 4;
    groupDelayODELAY = *driverControl & 0xF;
    setGroupDelay(groupDelayBuckets, groupDelayODELAY);
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
