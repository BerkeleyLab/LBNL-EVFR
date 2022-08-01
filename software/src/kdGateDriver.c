/*
 * Kicker gate driver control
 */
#include <stdio.h>
#include <stdint.h>
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
