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

/*
 * Accept and act upon commands from the IOC
 */
#include <stdio.h>
#include <string.h>
#include "evfrProtocol.h"
#include "bwudp.h"
#include "epics.h"
#include "evio.h"
#include "eventMonitor.h"
#include "evrio.h"
#include "gpio.h"
#include "iicChunk.h"
#include "kdGateDriver.h"
#include "mmcMailbox.h"
#include "softwareBuildDate.h"
#include "util.h"
#include "utio.h"
#include "xadc.h"

/*
 * Handle a reboot request
 */
static void
crankRebootStateMachine(int value)
{
    static uint16_t match[] = { 1, 100, 10000 };
    static int i;

    if (value == match[i]) {
        i++;
        if (i == (sizeof match / sizeof match[0])) {
            resetFPGA(0);
        }
    }
    else {
        i = 0;
    }
}

/*
 * Read fan tachometers
 * Works for even or odd number of fans
 */
static int
fetchFanSpeeds(uint32_t *ap)
{
    int i, shift = 0, count = 0;
    uint32_t v = 0;
    for (i = 0 ; i < CFG_FAN_COUNT ; i++) {
        if (shift > 16) {
            *ap++ = v;
            count++;
            shift = 0;
        }
        GPIO_WRITE(GPIO_IDX_FAN_TACHOMETERS, i);
        v |= (GPIO_READ(GPIO_IDX_FAN_TACHOMETERS) & 0xFFFF) << shift;
        shift += 16;
    }
    *ap = v;
    return count + 1;
}

/*
 * Fetch system monitors
 */
static int
sysmonFetch(uint32_t *args)
{
    uint32_t *ap = args;
    ap = xadcUpdate(ap);
    ap = iicChunkReadback(ap);
    ap = mmcMailboxFetchSysmon(ap);
    /*
     * Get recovered clock frequency.
     * Channel order set by freq_multi_count instantiation in EVFR.v.
     */
    GPIO_WRITE(GPIO_IDX_FREQ_MONITOR_CSR, 2);
    *ap++ = GPIO_READ(GPIO_IDX_FREQ_MONITOR_CSR) & 0x3FFFFFFF;
    *ap++ = GPIO_READ(GPIO_IDX_EVR_MONITOR_CSR);
    ap += fetchFanSpeeds(ap);
    ap = evioFetchSysmon(ap);
    ap = utioFetchSysmon(ap); /* FIXME -- Here's where EVRIO values would read back */
    return ap - args;
}

/*
 * Process command
 */
static int
handleCommand(int commandArgCount, struct evfPacket *cmdp,
                                   struct evfPacket *replyp)
{
    int lo = cmdp->command & EVF_PROTOCOL_CMD_MASK_LO;
    int idx = cmdp->command & EVF_PROTOCOL_CMD_MASK_IDX;
    int replyArgCount = 0;
    static int powerUpStatus = 1;

    switch (cmdp->command & EVF_PROTOCOL_CMD_MASK_HI) {
    case EVF_PROTOCOL_CMD_HI_LONGIN:
        if (commandArgCount != 0) return -1;
        replyArgCount = 1;
        switch (lo) {
        case EVF_PROTOCOL_CMD_LONGIN_LO_GENERIC:
            switch (idx) {
            case EVF_PROTOCOL_CMD_LONGIN_IDX_FIRMWARE_BUILD_DATE:
                replyp->args[0] = GPIO_READ(GPIO_IDX_FIRMWARE_BUILD_DATE);
                break;

            case EVF_PROTOCOL_CMD_LONGIN_IDX_SOFTWARE_BUILD_DATE:
                replyp->args[0] = SOFTWARE_BUILD_DATE;
                break;

            case EVF_PROTOCOL_CMD_LONGIN_IDX_GIT_HASH_ID:
                replyp->args[0] = GPIO_READ(GPIO_IDX_GITHASH);
                break;

            default: return -1;
            }
            break;

        default: return -1;
        }
        break;

    case EVF_PROTOCOL_CMD_HI_LONGOUT:
        if (commandArgCount != 1) return -1;
        switch (lo) {
        case EVF_PROTOCOL_CMD_LONGOUT_LO_NO_VALUE:
            switch (idx) {
            case EVF_PROTOCOL_CMD_LONGOUT_NV_IDX_CLEAR_POWERUP_STATUS:
                powerUpStatus = 0;
                break;

            default: return -1;
            }
            break;

        case EVF_PROTOCOL_CMD_LONGOUT_LO_EVR_ACTION:
            evrSetActionForEvent(idx & 0xFF, cmdp->args[0]);
            break;

        case EVF_PROTOCOL_CMD_LONGOUT_LO_EVR_MODE:
            evrioSetMode(idx, cmdp->args[0]);
            break;

        case EVF_PROTOCOL_CMD_LONGOUT_LO_EVR_DELAY:
            evrioSetDelay(idx, cmdp->args[0]);
            break;

        case EVF_PROTOCOL_CMD_LONGOUT_LO_EVR_WIDTH:
            evrioSetWidth(idx, cmdp->args[0]);
            break;

        case EVF_PROTOCOL_CMD_LONGOUT_LO_GENERIC:
            switch (idx) {
            case EVF_PROTOCOL_CMD_LONGOUT_GENERIC_IDX_REBOOT:
                crankRebootStateMachine(cmdp->args[0]);
                break;

            case EVF_PROTOCOL_CMD_LONGOUT_GENERIC_IDX_SET_LOOPBACK:
                if (!(hwConfig & HWCONFIG_HAS_EVIO)) return -1;
                evioSetLoopback(cmdp->args[0]);
                break;

            default: return -1;
            }
            break;

        default: return -1;
        }
        break;

    case EVF_PROTOCOL_CMD_HI_SYSMON:
        if (commandArgCount != 0) return -1;
        replyp->args[0] = powerUpStatus;
        replyArgCount = sysmonFetch(replyp->args + 1) + 1;
        break;

    case EVF_PROTOCOL_CMD_HI_PATTERN:
        switch (lo) {
        case EVF_PROTOCOL_CMD_PATTERN_LO_WRITE:
            evrioSetPattern(idx, cmdp->args[0], &cmdp->args[1]);
            break;

        default: return -1;
        }
        break;

    case EVF_PROTOCOL_CMD_HI_KICKER_DRIVER:
        if ((hwConfig & HWCONFIG_HAS_KICKER_DRIVER)
         && (lo == EVF_PROTOCOL_CMD_LO_KICKER_DRIVER)
         && (idx == EVF_PROTOCOL_CMD_KICKER_DRIVER_IDX_SET_GROUP_DELAY)) {
            kdGateDriverUpdate(cmdp->args);
            break;
        }
        else {
            return -1;
        }

    default: return -1;
    }
    return replyArgCount;
}

/*
 * Handle commands from IOC
 */
static void
epicsHandler(bwudpHandle replyHandle, char *payload, int length)
{
    struct evfPacket *cmdp = (struct evfPacket *)payload;
    int mustSwap = 0;
    int commandArgCount;
    static struct evfPacket reply;
    static int replySize;
    static uint32_t lastNonce;

    /*
     * Ignore weird-sized packets
     */
    if ((length < EVF_PROTOCOL_ARG_COUNT_TO_SIZE(0))
     || (length > sizeof(struct evfPacket))
     || ((length % sizeof(uint32_t)) != 0)) {
        return;
    }
    commandArgCount = EVF_PROTOCOL_SIZE_TO_ARG_COUNT(length);
    if (cmdp->magic == EVF_PROTOCOL_MAGIC_SWAPPED) {
        mustSwap = 1;
        bswap32(&cmdp->magic, length / sizeof(int32_t));
    }
    if (cmdp->magic == EVF_PROTOCOL_MAGIC) {
        if (debugFlags & DEBUGFLAG_EPICS) {
            printf("Command:%X nonce:%X args:%d 0x%x\n",
                         (unsigned int)cmdp->command, (unsigned int)cmdp->nonce,
                         commandArgCount, (unsigned int)cmdp->args[0]);
        }
        if (cmdp->nonce != lastNonce) {
            int n;
            memcpy(&reply, cmdp, EVF_PROTOCOL_ARG_COUNT_TO_SIZE(0));
            if ((n = handleCommand(commandArgCount, cmdp, &reply)) < 0) {
                return;
            }
            lastNonce = cmdp->nonce;
            replySize = EVF_PROTOCOL_ARG_COUNT_TO_SIZE(n);
            if (mustSwap) {
                bswap32(&reply.magic, replySize / sizeof(int32_t));
            }
        }
        bwudpSend(replyHandle, (const char *)&reply, replySize);
    }
}

void
epicsInit(void)
{
    bwudpRegisterServer(htons(EVF_PROTOCOL_UDP_EPICS_PORT), epicsHandler);
}
