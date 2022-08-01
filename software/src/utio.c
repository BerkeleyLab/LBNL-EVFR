/*
 * Communicate with PLL and other I2C devices on UTIO board
 */
#include <stdio.h>
#include <stdint.h>
#include "gpio.h"
#include "iicFMC2.h"
#include "util.h"
#include "utio.h"

/*
 * 7 bit I2C addresses
 */
#define ADT7410A_ADDRESS    0x48
#define ADT7410B_ADDRESS    0x49
#define AD9520_ADDRESS      0x5C
#define LTC2945A_ADDRESS    0x6B
#define LTC2945B_ADDRESS    0x6E

#define ADT7410_TCHAN  0x00
#define LTC2945_CONFIG 0x00
#define LTC2945_ICHAN  0x14
#define LTC2945_VCHAN  0x1E
#define LTC2945_ADCHAN 0x28

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
struct utioIIC {
    uint8_t address;
    uint8_t subaddress;
    uint8_t cbuf[2];
};
static struct utioIIC utioTable[] = {
    { .address = LTC2945A_ADDRESS, .subaddress = LTC2945_ICHAN },
    { .address = LTC2945A_ADDRESS, .subaddress = LTC2945_VCHAN },
    { .address = LTC2945B_ADDRESS, .subaddress = LTC2945_ICHAN },
    { .address = LTC2945B_ADDRESS, .subaddress = LTC2945_VCHAN },
    { .address = ADT7410A_ADDRESS, .subaddress = ADT7410_TCHAN },
    { .address = ADT7410B_ADDRESS, .subaddress = ADT7410_TCHAN },
};

void
utioCrank(void)
{
    uint32_t now = MICROSECONDS_SINCE_BOOT();
    struct utioIIC *up;
    static int idx;
    static uint32_t whenDone;
    if (idx == 0) {
        if ((now - whenDone) < 2000000) {
            return;
        }
    }
    up = &utioTable[idx];
    iicFMC2recv(up->address, up->subaddress, up->cbuf, 2);
    if (++idx == (sizeof utioTable / sizeof utioTable[0])) {
        whenDone = now;
        idx = 0;
    }
}

/*
 * Read back system monitor points
 */
uint32_t *
utioFetchSysmon(uint32_t *ap)
{
    int i;
    /*
     * Return LTC2945 voltage and current readings
     * then ADT7410 temperature readings.
     *
     */
    for (i = 0 ; i < 6 ; i += 2) {
        *ap++ = (utioTable[i+0].cbuf[0] << 24) |
                (utioTable[i+0].cbuf[1] << 16) |
                (utioTable[i+1].cbuf[0] <<  8) |
                 utioTable[i+1].cbuf[1];
    }
    return ap;
}

/*
 * Initialize UTIO devices
 */
void
utioInit(void)
{
    unsigned char v;

    /*
     * Reset PLL
     */
    GPIO_WRITE(GPIO_IDX_EVR_SELECT_OUTPUT, 0x8000000);
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
