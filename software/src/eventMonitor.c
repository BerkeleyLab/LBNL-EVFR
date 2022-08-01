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
 * Publish event monitors to IOC
 */
#include <stdio.h>
#include <string.h>
#include "bwudp.h"
#include "eventMonitor.h"
#include "evfrProtocol.h"
#include "gpio.h"
#include "util.h"

#define SUBSCRIPTION_TIMEOUT_SECONDS    50

#define CSR_W_MONITOR_ACTION            0x80000000
#define CSR_W_MONITOR_FIFO_READ         0x40000000
#define CSR_W_MONITOR_FIFO_ENABLE_RESET 0x20000000
#define CSR_W_MONITOR_FIFO_APPLY_RESET  0x10000000
#define CSR_R_MONITOR_FIFO_EMPTY        0x40000000
#define CSR_R_MONITOR_FIFO_CODE_MASK    0xFF0000
#define CSR_MONITOR_FIFO_CODE_SHIFT     16

#define EVENT_HANDLER_CAPACITY    255

#define EVR_ACTION_MASK ((1 << (CFG_EVR_OUTPUT_COUNT)) - 1)
#define EVR_ACTION_LOG (1 << (CFG_EVR_OUTPUT_COUNT))

static uint16_t eventActions[EVENT_HANDLER_CAPACITY];
static uint32_t eventCounts[EVENT_HANDLER_CAPACITY];

static bwudpHandle eventMonitorHandle;
static struct evfPacket reply;
static int replyArgc;
static uint32_t whenSubscribed;

/*
 * Set event action
 */
void
evrSetActionForEvent(int e, int action)
{
    if ((e >= 1) && (e < EVENT_HANDLER_CAPACITY)) {
        action &= EVR_ACTION_MASK;
        action |= eventActions[e] & EVR_ACTION_LOG;
        GPIO_WRITE(GPIO_IDX_EVR_MONITOR_CSR, (action << 8) | e);
        eventActions[e] = action;
    }
}

/*
 * Check for event arrival
 */
void
eventMonitorCrank(void)
{
    uint32_t csr;
    uint32_t now = MICROSECONDS_SINCE_BOOT();
    static uint32_t whenLastSent;
    static uint32_t whenFirstArrived;
    static int watchdog = 3;

    if (eventMonitorHandle == NULL) return;
    if ((GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT) - whenSubscribed) >
                                                 SUBSCRIPTION_TIMEOUT_SECONDS) {
        if (debugFlags & DEBUGFLAG_EVENT_MONITOR) {
            printf("Subscription timeout\n");
        }
        eventMonitorHandle = NULL;
        return;
    }

    /*
     * Read events from FIFO until empty
     */
    while (((csr=GPIO_READ(GPIO_IDX_EVR_MONITOR_CSR)) &
                                               CSR_R_MONITOR_FIFO_EMPTY) == 0) {
        int eventCode = (csr & CSR_R_MONITOR_FIFO_CODE_MASK) >>
                                                    CSR_MONITOR_FIFO_CODE_SHIFT;
        if (replyArgc == 0) {
            whenFirstArrived = now;
        }
        if ((eventCode >= 1) && (eventCode < EVENT_HANDLER_CAPACITY)) {
            eventCounts[eventCode]++;
            reply.args[replyArgc+0] = eventCode;
            reply.args[replyArgc+1] = GPIO_READ(GPIO_IDX_EVR_MONITOR_SECONDS);
            reply.args[replyArgc+2] = GPIO_READ(GPIO_IDX_EVR_MONITOR_TICKS);
            reply.args[replyArgc+3] = eventCounts[eventCode];
            replyArgc += 4;
        }
        GPIO_WRITE(GPIO_IDX_EVR_MONITOR_CSR, CSR_W_MONITOR_ACTION |
                                             CSR_W_MONITOR_FIFO_READ);
        if ((replyArgc + 4) > EVF_PROTOCOL_ARG_CAPACITY) {
            reply.command++;
            bwudpSend(eventMonitorHandle, (const char *)&reply,
                                     EVF_PROTOCOL_ARG_COUNT_TO_SIZE(replyArgc));
            whenLastSent = now;
            replyArgc = 0;
            /*
             * Guard against getting stuck here forever
             */
            if (--watchdog == 0) {
                return;
            }
        }
    }

    /*
     * Send after pause to wait for more events
     */
    if ((replyArgc != 0) && ((now - whenFirstArrived) > 10000)) {
        reply.command++;
        bwudpSend(eventMonitorHandle, (const char *)&reply,
                                     EVF_PROTOCOL_ARG_COUNT_TO_SIZE(replyArgc));
        whenLastSent = now;
        replyArgc = 0;
    }

    /*
     * Send keepalive if necessary
     */
    if ((now - whenLastSent) >= 5000000) {
        reply.command++;
        bwudpSend(eventMonitorHandle, (const char *)&reply,
                                             EVF_PROTOCOL_ARG_COUNT_TO_SIZE(0));
        whenLastSent = now;
    }
}

/*
 * Handle commands from IOC
 */
static void
eventMonitorHandler(bwudpHandle replyHandle, char *payload, int length)
{
    struct evfPacket *cmdp = (struct evfPacket *)payload;
    int e;

    if (debugFlags & DEBUGFLAG_EVENT_MONITOR) {
        printf("Subscribe\n");
    }

    /*
     * Ignore weird-sized packets
     */
    if (length !=
               EVF_PROTOCOL_ARG_COUNT_TO_SIZE((EVENT_HANDLER_CAPACITY+31)/32)) {
        return;
    }

    /*
     * Enable replies
     */
    whenSubscribed = GPIO_READ(GPIO_IDX_SECONDS_SINCE_BOOT);
    reply.magic = cmdp->magic;
    eventMonitorHandle = replyHandle;
    if (reply.nonce == cmdp->nonce) {
        return; /* Resubscription packets require no further processing */
    }
    reply.nonce = cmdp->nonce;

    /*
     * Log events of interest
     */
    if (debugFlags & DEBUGFLAG_EVENT_MONITOR) {
        printf("Monitor\n");
    }
    for (e = 1 ; e < EVENT_HANDLER_CAPACITY ; e++) {
        int argIdx = e >> 5;
        int bitIdx = e & 0x1F;
        if (cmdp->args[argIdx] & (uint32_t)1 << bitIdx) {
            eventActions[e] |= EVR_ACTION_LOG;
            if (debugFlags & DEBUGFLAG_EVENT_MONITOR) {
                printf(" %d", e);
            }
        }
        else {
            eventActions[e] &= ~EVR_ACTION_LOG;
        }
        GPIO_WRITE(GPIO_IDX_EVR_MONITOR_CSR, (eventActions[e] << 8) | e);
    }
    if (debugFlags & DEBUGFLAG_EVENT_MONITOR) {
        printf("\n");
    }

    /*
     * Flush any dregs left in FIFO
     */
    GPIO_WRITE(GPIO_IDX_EVR_MONITOR_CSR, CSR_W_MONITOR_ACTION |
                                         CSR_W_MONITOR_FIFO_ENABLE_RESET |
                                         CSR_W_MONITOR_FIFO_APPLY_RESET);
    microsecondSpin(1);
    GPIO_WRITE(GPIO_IDX_EVR_MONITOR_CSR, CSR_W_MONITOR_ACTION |
                                         CSR_W_MONITOR_FIFO_ENABLE_RESET);
    replyArgc = 0;
}

void
eventMonitorInit(void)
{
    bwudpRegisterServer(htons(EVF_PROTOCOL_UDP_EPICS_PORT+1), eventMonitorHandler);
}
