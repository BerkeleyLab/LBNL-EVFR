/*
 * Configure User MGT reference clock (SI570)
 * Complicated by the fact that the SI570 I2C address differs between boards.
 */

#include <stdio.h>
#include <stdint.h>
#include "iicProc.h"
#include "util.h"

/* 7-bit address */
static uint8_t si570Address = 0;

static int
setReg(int reg, int value)
{
    uint8_t cv = value;
    return iicProcWrite(si570Address, reg, &cv, 1);
}

static int
refAdust(int offsetPPM)
{
    int i;
    uint8_t buf[5];
    uint64_t rfreq;

    if (offsetPPM > 3500) offsetPPM = 3500;
    else if (offsetPPM < -3500) offsetPPM = -3500;
    if (!iicProcSetMux(IIC_MUX_PORT_PORT_EXPANDER)) return 0;
    if (!setReg(135, 0x01)) return 0;
    if (!iicProcRead(si570Address, 8, buf, 5)) return 0;
    rfreq = buf[0] & 0x3F;
    for (i = 1 ; i < 5 ; i++) {
        rfreq = (rfreq << 8) | buf[i];
    }
    rfreq = ((rfreq * (1000000 + offsetPPM)) + 500000) / 1000000;
    for (i = 4 ; i > 0 ; i--) {
        buf[i] = rfreq & 0xFF;
        rfreq >>= 8;
    }
    buf[0] = (buf[0] & ~0x3F) | (rfreq & 0x3F);
    if (!setReg(137, 0x20)) return 0;
    if (!iicProcWrite(si570Address, 8, buf, 5)) return 0;
    if (!setReg(137, 0x00)) return 0;
    if (!setReg(135, 0x40)) return 0;
    return 1;
}

int
userMGTrefClkAdjust(int offsetPPM)
{
    int r = 0;
    iicProcTakeControl();
    if (si570Address == 0) {
        if (iicProcSetMux(IIC_MUX_PORT_PORT_EXPANDER)) {
            int i;
            static const uint8_t addrList[] = { 0x55, 0x75 };
            for (i = 0 ; i < sizeof(addrList)/sizeof(addrList[0]) ; i++) {
                if (iicProcWrite(addrList[i], -1, NULL, 0)) {
                    si570Address = addrList[i];
                    break;
                }
            }
        }
    }
    if (si570Address) {
        r = refAdust(offsetPPM);
    }
    iicProcRelinquishControl();
    if (r) {
        printf("Updated MGT SI570 0x%02X (7-bit address).\n", si570Address);
    }
    else {
        warn("Unable to update MGT SI570");
    }
    return r;
}
