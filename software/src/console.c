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
 * Simple command interpreter
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <xparameters.h>
#include <xuartlite_l.h>
#include "eyescan.h"
#include "gpio.h"
#include "iicProc.h"
#include "mgt.h"
#include "mgtClkSwitch.h"
#include "systemParameters.h"
#include "user_mgt_refclk.h"
#include "st7789v.h"
#include "util.h"

#define CONSOLE_UDP_PORT 50004
#define UDP_BUFSIZE      1460

/*
 * UDP console support
 */
static struct udpConsole {
    int         active;
    bwudpHandle handle;
    int         txIndex;
    char        txBuf[UDP_BUFSIZE];
    uint32_t    usAtFirstOutputCharacter;
    char        rxBuf[UDP_BUFSIZE];
    int         rxIndex;
    int         rxCount;
} udpConsole;

/*
 * Special modes
 */
static int (*modalHandler)(int argc, char **argv);

/*
 * Mark UDP console inactive while draining in case
 * network code diagnostic messages are enabled.
 */
static void
udpConsoleDrain(void)
{
    udpConsole.active = 0;
    bwudpSend(udpConsole.handle, udpConsole.txBuf, udpConsole.txIndex);
    udpConsole.txIndex = 0;
    udpConsole.active = 1;
}

/*
 * Handle an incoming packet on the console port
 */
void
callbackConsole(bwudpHandle replyHandle, char *payload, int length)
{
    int nCopy, nFree;
    udpConsole.handle = replyHandle;
    nCopy = udpConsole.rxCount - udpConsole.rxIndex;
    if (nCopy > 0) {
        memmove(udpConsole.rxBuf, udpConsole.rxBuf + udpConsole.rxIndex, nCopy);
        udpConsole.rxCount = nCopy;
        nFree = UDP_BUFSIZE - nCopy;
    }
    else {
        udpConsole.rxCount = 0;
        nFree = UDP_BUFSIZE;
    }
    udpConsole.rxIndex = 0;
    if (nFree) {
        if (length > nFree) {
            length = nFree;
        }
        memcpy(udpConsole.rxBuf + udpConsole.rxCount, payload, length);
        udpConsole.rxCount += length;
    }
}

/*
 * Pulling in real sprintf bloats executable by more than 60 kB so provide this
 * fake version that accepts only a limited number of integer arguments.
 */
static char *outbyteStash;
int
sprintf(char *buf, const char *fmt, ...)
{
    va_list args;
    unsigned int a[6];
    va_start(args, fmt);
    a[0] = va_arg(args, unsigned int);
    a[1] = va_arg(args, unsigned int);
    a[2] = va_arg(args, unsigned int);
    a[3] = va_arg(args, unsigned int);
    a[4] = va_arg(args, unsigned int);
    a[5] = va_arg(args, unsigned int);
    *buf = '\0';
    outbyteStash = buf;
    printf(fmt, a[0], a[1], a[2], a[3], a[4], a[5]);
    outbyteStash = NULL;
    va_end(args);
    return outbyteStash - buf;
}

/*
 * Stash character and return if in 'sprintf'.
 * Convert <newline> to <carriage return><newline> so
 * we can use normal looking printf format strings.
 * Hang on to startup messages.
 * Buffer to limit the number of transmitted packets.
 */
#define STARTBUF_SIZE   5000
static char startBuf[STARTBUF_SIZE];
static int startIdx = 0;
static int isStartup = 1;
static int showingStartup = 0;

void
outbyte(char8 c)
{
    static int wasReturn;

    if (outbyteStash != NULL) {
        *outbyteStash++ = c;
        *outbyteStash = '\0';
        return;
    }
    if ((c == '\n') && !wasReturn) outbyte('\r');
    wasReturn = (c == '\r');
    XUartLite_SendByte(STDOUT_BASEADDRESS, c);
    if (isStartup && (startIdx < STARTBUF_SIZE))
        startBuf[startIdx++] = c;
    if (udpConsole.active) {
        if (udpConsole.txIndex == 0)
            udpConsole.usAtFirstOutputCharacter = MICROSECONDS_SINCE_BOOT();
        udpConsole.txBuf[udpConsole.txIndex++] = c;
        if (udpConsole.txIndex >= UDP_BUFSIZE) {
            udpConsoleDrain();
        }
    }
}

static int
cmdLOG(int argc, char **argv)
{
    showingStartup = 1;
    return 0;
}

static int
cmdBOOT(int argc, char **argv)
{
    static int bootAlternateImage;
    if (modalHandler) {
        if (argc == 1) {
            if (strcasecmp(argv[0], "Y") == 0) {
                if (udpConsole.active) udpConsoleDrain();
                microsecondSpin(1000);
                resetFPGA(bootAlternateImage);
                modalHandler = NULL;
                return 0;
            }
            if (strcasecmp(argv[0], "N") == 0) {
                modalHandler = NULL;
                return 0;
            }
        }
    }
    else {
        if (argc == 1) {
            bootAlternateImage = 0;
        }
        else if ((argc == 2)
              && (argv[1][0] == '-')
              && ((argv[1][1] == 'b') || (argv[1][1] == 'B'))
              && (argv[1][2] == '\0')) {
            bootAlternateImage = 1;
        }
        else {
            printf("Invalid argument.\n");
            return 0;
        }
        modalHandler = cmdBOOT;
    }
    printf("Reboot FPGA image %c (y or n)? ", 'A' + bootAlternateImage);
    fflush(stdout);
    return 0;
}

static int
cmdDEBUG(int argc, char **argv)
{
    char *endp;
    int d;
    int sFlag = 0;

    if ((argc > 1) && (strcmp(argv[1], "-s") == 0)) {
        sFlag = 1;
        argc--;
        argv++;
    }
    if ((argc > 1) && (strcmp(argv[1], "-h") == 0)) {
        argc--;
        argv++;
        printDebugFlags();
    }
    if (argc > 2) {
            printf("Too many arguments.\n");
            return 0;
    }
    if (argc > 1) {
        d = strtol(argv[1], &endp, 16);
        if (*endp != '\0') {
            printf("Bad argument.\n");
            return 0;
        }
    }
    else {
        d = debugFlags;
    }
    if (sFlag) {
        if ((argc > 1) && (systemParameters.startupDebugFlags != d)) {
            systemParameters.startupDebugFlags = d;
            systemParametersStash();
        }
        printf("Startup debug flags: 0x%x\n",
                                            systemParameters.startupDebugFlags);
    }
    else {
        if (d & DEBUGFLAG_IIC_SCAN) iicProcScan();
        if (d & DEBUGFLAG_DUMP_SCREEN) st7789vDumpScreen();
        if (d & DEBUGFLAG_DUMP_MGT_SWITCH) mgtClkSwitchDump();
        if (d & DEBUGFLAG_SHOW_RX_ALIGNER) mgtShowRxAligners();
        debugFlags = d;
        printf("Debug flags: 0x%x\n", debugFlags);
    }
    return 0;
}

static int
cmdDumpScreen(int argc, char **argv)
{
    printf("dumpscreen\n");
    st7789vDumpScreen();
    return 0;
}

static int
cmdFMON(int argc, char **argv)
{
    int i;
    static const char *names[] = { "System",
                                   "MGT reference",
                                   "Event receiver",
                                   "Ethernet Tx",
                                   "Ethernet Rx",
                                   "EVRIO PLL" };
    for (i = 0 ; i < sizeof names / sizeof names[0] ; i++) {
        GPIO_WRITE(GPIO_IDX_FREQ_MONITOR_CSR, i);
        uint32_t csr = GPIO_READ(GPIO_IDX_FREQ_MONITOR_CSR);
        unsigned int rate = csr & 0xc3FFFFFFF;
        printf("%20s clock: %3d.", names[i], rate / 1000000);
        if (csr & 0x80000000) {
            printf("%03d\n", (rate / 1000) % 1000);
        }
        else {
            printf("%06d\n", rate % 1000000);
        }
    }
    return 0;
}

static int
cmdNET(int argc, char **argv)
{
    int bad = 0;
    int i;
    char *cp;
    uint32_t netmask;
    unsigned int netLen = 24;
    char *endp;
    static struct sysNetParms np;

    if (modalHandler) {
        if (argc == 1) {
            if (strcasecmp(argv[0], "Y") == 0) {
                systemParameters.netConfig.np = np;
                systemParametersStash();
                modalHandler = NULL;
                return 0;
            }
            if (strcasecmp(argv[0], "N") == 0) {
                modalHandler = NULL;
                return 0;
            }
        }
    }
    else {
        if (argc == 1) {
            np = systemParameters.netConfig.np;
        }
        else if (argc == 2) {
            cp = argv[1];
            i = parseIP(cp, &np.address);
            if (i < 0) {
                bad = 1;
            }
            else if (cp[i] == '/') {
                netLen = strtol(cp + i + 1, &endp, 0);
                if ((*endp != '\0')
                 || (netLen < 8)
                 || (netLen > 24)) {
                    bad = 1;
                    netLen = 24;
                }
            }
            netmask = ~0U << (32 - netLen);
            np.netmask.a[0] = netmask >> 24;
            np.netmask.a[1] = netmask >> 16;
            np.netmask.a[2] = netmask >> 8;
            np.netmask.a[3] = netmask;
            np.gateway.a[0] = np.address.a[0] & np.netmask.a[0];
            np.gateway.a[1] = np.address.a[1] & np.netmask.a[1];
            np.gateway.a[2] = np.address.a[2] & np.netmask.a[2];
            np.gateway.a[3] = (np.address.a[3] & np.netmask.a[3]) | 1;
        }
        else {
            bad = 1;
        }
        if (bad) {
            printf("Command takes single optional argument of the form "
                   "www.xxx.yyy.xxx[/n]\n");
            return 1;
        }
    }
    showNetworkConfig(&np);
    if (!memcmp(&np.address, &systemParameters.netConfig.np.address, sizeof(ipv4Address))
     && !memcmp(&np.netmask, &systemParameters.netConfig.np.netmask, sizeof(ipv4Address))
     && !memcmp(&np.gateway, &systemParameters.netConfig.np.gateway, sizeof(ipv4Address))) {
        return 0;
    }
    printf("Write parameters to flash (y or n)? ");
    fflush(stdout);
    modalHandler = cmdNET;
    return 0;
}

static int
cmdMAC(int argc, char **argv)
{
    int bad = 0;
    int i;
    static ethernetMAC mac;

    if (modalHandler) {
        if (argc == 1) {
            if (strcasecmp(argv[0], "Y") == 0) {
                memcpy(&systemParameters.netConfig.ethernetMAC,&mac,sizeof mac);
                systemParametersStash();
                modalHandler = NULL;
                return 0;
            }
            if (strcasecmp(argv[0], "N") == 0) {
                modalHandler = NULL;
                return 0;
            }
        }
    }
    else {
        if (argc == 1) {
            memcpy(&mac, &systemParameters.netConfig.ethernetMAC, sizeof mac);
        }
        else if (argc == 2) {
            i = parseMAC(argv[1], &mac);
            if ((i < 0) || (argv[1][i] != '\0')) {
                bad = 1;
            }
        }
        else {
            bad = 1;
        }
        if (bad) {
            printf("Command takes single optional argument of the form "
                   "aa:bb:cc:dd:ee:ff\n");
            return 1;
        }
    }
    printf("   ETHERNET ADDRESS: %s\n", formatMAC(&mac));
    if (!(memcmp(&systemParameters.netConfig.ethernetMAC, &mac, sizeof mac))) {
        return 0;
    }
    printf("Write to flash (y or n)? ");
    fflush(stdout);
    modalHandler = cmdMAC;
    return 0;
}

static int
cmdREG(int argc, char **argv)
{
    char *endp;
    int i;
    int first;
    int n = 1;

    if (argc > 1) {
        first = strtol(argv[1], &endp, 0);
        if (*endp != '\0')
            return 1;
        if (argc > 2) {
            n = strtol(argv[2], &endp, 0);
            if (*endp != '\0')
                return 1;
        }
        if ((first < 0) || (first >= GPIO_IDX_COUNT) || (n <= 0))
            return 1;
        if ((first + n) > GPIO_IDX_COUNT)
            n = GPIO_IDX_COUNT - first;
        for (i = first ; i < first + n ; i++) {
            showReg(i);
        }
    }
    return 0;
}

static int
cmdUMGT(int argc, char **argv)
{
    if (argc > 1) {
        char *endp;
        int offsetPPM = strtol(argv[1], &endp, 10);
        if (*endp == '\0') {
            if (offsetPPM > 3500) offsetPPM = 3500;
            else if (offsetPPM < -3500) offsetPPM = -3500;
            if (userMGTrefClkAdjust(offsetPPM)) {
                if (systemParameters.userMGTrefClkOffsetPPM != offsetPPM) {
                    systemParameters.userMGTrefClkOffsetPPM = offsetPPM;
                    systemParametersStash();
                }
            }
        }
    }
    systemParametersShowUserMGTrefClkOffsetPPM();
    return 0;
}

static int showEVIO;
static int
cmdShowEVIO(int argc, char **argv)
{
    int newValue = GPIO_READ(GPIO_IDX_EVIO_HW_IN);
    static int oldValue;
    if (argc >= 1) {
        if (!(hwConfig & HWCONFIG_HAS_EVIO)) {
            printf("EVIO card not installed.\n");
            return 1;
        }
        showEVIO = 1;
        oldValue = ~newValue;
    }
    if (oldValue != newValue) {
        int i, b = 0x1;
        oldValue = newValue;
        print("\rTRIG:");
        for (i = 0 ; i < CFG_EVIO_HARDWARE_TRIGGER_COUNT ; i++, b <<= 1) {
            printf("%c", newValue & b ? '1'+i : '.');
        }
        printf("  DIAG:", newValue & b ? '1' : '.');
        for (i = 0 ; i < CFG_EVIO_DIAG_IN_COUNT ; i++, b <<= 1) {
            printf("%c", newValue & b ? '1'+i : '.');
        }
        printf("  AUX:%c  ", newValue & b ? '1' : '.');
    }
    return 0;
}

static int
cmdTLOG(int argc, char **argv)
{
    uint32_t csr;
    static int isActive, isFirstHB, todBitCount;
    static int rAddr;
    static int addrMask;
    int pass = 0;
    uint32_t gpioIdxEventLogCsr = GPIO_IDX_EVR_TLOG_CSR;
    uint32_t gpioIdxEventLogTicks = GPIO_IDX_EVR_TLOG_TICKS;

    if (argc < 0) {
        if (isActive) {
            GPIO_WRITE(gpioIdxEventLogCsr, 0);
            isActive = 0;
        }
        return 0;
    }
    if (argc > 0) {
        csr = GPIO_READ(gpioIdxEventLogCsr);
        addrMask = ~(~0UL << ((csr >> 24) & 0xF));
        GPIO_WRITE(gpioIdxEventLogCsr, 0x80000000);
        rAddr = 0;
        isActive = 1;
        isFirstHB = 1;
        todBitCount = 0;
        return 0;
    }
    if (isActive) {
        int wAddr, wAddrOld;
        static uint32_t lastHbTicks, lastEvTicks, todShift;
        csr = GPIO_READ(gpioIdxEventLogCsr);
        wAddrOld = csr & addrMask;
        for (;;) {
            csr = GPIO_READ(gpioIdxEventLogCsr);
            wAddr = csr & addrMask;
            if (wAddr == wAddrOld) break;
            if (++pass > 10) {
                printf("Event logger unstable!\n");
                isActive = 0;
                return 0;
            }
            wAddrOld = wAddr;
        }
        for (pass = 0 ; rAddr != wAddr ; ) {
            int event;
            GPIO_WRITE(gpioIdxEventLogCsr, 0x80000000 | rAddr);
            rAddr = (rAddr + 1) & addrMask;
            event = (GPIO_READ(gpioIdxEventLogCsr) >> 16) & 0xFF;
            if (event == 112) {
                todBitCount++;
                todShift = (todShift << 1) | 0;
            }
            else if (event == 113) {
                todBitCount++;
                todShift = (todShift << 1) | 1;
            }
            else {
                uint32_t ticks = GPIO_READ(gpioIdxEventLogTicks);
                switch(event) {
                case 122:
                    if (isFirstHB) {
                        printf("HB\n");
                        isFirstHB = 0;
                    }
                    else {
                        printf("HB %d\n", ticks - lastHbTicks);
                    }
                    lastHbTicks = ticks;
                    break;

                case 125:
                    if (todBitCount == 32) {
                        printf("PPS %d\n", todShift);
                    }
                    else {
                        printf("PPS\n");
                    }
                    todBitCount = 0;
                    break;

                default:
                    printf("%d %d\n", event, ticks - lastEvTicks);
                    lastEvTicks = ticks;
                    break;
                }
            }
            if (++pass >= addrMask) {
                printf("Event logger can't keep up.\n");
                isActive = 0;
                return 0;
            }
        }
        return 1;
    }
    return 0;
}

static void
commandHandler(int argc, char **argv)
{
    int i;
    int len;
    int matched = -1;
    struct commandInfo {
        const char *name;
        int       (*handler)(int argc, char **argv);
        const char *description;
    };
    static struct commandInfo commandTable[] = {
      { "boot",       cmdBOOT,        "Reboot FPGA"                         },
      { "debug",      cmdDEBUG,       "Set debug flags"                     },
      { "dumpscreen", cmdDumpScreen,  "Perform screen dump via console"     },
      { "eyescan",    eyescanCommand, "Perform transceiver eye scan"        },
      { "fmon",       cmdFMON,        "Show clock frequencies"              },
      { "log",        cmdLOG,         "Replay startup console output"       },
      { "mac",        cmdMAC,         "Set Ethernet MAC address"            },
      { "net",        cmdNET,         "Set network parameters"              },
      { "reg",        cmdREG,         "Show GPIO register(s)"               },
      { "showEVIO",   cmdShowEVIO,    "Show EVIO hardware inputs"           },
      { "tlog",       cmdTLOG,        "Timing system event logger"          },
      { "userMGT",    cmdUMGT,        "User MGT reference clock adjustment" },
    };

    if (argc <= 0)
        return;
    len = strlen(argv[0]);
    for (i = 0 ; i < sizeof commandTable / sizeof commandTable[0] ; i++) {
        if (strncasecmp(argv[0], commandTable[i].name, len) == 0) {
            if (matched >= 0) {
                printf("Not unique.\n");
                return;
            }
            matched = i;
        }
    }
    if (matched >= 0) {
        (*commandTable[matched].handler)(argc, argv);
        return;
    }
    if ((strncasecmp(argv[0], "help", len) == 0) || (argv[0][0] == '?')) {
        printf("Commands:\n");
        for (i = 0 ; i < sizeof commandTable / sizeof commandTable[0] ; i++) {
            printf("%8s -- %s\n", commandTable[i].name,
                                  commandTable[i].description);
        }
    }
    else {
        printf("Invalid command\n");
    }
}

static void
handleLine(char *line)
{
    char *argv[10];
    int argc;
    char *tokArg, *tokSave;

    argc = 0;
    tokArg = line;
    while ((argc < (sizeof argv / sizeof argv[0]) - 1)) {
        char *cp = strtok_r(tokArg, " ,", &tokSave);
        if (cp == NULL)
            break;
        argv[argc++] = cp;
        tokArg = NULL;
    }
    argv[argc] = NULL;
    if (modalHandler) {
        (*modalHandler)(argc, argv);
    }
    else {
        commandHandler(argc, argv);
    }
}

/*
 * Check for and act upon character from console
 */
void
consoleCheck(void)
{
    int c;
    static char line[200];
    static int idx = 0;

    if (udpConsole.txIndex != 0) {
        if ((MICROSECONDS_SINCE_BOOT() - udpConsole.usAtFirstOutputCharacter) >
                                                                       100000) {
            udpConsoleDrain();
        }
    }

    /*
     * Startup log display in progress?
     */
    if (showingStartup) {
        static int i;
        if (i < startIdx) {
            outbyte(startBuf[i++]);
        }
        else {
            i = 0;
            showingStartup = 0;
        }
    }

    /*
     * Eye scan in progress?
     */
    if (eyescanCrank()) return;

    /*
     * EVIO validation in progress?
     */
    if (showEVIO) cmdShowEVIO(0, NULL);

    /*
     * See if UART or network has input pending
     */
    if (!XUartLite_IsReceiveEmpty(STDIN_BASEADDRESS)) {
        c = XUartLite_RecvByte(STDIN_BASEADDRESS) & 0xFF;
        udpConsole.active = 0;
        udpConsole.txIndex = 0;
        udpConsole.rxCount = 0;
    }
    else if (udpConsole.rxIndex < udpConsole.rxCount) {
        udpConsole.active = 1;
        c = udpConsole.rxBuf[udpConsole.rxIndex++] & 0xFF;
    }
    else {
        cmdTLOG(0, NULL);
        return;
    }
    /*
     * Terminate an EVIO validation
     */
    if (showEVIO) {
        showEVIO = 0;
        printf("\n");
        return;
    }

    /*
     * Process character
     */
    isStartup = 0;
    if ((c == '\001') || (c > '\177')) return;
    if (c == '\t') c = ' ';
    else if (c == '\177') c = '\b';
    else if (c == '\r') c = '\n';
    if (c == '\n') {
        printf("\n");
        line[idx] = '\0';
        idx = 0;
        handleLine(line);
        return;
    }
    cmdTLOG(-1, NULL);
    if (c == '\b') {
        if (idx) {
            printf("\b \b");
            fflush(stdout);
            idx--;
        }
        return;
    }
    if (c < ' ')
        return;
    if (idx < ((sizeof line) - 1)) {
        printf("%c", c);
        fflush(stdout);
        line[idx++] = c;
    }
}

void
consoleInit(void)
{
    if (bwudpRegisterServer(htons(CONSOLE_UDP_PORT), callbackConsole) < 0) {
        warn("Can't register console server");
    }
}
