/*
 * Event receiver I/O
 */
#include <stdio.h>
#include <stdint.h>
#include "evfrProtocol.h"
#include "iicFMC2.h"
#include "evrio.h"
#include "gpio.h"
#include "util.h"

/*
 * 7 bit I2C addresses
 */
#define ADT7410A_ADDRESS    0x48
#define ADT7410B_ADDRESS    0x49
#define AD9520_ADDRESS      0x5C
#define LTC2945A_ADDRESS    0x6B
#define LTC2945B_ADDRESS    0x6E

/*
 * SysMon internal Registers
 */
#define ADT7410_TCHAN  0x00
#define LTC2945_CONFIG 0x00
#define LTC2945_ICHAN  0x14
#define LTC2945_VCHAN  0x1E
#define LTC2945_ADCHAN 0x28

/*
 * EVR configuration
 */
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

/*
 * Write an AD9520 register
 */
static void
ad9520set(unsigned int reg, int value)
{
    unsigned char v[3];
    v[0] = reg >> 8;
    v[1] = reg;
    v[2] = value;
    iicFMC2send(AD9520_ADDRESS, -1, v, 3);
}

/*
 * Read an AD9520 register
 */
static int
ad9520get(unsigned int reg)
{
    unsigned char v[2];
    v[0] = reg >> 8;
    v[1] = reg;
    iicFMC2send(AD9520_ADDRESS, -1, v, 2);
    iicFMC2recv(AD9520_ADDRESS, -1, v, 1);
    return v[0];
}

void
ad9520show(void)
{
    int r;

    printf("PLL (AD9520) configuration:\n");
    for (r = 0 ; r <= 0x232 ; r++) {
        if (((r >= 0x001) && (r <= 0x002))
         || ((r >= 0x007) && (r <= 0x00F))
         || ((r >= 0x020) && (r <= 0x0EF))
         || ((r >= 0x0FE) && (r <= 0x18F))
         || ((r >= 0x19C) && (r <= 0x1DF))
         || ((r >= 0x1E2) && (r <= 0x22F))
         || (r == 0x231))
            continue;
        printf("%03X: %02X\n", r, ad9520get(r));
    }
}

int
ad9520RegIO(int idx, unsigned int value)
{
    static int registerIndex;

    if (idx) {
        ad9520set(registerIndex, value);
    }
    else {
        registerIndex = value & 0xFFF;
        value = ad9520get(registerIndex);
    }
    return value;
}

static void
ad9520Table(void)
{
    int i, regCount, reg0x018 = -1;
    const uint16_t *sp;
    #include "ad9520Tables.h"

    sp = pt0table;
    regCount = sizeof(pt0table) / 4;
    for (i = 0 ; i < regCount ; i++) {
        int reg = *sp++;
        int value = *sp++;
        if (reg == 0x018) {
            /*
             * VCO calibration requires a 0->1 transition
             * of the least-signficant bit of this register
             * so make sure it's a 0 here
             */
            value &= ~0x01;
            reg0x018 = value;
        }
        ad9520set(reg, value);
    }
    ad9520set(0x232, 0x01);

    /*
     * Perform VCO calibration
     */
    if (reg0x018 >= 0) {
        ad9520set(0x18, reg0x018 | 0x01);
    }
    ad9520set(0x232, 0x01);
}

/*
 * Reading IIC is fairly slow
 * Keep processing loop latency down by doing operations one at a time.
 */
struct evrioIIC {
    uint8_t address;
    uint8_t subaddress;
    uint8_t cbuf[2];
};
static struct evrioIIC evrioTable[] = {
    { .address = LTC2945A_ADDRESS, .subaddress = LTC2945_ICHAN },
    { .address = LTC2945A_ADDRESS, .subaddress = LTC2945_VCHAN },
    { .address = LTC2945B_ADDRESS, .subaddress = LTC2945_ICHAN },
    { .address = LTC2945B_ADDRESS, .subaddress = LTC2945_VCHAN },
    { .address = ADT7410A_ADDRESS, .subaddress = ADT7410_TCHAN },
    { .address = ADT7410B_ADDRESS, .subaddress = ADT7410_TCHAN },
};

void
evrioCrank(void)
{
    uint32_t now = MICROSECONDS_SINCE_BOOT();
    struct evrioIIC *up;
    static int idx;
    static uint32_t whenDone;
    if (idx == 0) {
        if ((now - whenDone) < 2000000) {
            return;
        }
    }
    up = &evrioTable[idx];
    iicFMC2recv(up->address, up->subaddress, up->cbuf, 2);
    if (++idx == (sizeof evrioTable / sizeof evrioTable[0])) {
        whenDone = now;
        idx = 0;
    }
}

/*
 * Read back system monitor points
 */
uint32_t *
evrioFetchSysmon(uint32_t *ap)
{
    int i;
    /*
     * Return LTC2945 voltage and current readings
     * then ADT7410 temperature readings.
     *
     */
    for (i = 0 ; i < 6 ; i += 2) {
        *ap++ = (evrioTable[i+0].cbuf[0] << 24) |
                (evrioTable[i+0].cbuf[1] << 16) |
                (evrioTable[i+1].cbuf[0] <<  8) |
                 evrioTable[i+1].cbuf[1];
    }
    return ap;
}

/*
 * Initialize EVRIO devices
 */
void
evrioInit(void)
{
    unsigned char v;

    /*
     * Reset PLL and OSERDES
     */
    GPIO_WRITE(GPIO_IDX_EVR_SELECT_OUTPUT, 0x80000000);
    microsecondSpin(100);
    GPIO_WRITE(GPIO_IDX_EVR_SELECT_OUTPUT, 0x0);
    microsecondSpin(20000);

    /*
     * Set up PLL
     */
    iicFMC2init();
    ad9520Table();

    /* Configure power monitors */
    v = 0x05;
    iicFMC2send(LTC2945A_ADDRESS, LTC2945_CONFIG, &v, 1);
    iicFMC2send(LTC2945B_ADDRESS, LTC2945_CONFIG, &v, 1);
}

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
