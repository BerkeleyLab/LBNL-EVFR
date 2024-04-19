/*
 * Copyright 2020, Lawrence Berkeley National Laboratory
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its
 * contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS
 * AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 * BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include "bootFlash.h"
#include "console.h"
#include "display.h"
#include "epics.h"
#include "eventMonitor.h"
#include "evio.h"
#include "eyescan.h"
#include "gpio.h"
#include "iicChunk.h"
#include "iicProc.h"
#include "platform.h"
#include "mgt.h"
#include "mgtClkSwitch.h"
#include "mmcMailbox.h"
#include "softwareBuildDate.h"
#include "st7789v.h"
#include "systemParameters.h"
#include "tftp.h"
#include "util.h"
#include "evrio.h"

/*
 * Type/length 7:6 11 ASCII if english...
 * 6 bit length
 */
int hwConfig;
static void
checkHardwareConfiguration(void)
{
    int fmcIndex;
    int firmwareIsKickerDriver=((GPIO_READ(GPIO_IDX_FMC1_FIREFLY)&(1<<31))!=0);
    for (fmcIndex = 0 ; fmcIndex < 2 ; fmcIndex++) {
        const char *name = iicProcFMCproductType(fmcIndex);
        if ((name == NULL) || (*name == '\0')) {
            continue;
        }
        if ((strcmp(name, "EVIO") == 0) && (fmcIndex == 0)) {
            hwConfig |= HWCONFIG_HAS_EVIO;
            evioInit();
        }
        else if ((strcmp(name, "EVRIO") == 0 ||
                  strcmp(name, "UserTiming") == 0) && (fmcIndex == 1)) {
            evrioInit();
            hwConfig |= HWCONFIG_HAS_EVRIO;
        }
        else if (strcmp(name, "KDIO") == 0) {
            hwConfig |= HWCONFIG_HAS_KICKER_DRIVER;
        }
        else {
            warn("FMC %d -- Invalid card/location", fmcIndex + 1);
        }
    }
    if (firmwareIsKickerDriver) {
        if (!(hwConfig & HWCONFIG_HAS_KICKER_DRIVER)) {
            warn("Kicker driver firmware but not kicker driver hardware");
        }
    }
    else {
        if (hwConfig & HWCONFIG_HAS_KICKER_DRIVER) {
            warn("Kicker driver hardware but not kicker driver firmware");
        }
    }
    switch (hwConfig & (HWCONFIG_HAS_EVIO | HWCONFIG_HAS_QSFP2)) {
    case 0:
        warn("Critical -- Neither EVIO nor QSFP2 are present.  "
              "No event source!");
        break;
    case HWCONFIG_HAS_EVIO | HWCONFIG_HAS_QSFP2:
        warn("Both EVIO and QSFP2 are present -- this is unusual.");
        break;
    default: break;
    }
}

/*
 * "High priority" polling
 */
static void
pollHighPriority(void)
{
    eventMonitorCrank();
    displayCrank();
}

int
main(void)
{
    /* Set up infrastructure */
    init_platform();
    st7789vInit();

    /* Let UART settle down */
    microsecondSpin(20000);

    /* Screen check */
    st7789vTestPattern();
    microsecondSpin(0.5 * 1000 * 1000);
    st7789vFlood(0, 0, COL_COUNT, ROW_COUNT, 0);

    /* Announce our presence */
    printf("\nGit ID (32-bit): 0x%08x\n", GPIO_READ(GPIO_IDX_GITHASH));
    printf("Firmware POSIX seconds: %u\n",
                         (unsigned int)GPIO_READ(GPIO_IDX_FIRMWARE_BUILD_DATE));
    printf("Software POSIX seconds: %u\n", SOFTWARE_BUILD_DATE);

    /*
     * Initialize IIC chunk and give it time to complete a scan
     */
    iicChunkInit();
    microsecondSpin(500000);
    iicProcInit();

    /*
     * Start things
     */
    bootFlashInit();
    systemParametersInit();
    showNetworkConfig(&systemParameters.netConfig.np);
    bwudpRegisterInterface(
                         (ethernetMAC *)&systemParameters.netConfig.ethernetMAC,
                         (ipv4Address *)&systemParameters.netConfig.np.address,
                         (ipv4Address *)&systemParameters.netConfig.np.netmask,
                         (ipv4Address *)&systemParameters.netConfig.np.gateway);
    consoleInit();

    /*
     * More initialization
     */
    tftpInit();
    eventMonitorInit();
    mmcMailboxInit();
    mgtClkSwitchInit();
    eyescanInit();
    mgtInit();
    epicsInit();
    checkHardwareConfiguration();
    if (hwConfig & (HWCONFIG_HAS_EVRIO | HWCONFIG_HAS_EVIO)) {
        /*
         * The current EVRIO version has a non-constant CLK3 phase relationship
         * with the reference clock (evrClk) hence the workaround relies on the
         * PAT0 output to generate a 125 MHz clock
         */
        printf("Setting PAT0 as 125 MHz clock (pattern loop mode)\n");
        uint32_t pattern[] = {3, 0, 0, 0};
        evrioSetPattern(0, 4, pattern);
        evrioSetMode(0, 3);
        evrSetActionForEvent(122, 1);
    }
    /*
     * Main processing loop
     */
    for (;;) {
        checkForReset();
        pollHighPriority();
        bwudpCrank();
        pollHighPriority();
        consoleCheck();
        pollHighPriority();
        mgtCrankRxAligner();
        pollHighPriority();
        if (hwConfig & HWCONFIG_HAS_EVRIO) {
            evrioCrank();
        }
        pollHighPriority();
        if (hwConfig & HWCONFIG_HAS_EVIO) {
            evioCrank();
        }
        pollHighPriority();
    }

    /* Never reached */
    cleanup_platform();
    return 0;
}
