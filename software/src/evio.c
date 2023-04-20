/*
 * Support for EVIO FMC card components:
 *  ADN4605 40x40 crosspoint switch
 *  Firefly optical I/O modules
 * Maintains the same AXI IIC GPO layout as the event generator version of this
 * code even though the fmcIndex is not needed for the event fanout since there
 * is only one EVIO board.
 */

#include <stdio.h>
#include "evio.h"
#include "iicEVIO.h"
#include "iicProc.h"
#include "gpio.h"
#include "util.h"

/*
 * Crosspoint switch port assignments
 *   Port 0 is unused.
 *   Ports [1:36] correspond to front panel fiber pairs [1:36].
 *   Port 37 is the FPGA MGT.
 *   Port 38 is the FPGA MGT reference clock (output only).
 *   Port 39 is the FPGA fabric reference clock (output only).
 */
#define XPOINT_IO_UNUSED        0
#define XPOINT_IO_FIRST_FIREFLY 1
#define XPOINT_IO_LAST_FIREFLY  (XPOINT_IO_FIRST_FIREFLY + \
                                   (EVIO_XCVR_COUNT * CHANNELS_PER_FIREFLY) - 1)
#define XPOINT_IO_FMC_DP0       (XPOINT_IO_LAST_FIREFLY + 1)
#define XPOINT_OUT_FMC_GBTCLK0  (XPOINT_IO_FMC_DP0 + 1)
#define XPOINT_OUT_FMC_CLK0_M2C (XPOINT_OUT_FMC_GBTCLK0 + 1)
#define XPOINT_CHANNEL_COUNT 40

#define FIREFLY_REG_PWR_LO      14
#define FIREFLY_REG_TEMPERATURE 22
#define FIREFLY_REG_VCC_HI      26
#define FIREFLY_REG_VCC_LO      27
#define FIREFLY_REG_RX_CHANNEL_DISABLE_HI   52
#define FIREFLY_REG_RX_CHANNEL_DISABLE_LO   53
#define FIREFLY_REG_RX_OUTPUT_DISABLE_HI    54
#define FIREFLY_REG_RX_OUTPUT_DISABLE_LO    55

static struct fireflyStatus {
    uint8_t     isPresent;
    int8_t      temperature;
    uint16_t    vcc;
    uint16_t    rxLowPower;
    uint16_t    rxEnable;
} fireflyStatus[EVIO_XCVR_COUNT][2]; /* [0]=Tx, [1]=Rx */
static unsigned int fmcPresent;

/*
 * Crosspoint switch
 */
#define XP_REG_RESET                0x00
# define XP_RESET 0x1
#define XP_REG_UPDATE               0x01
# define XP_UPDATE 0x1
#define XP_REG_MAP_SELECT           0x02
#define XP_REG_TX_HEADROOM          0xBB
#define XP_REG_OUTPUT_CONNECT(n)    (0x04+(n))
#define XP_REG_OUTPUT_STATUS(n)     (0x54+(n))
#define XP_REG_RX_SIGN_CONTROL(n)   (0xCB+((n)/8))
#define XP_REG_TX_SIGN_CONTROL(n)   (0xA9+((n)/8))
# define XP_SIGN_BIT(n)             (0x1<<((n)%8))
#define XP_REG_OUTPUT_ENABLE(n)     (0xB0+((n)/4))
# define XP_OUTPUT_ENABLE_BITS(n)   (0x3<<(((n)%4)*2))
# define XP_OUTPUT_ENABLED(n,v)     (((v)>>(((n)%4)*2))&0x3)
#define XP_REG_TX_TERM_CONTROL(n)   (0xBC+((n)/20))
#define XP_REG_RX_TERM_CONTROL(n)   (0xD0+((n)/20))
# define XP_TERM_ENABLE_BIT(n)      (0x1<<(((n)/4)%5))
#define XP_REG_RX_EQ_BOOST(n)       (0xC0+((n)/4))
# define XP_RX_EQ_BOOST_WR(n,v)     ((v)<<(((n)%4)*2))
# define XP_RX_EQ_BOOST_RD(n,v)     (((v)>>(((n)%4)*2)) & 0x3)
# define XP_RX_EQ_DISABLE_RX 0x0
# define XP_RX_EQ_3_DB       0x1
# define XP_RX_EQ_MASK       0x3

/*
 * Card device IIC addresses (7-bit)
 */
#define IIC_ADDRESS_ADN4605    0x48
#define IIC_ADDRESS_FIREFLY_TX 0x50
#define IIC_ADDRESS_FIREFLY_RX 0x54

static void
iicSelect(int fireflyIndex)
{
    int sel = 0;
    if (fireflyIndex >= 0) {
        sel |= 1 << (fireflyIndex + 1);
    }
    iicEVIOsetGPO(sel);
}

static int
xpWriteReg(int reg, int value)
{
    unsigned char v = value;
    iicSelect(-1);
    return (iicEVIOsend(IIC_ADDRESS_ADN4605, reg, &v, 1) >= 0);
}

static int
xpReadReg(int reg)
{
    unsigned char v;
    iicSelect(-1);
    if (iicEVIOrecv(IIC_ADDRESS_ADN4605, reg, &v, 1) < 0) return -1;
    return v;
}

/*
 * Drive specified output from specified input
 */
static int
xpOutFromIn(unsigned int outputIndex, unsigned int inputIndex)
{
    if ((outputIndex >= XPOINT_CHANNEL_COUNT)
     || (inputIndex >= XPOINT_CHANNEL_COUNT)) return 0;
    return (xpWriteReg(XP_REG_OUTPUT_CONNECT(outputIndex), inputIndex)
         && xpWriteReg(XP_REG_UPDATE, XP_UPDATE));
}

/*
 * Enable specified output
 */
static int
xpEnableOutput(unsigned int outputIndex)
{
    int r, v, b;
    if (outputIndex >= XPOINT_CHANNEL_COUNT) return 0;
    r = XP_REG_OUTPUT_ENABLE(outputIndex);
    b = XP_OUTPUT_ENABLE_BITS(outputIndex);
    v = xpReadReg(r);
    if (v < 0) return 0;
    v |= b;
    return xpWriteReg(r, v);
}

/*
 * Set receiver equalization
 */
static int
xpSetRxEqualization(unsigned int inputIndex, int eq)
{
    int r, v, bits, mask;
    r = XP_REG_RX_EQ_BOOST(inputIndex);
    bits = XP_RX_EQ_BOOST_WR(inputIndex, eq);
    mask = XP_RX_EQ_BOOST_WR(inputIndex, XP_RX_EQ_MASK);
    v = xpReadReg(r);
    if (v < 0) return 0;
    v = (v & ~mask) | (bits & mask);
    return xpWriteReg(r, v);
}

static int
xpReset(void)
{
    return xpWriteReg(XP_REG_RESET, XP_RESET);
}

static void
fireflyRxLoopbackEnable(int receiverChannel)
{
    int xcvrIndex, loopbackTransceiver = -1;
    uint8_t cbuf[4];

    if ((receiverChannel > XPOINT_IO_FIRST_FIREFLY)
     && (receiverChannel <= XPOINT_IO_LAST_FIREFLY)) {
        loopbackTransceiver = (receiverChannel - XPOINT_IO_FIRST_FIREFLY) /
                                                           CHANNELS_PER_FIREFLY;
    }

    /*
     * Disable everything but the upstream link (first) and loopback channel.
     */
    for (xcvrIndex = 0 ; xcvrIndex < EVIO_XCVR_COUNT ; xcvrIndex++) {
        struct fireflyStatus *fs = &fireflyStatus[xcvrIndex][1];
        fs->rxEnable = (xcvrIndex == 0) ? 0x1 : 0x0;
        if (xcvrIndex == loopbackTransceiver) {
            fs->rxEnable |= 1 << ((receiverChannel - XPOINT_IO_FIRST_FIREFLY) %
                                                          CHANNELS_PER_FIREFLY);
        }
        if (fs->isPresent) {
            int bitmap = ~fs->rxEnable & ((1 << CHANNELS_PER_FIREFLY) - 1);
            cbuf[0] = bitmap >> 8;
            cbuf[1] = bitmap;
            cbuf[2] = cbuf[0];
            cbuf[3] = cbuf[1];
            iicSelect(xcvrIndex);
            iicEVIOsend(IIC_ADDRESS_FIREFLY_RX,
                                    FIREFLY_REG_RX_CHANNEL_DISABLE_HI, cbuf, 4);
        }
    }
}

void
evioInit(void)
{
    const char *name;
    uint32_t presentBits;
    int txCount = 0;
    int xpChannel, isRx;
    int i;

    /*
     * Validate FMC card
     */
    name = iicProcFMCproductType(0);
    if (strcmp(name, "EVIO") == 0) {
        fmcPresent = 1;
    }
    else {
        warn("Critical -- Missing/Improper FMC card");
        return;
    }
    iicEVIOinit();

    /*
     * Detect firefly modules
     */
    presentBits = ~GPIO_READ(GPIO_IDX_FMC1_FIREFLY);
    for (i = 0 ; i < EVIO_XCVR_COUNT ; i++) {
        for (isRx = 0 ; isRx < 2 ; isRx++) {
            fireflyStatus[i][isRx].isPresent = presentBits>>((i*2)+isRx) & 0x1;
        }
        if (fireflyStatus[i][0].isPresent) {
            txCount++;
        }
    }
    if (!(hwConfig & HWCONFIG_HAS_QSFP2)) {
        if (!fireflyStatus[0][1].isPresent) {
            warn("Critical -- EVIO has no RF reference receiver");
        }
        if (txCount == 0) {
            warn("Critical -- EVIO has no transmitters");
        }
    }

    /*
     * Reset crosspoint -- disables all I/O, enables all terminations
     */
    if (!xpReset()) {
        warn("Critical -- EVIOC bad crosspoint switch");
        return;
    }

    /*
     * Route event links
     */
    xpSetRxEqualization(XPOINT_IO_FIRST_FIREFLY, XP_RX_EQ_3_DB);
    for (xpChannel = XPOINT_IO_FIRST_FIREFLY ;
                        xpChannel <= XPOINT_IO_LAST_FIREFLY ; xpChannel++) {
        int ffIdx;
        ffIdx = (xpChannel-XPOINT_IO_FIRST_FIREFLY) / CHANNELS_PER_FIREFLY;
        if (fireflyStatus[ffIdx][0].isPresent) {
            xpOutFromIn(xpChannel, XPOINT_IO_FIRST_FIREFLY);
            xpEnableOutput(xpChannel);
        }
    }

    /*
     * XPOINT_IO_FMC_DP0 is special. Output first firefly so FPGA
     * can monitor the event stream
     */
    xpOutFromIn(XPOINT_IO_FMC_DP0, XPOINT_IO_FIRST_FIREFLY);
    xpEnableOutput(XPOINT_IO_FMC_DP0);

    /*
     * Set loopback for the receiving upstream stream
     */
    evioSetLoopback(XPOINT_IO_FIRST_FIREFLY);

    /*
     * Show xpoint mapping
     */
    evioShowCrosspointRegisters();
}

/*
 * Loop back specified channel
 * Disable unused crosspoint receiver inputs
 */
void
evioSetLoopback(int loopbackChannel)
{
    static int oldLoopback = XPOINT_IO_FIRST_FIREFLY - 1;
    if (fmcPresent && (loopbackChannel != oldLoopback)) {
        if ((oldLoopback >  XPOINT_IO_FIRST_FIREFLY)
         && (oldLoopback <= XPOINT_IO_LAST_FIREFLY)) {
            xpSetRxEqualization(oldLoopback, XP_RX_EQ_DISABLE_RX);
        }
        if ((loopbackChannel >  XPOINT_IO_FIRST_FIREFLY)
         && (loopbackChannel <= XPOINT_IO_LAST_FIREFLY)) {
            xpSetRxEqualization(loopbackChannel, XP_RX_EQ_3_DB);
            fireflyRxLoopbackEnable(loopbackChannel);
        }
        else {
            loopbackChannel = XPOINT_IO_FMC_DP0;
        }
        xpOutFromIn(XPOINT_IO_FIRST_FIREFLY, loopbackChannel);
        oldLoopback = loopbackChannel;
    }
}

void
evioCrank(void)
{
    static int isActive;
    static int xcvrIndex, isRx;
    static uint32_t whenIdle;

    if (isActive) {
        struct fireflyStatus *fs = &fireflyStatus[xcvrIndex][isRx];
        if (fs->isPresent) {
            uint8_t cbuf[FIREFLY_REG_VCC_LO - FIREFLY_REG_PWR_LO + 1];
            iicSelect(xcvrIndex);
            iicEVIOrecv(isRx ? IIC_ADDRESS_FIREFLY_RX : IIC_ADDRESS_FIREFLY_TX,
                                   FIREFLY_REG_PWR_LO, cbuf,
                                   FIREFLY_REG_VCC_LO - FIREFLY_REG_PWR_LO + 1);
            fs->temperature = cbuf[FIREFLY_REG_TEMPERATURE-FIREFLY_REG_PWR_LO];
            fs->vcc = (cbuf[FIREFLY_REG_VCC_HI - FIREFLY_REG_PWR_LO] << 8)
                     | cbuf[FIREFLY_REG_VCC_LO - FIREFLY_REG_PWR_LO];
            if (isRx) {
                int i, idx = 0, bit = 0x40;
                int bitmap = 0;
                for (i = 0 ; i < CHANNELS_PER_FIREFLY ; i++) {
                    bitmap = (bitmap << 1) | ((cbuf[idx] & bit) != 0);
                    bit >>= 2;
                    if (bit == 0) {
                        idx++;
                        bit = 0x40;
                    }
                }
                fs->rxLowPower = bitmap;
            }
        }
        if (isRx) {
            isRx = 0;
            if (xcvrIndex == (EVIO_XCVR_COUNT - 1)) {
                xcvrIndex = 0;
                isActive = 0;
                whenIdle = MICROSECONDS_SINCE_BOOT();
            }
            else {
                xcvrIndex++;
            }
        }
        else {
            isRx = 1;
        }
    }
    else {
        if ((MICROSECONDS_SINCE_BOOT() - whenIdle) > 10000000) {
            isActive = 1;
        }
    }
}

uint32_t *
evioFetchSysmon(uint32_t *ap)
{
    int xcvrIndex, isRx;
    struct fireflyStatus *fs;
    for (xcvrIndex = 0 ; xcvrIndex < EVIO_XCVR_COUNT ; xcvrIndex++) {
        for (isRx = 0 ; isRx < 2 ; isRx++) {
            fs = &fireflyStatus[xcvrIndex][isRx];
            *ap++ = (fs->temperature << 16) | fs->vcc;
        }
    }
    for (xcvrIndex = 0 ; xcvrIndex < EVIO_XCVR_COUNT ; xcvrIndex++) {
        fs = &fireflyStatus[xcvrIndex][1];
        *ap++ = (fs->rxLowPower << 16) | fs->rxEnable;
    }
    return ap;
}

static void
fireflyDumpPage(int isRx, int base)
{
    int i, j;
    uint8_t cbuf[16];
    for (i = 0 ; i < 128 ; i += 16) {
        iicEVIOrecv((isRx ? IIC_ADDRESS_FIREFLY_RX : IIC_ADDRESS_FIREFLY_TX),
                                                            base + i, cbuf, 16);
        printf("%3d:", base + i);
        for (j = 0 ; j < 16 ; j++) {
            printf(" %02X", cbuf[j]);
        }
        printf("  ");
        for (j = 0 ; j < 16 ; j++) {
            int c = cbuf[j];
            if ((c < ' ') || (c > '~')) c = ' ';
            printf("%c", c);
        }
        printf("\n");
    }
}

static void
fireflyShowAll(void)
{
    int xcvrIdx, isRx, pgIdx;
    static const uint8_t pgMap[] = { 0x00, 0x01, 0x0B };
    for (isRx = 0 ; isRx < 2 ; isRx++) {
        for (xcvrIdx = 0 ; xcvrIdx < EVIO_XCVR_COUNT ; xcvrIdx++) {
            struct fireflyStatus *fs = &fireflyStatus[xcvrIdx][isRx];
            if (!fs->isPresent) {
                continue;
            }
            printf("XCVR:%d  %cx\n", xcvrIdx, isRx?'R':'T');
            iicSelect(xcvrIdx);
            fireflyDumpPage(isRx, 0);
            for (pgIdx = 0 ; pgIdx < sizeof pgMap/sizeof pgMap[0] ; pgIdx++) {
                printf(" Page %02X:\n", pgMap[pgIdx]);
                iicEVIOsend((isRx ? IIC_ADDRESS_FIREFLY_RX :
                                IIC_ADDRESS_FIREFLY_TX), 127, &pgMap[pgIdx], 1);
                microsecondSpin(600000);
                fireflyDumpPage(isRx, 128);
            }
            iicEVIOsend((isRx ? IIC_ADDRESS_FIREFLY_RX :
                                IIC_ADDRESS_FIREFLY_TX), 127, &pgMap[0], 1);
        }
    }
}

void
evioShowCrosspointRegisters(void)
{
    int i;
    uint8_t txAssignment, txSign, txEnReg, txEn, txTerm;
    uint8_t rxEqReg, rxEq, rxSign, rxTerm;

    if (!fmcPresent) {
        return;
    }
    printf("Map %d enabled, TxHeadroom %sabled\n",
                                  xpReadReg(XP_REG_MAP_SELECT),
                                  xpReadReg(XP_REG_TX_HEADROOM) ? "en" : "dis");
    printf("Output Source  TXen TXsign TXterm  RXeq RXsign RXterm\n");
    for (i = 0 ; i < XPOINT_CHANNEL_COUNT ; i++) {
        txAssignment = xpReadReg(XP_REG_OUTPUT_STATUS(i));
        txSign = ((xpReadReg(XP_REG_TX_SIGN_CONTROL(i)) & XP_SIGN_BIT(i)) != 0);
        rxSign = ((xpReadReg(XP_REG_RX_SIGN_CONTROL(i)) & XP_SIGN_BIT(i)) != 0);
        txEnReg = xpReadReg(XP_REG_OUTPUT_ENABLE(i));
        txEn = XP_OUTPUT_ENABLED(i, txEnReg);
        txTerm = ((xpReadReg(XP_REG_TX_TERM_CONTROL(i)) &
                                                   XP_TERM_ENABLE_BIT(i)) != 0);
        rxTerm = ((xpReadReg(XP_REG_RX_TERM_CONTROL(i)) &
                                                   XP_TERM_ENABLE_BIT(i)) != 0);
        rxEqReg = xpReadReg(XP_REG_RX_EQ_BOOST(i));
        rxEq = XP_RX_EQ_BOOST_RD(i, rxEqReg);
        printf("%4d     %2d      %d     %d      %d      %d     %d      %d\n",
                                          i, txAssignment, txEn, txSign, txTerm,
                                          rxEq, rxSign, rxTerm);
    }
    for (i = 0 ; i < EVIO_XCVR_COUNT ; i++) {
        if(fireflyStatus[i][1].isPresent) {
            printf("Firefly %d low Rx power: %03X\n", i,
                                                fireflyStatus[i][1].rxLowPower);
        }
    }
}

/* 
 * Everytimes is called returns a different temperature value, starting from TX0 
 */
int
getFireflyTemperature(void) {
    static uint8_t fireflyNumber = 0; 
    static uint8_t rxtx_index = 0;
    return 10*fireflyStatus[((rxtx_index%2)? 
                                fireflyNumber++:
                                fireflyNumber)%EVIO_XCVR_COUNT]
                         [(rxtx_index++)%2].temperature;
}

/* return variable bit organization:
 *  | 5th  | 4th  | 3th  | 2th  | 1th  | 0th  |
 *  | bit  | bit  | bit  | bit  | bit  | bit  |
 *  |[0][0]|[0][1]|[1][0]|[1][1]|[2][0]|[2][1]|
 */
uint16_t
getFireflyPresence(void) {
    uint16_t presence = 0;
    for(uint8_t i=0; i<2*EVIO_XCVR_COUNT; i++) {
        presence |= (fireflyStatus[i>>1][i&0x1].isPresent) << i;
    }
    return presence;
}

uint16_t
getFireflyRxLowPower(uint8_t index) {
    return fireflyStatus[index%EVIO_XCVR_COUNT][1].rxLowPower;
}