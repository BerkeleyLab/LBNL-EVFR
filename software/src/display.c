/*
 * Front panel display
 *  The code is structured in screens and display button allows to switch
 *  among them. The top level is displayCrank() periodically called. The
 *  screens share a common bottom area showing timestamp, IP and icons.
 *      Startup screen is diagnostic display (screen0)
 *      Second one shows incoming events (screen1)
 *      Last screen allows to check optical lowPower status (screen2)
 */



#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include "display.h"
#include "drawEventLog.h"
#include "evio.h"
#include "eventMonitor.h"
#include "gpio.h"
#include "iicProc.h"
#include "st7789v.h"
#include "systemParameters.h"
#include "util.h"
#include "xadc.h"
#include "mmcMailbox.h"

#define CHAR_FROM_RIGHT(n) (COL_COUNT-(((n)+1) * ST7789V_CHARACTER_WIDTH))
#define CHAR_FROM_LEFT(n)                (((n)) * ST7789V_CHARACTER_WIDTH)
#define LINE_FROM_TOP(n)                    ((n)*ST7789V_CHARACTER_HEIGHT)
#define LINE_FROM_BOTTOM(n) (ROW_COUNT - ((n+1)*ST7789V_CHARACTER_HEIGHT))
#define ICON_VERT_OFFSET                                                 0 // pixel from the bottom
#define HEARTHBEAT_HOFF                                                  0 // pixel from right edge
#define FLASH_HOFF                             2 * ST7789V_CHARACTER_WIDTH // pixel from right edge
#define TEMP_SENSOR_NUM                                                  9 // temperature sensor num
#define TEMP_DESC_LENGTH                                                 4 // sensor name length
#define TEMP_STR_LEN                                                    11 // char number per indicator
#define TEMP_STR_VOFF                                                    8 // lines from bottom
#define MAC_STR_VOFF                                   LINE_FROM_BOTTOM(2)
#define MAC_STR_HOFF                                     CHAR_FROM_LEFT(0)
#define MMC_STR_VOFF                                          MAC_STR_VOFF
#define MMC_STR_HOFF                                    CHAR_FROM_LEFT(18)
#define FREQ_STR_VOFF                                                   14 // lines from bottom (header)
#define VOLTAGE_HOFF                                     CHAR_FROM_LEFT(0) // header
#define VOLTAGE_VOFF                                   LINE_FROM_BOTTOM(4) // header
#define FIREFLY_HOFF                                                     9 // pixel from  left
#define FIREFLY_VOFF                                      LINE_FROM_TOP(1)
#define BOX_WIDTH                                                       24 // pixel
#define BOX_OFFSET_X(j)                       FIREFLY_HOFF+j*(BOX_WIDTH+1)
#define BOX_OFFSET_Y(i)                      (2+i%2+(i>>1)*4)*FIREFLY_VOFF
#define EVIO_BOOT_DELAY                                           10000000 // us

/*
    * Temperature sensors wrapper variable
    *   order:  [FPGA, U28, U29, 6x Firefly]
    */
static struct tempInfo_t {
    int32_t tempVal [TEMP_SENSOR_NUM];
    int (*getTemperature[TEMP_SENSOR_NUM])(void);
    char description[TEMP_SENSOR_NUM][TEMP_DESC_LENGTH+1];
    uint16_t x_position [TEMP_SENSOR_NUM];
    uint16_t y_position [TEMP_SENSOR_NUM];
} tempInfo = {
                .getTemperature = {
                                xadcGetFPGAtemp,
                                getU28temperature,
                                getU29temperature,
                                getFireflyTX0temperature,
                                getFireflyRX0temperature,
                                getFireflyTX1temperature,
                                getFireflyRX1temperature,
                                getFireflyTX2temperature,
                                getFireflyRX2temperature},
                .description = {"FPGA\0",
                                " U28\0",
                                " U29\0",
                                "Fly1\0",
                                "Fly2\0",
                                "Fly3\0",
                                "Fly4\0",
                                "Fly5\0",
                                "Fly6\0"},
                .x_position = {10, TEMP_STR_LEN*10, 2*TEMP_STR_LEN*10,// line 1
                                10, TEMP_STR_LEN*10, 2*TEMP_STR_LEN*10,// line 2
                                10, TEMP_STR_LEN*10, 2*TEMP_STR_LEN*10,// line 3
                                },
                .y_position = {ROW_COUNT- (TEMP_STR_VOFF-0)*16, // line 1
                                ROW_COUNT- (TEMP_STR_VOFF-0)*16, // line 1
                                ROW_COUNT- (TEMP_STR_VOFF-0)*16, // line 1
                                ROW_COUNT- (TEMP_STR_VOFF-1)*16, // line 2
                                ROW_COUNT- (TEMP_STR_VOFF-1)*16, // line 2
                                ROW_COUNT- (TEMP_STR_VOFF-1)*16, // line 2
                                ROW_COUNT- (TEMP_STR_VOFF-2)*16, // line 3
                                ROW_COUNT- (TEMP_STR_VOFF-2)*16, // line 3
                                ROW_COUNT- (TEMP_STR_VOFF-2)*16  // line 3
                                }
                };

/*
 * Draw hearbeat marker
 */
static void
drawHeartbeatIndicator(void)
{
    int hb = ((GPIO_READ(GPIO_IDX_EVR_MONITOR_CSR) &
                EVR_MONITOR_CSR_R_HEARTBEAT) != 0);
    static int hbOld;

    static const uint16_t heart[16][18] = {
    { 0x0000,0x0100,0x0580,0x0F41,0x0FC1,0x0F81,0x0600,0x0280,0x0000,0x0000,
      0x0280,0x0600,0x0F81,0x0FC1,0x0F41,0x0580,0x0100,0x0000 },
    { 0x0140,0x0EC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0F81,0x0380,0x0380,
      0x0F81,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0EC1,0x0140 },
    { 0x0580,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0F41,0x0F41,
      0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0580 },
    { 0x0F41,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0F41 },
    { 0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1 },
    { 0x0F81,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0F81 },
    { 0x0F01,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0F01 },
    { 0x0580,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0580 },
    { 0x0200,0x0F81,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0F81,0x0200 },
    { 0x0000,0x0400,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0400,0x0000 },
    { 0x0000,0x0000,0x0440,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0440,0x0000,0x0000 },
    { 0x0000,0x0000,0x0000,0x03C0,0x0F81,0x0FC1,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0FC1,0x0F81,0x03C0,0x0000,0x0000,0x0000 },
    { 0x0000,0x0000,0x0000,0x0000,0x0300,0x0F41,0x0FC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0FC1,0x0F41,0x0300,0x0000,0x0000,0x0000,0x0000 },
    { 0x0000,0x0000,0x0000,0x0000,0x0000,0x01C0,0x0EC1,0x0FC1,0x0FC1,0x0FC1,
      0x0FC1,0x0EC1,0x01C0,0x0000,0x0000,0x0000,0x0000,0x0000 },
    { 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x00C0,0x0E41,0x0FC1,0x0FC1,
      0x0E41,0x00C0,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000 },
    { 0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0040,0x05C0,0x05C0,
      0x0040,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000,0x0000 },
    };

    if (hb != hbOld) {
        const int rows = sizeof heart / sizeof heart[0];
        const int cols = sizeof heart[0] / sizeof heart[0][0];
        const int xs = COL_COUNT - cols - HEARTHBEAT_HOFF;
        const int ys = ROW_COUNT - rows - ICON_VERT_OFFSET;
        if(hb)
            st7789vDrawRectangle(xs, ys, cols, rows, &heart[0][0]);
        else
            st7789vFlood(xs, ys, cols, rows, ST7789V_BLACK);
        hbOld = hb;
    }
}

/*
 * Update time and perhaps date.
 * Draw as little as possible.
 */
static void
drawTime(int redraw)
{
    uint32_t now = GPIO_READ(GPIO_IDX_EVR_SECONDS);
    static uint32_t then;
    int year, month, day;
    int n, c;
    static char cbuf[12]; /* YYYMMDDhhmms */
    char *cp;
    const int top = ROW_COUNT - (ST7789V_CHARACTER_HEIGHT - 1);

    if (redraw) {
        st7789vSetCharacterRGB(ST7789V_WHITE, ST7789V_BLACK);
        st7789vDrawChar(CHAR_FROM_LEFT(0), top, '2');
        st7789vDrawChar(CHAR_FROM_LEFT(4), top, '-');
        st7789vDrawChar(CHAR_FROM_LEFT(7), top, '-');
        st7789vDrawChar(CHAR_FROM_LEFT(13), top, ':');
        st7789vDrawChar(CHAR_FROM_LEFT(16), top, ':');
        then = now - 1;
        memset(cbuf, 0, sizeof cbuf);
    }
    else if (now == then) return;
    if (now != (then + 1)) redraw = 1;
    then = now;
    cp = cbuf + 11;
    st7789vSetCharacterRGB(ST7789V_WHITE, ST7789V_BLACK);

    n = now % 60;
    c = (n % 10) + '0';
    st7789vDrawChar(CHAR_FROM_LEFT(18), top, c);
    c = (n / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(17), top, c);
    if ((n != 0) && !redraw) return;

    n = (now / 60) % 60;
    c = (n % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(15), top, c);
    c = (n / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(14), top, c);
    if ((n != 0) && !redraw) return;

    n = (now / 3600) % 24;
    c = (n % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(12), top, c);
    c = (n / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(11), top, c);
    if ((n != 0) && !redraw) return;

    civil_from_days(now / 86400, &year, &month, &day);
    c = (day % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(9), top, c);
    c = (day / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(8), top, c);
    if ((day != 1) && !redraw) return;

    c = (month % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(6), top, c);
    c = (month / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(5), top, c);
    if ((month != 1) && !redraw) return;

    c = (year % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(3), top, c);
    c = ((year / 10) % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    st7789vDrawChar(CHAR_FROM_LEFT(2), top, c);
    c = ((year / 100) % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp = c;
    st7789vDrawChar(CHAR_FROM_LEFT(1), top, c);
}

static void
drawMACaddress(int redraw) {
    if (redraw) {
        char cbuf[24];
        sprintf(cbuf, "%s", formatMAC(
                    &systemParameters.netConfig.ethernetMAC));
        st7789vShowString(MAC_STR_HOFF,
                          MAC_STR_VOFF, cbuf);
    }
}

static void
drawIPaddress(int redraw)
{
    if (redraw) {
        char cbuf[24];
        const uint8_t *mp = &systemParameters.netConfig.np.netmask.a[3];
        int i = 32, b = 1;
        while ((i > 0) && ((b & *mp) == 0)) {
            i--;
            if (b == 0x80) {
                b = 0x1;
                mp--;
            }
            else {
                b <<= 1;
            }
        }
        sprintf(cbuf, "%s/%d", formatIP(
            &systemParameters.netConfig.np.address),i);
        st7789vShowString(0, LINE_FROM_BOTTOM(1), cbuf);
    }
}

static void
drawMMCfirmware(int redraw) {
    if(redraw) {
        char cbuf [23];
        sprintf(cbuf, "- MMC=%8X", getMMCfirmware());
        st7789vShowString(MMC_STR_HOFF,
                          MMC_STR_VOFF, cbuf);
    }
}

/*
 * Draw the onboard frequencies measured by FPGA. Same ouput as FPGA console
 */

static int
drawFMON(int redraw)
{
    static const char *names[] = { "System",
                                   "MGT reference",
                                   "Event receiver",
                                   "Ethernet Tx",
                                   "Ethernet Rx" };
    if(redraw) {
        st7789vShowString(0, LINE_FROM_BOTTOM(FREQ_STR_VOFF),
                            "Frequencies [MHz]:______________");
        for(uint8_t j=0; j<sizeof names / sizeof names[0]; j++) {
            char cbuf[20];
            sprintf(cbuf, "%16s : ", names[j]);
            st7789vShowString(st7789vCharWidth,
                              LINE_FROM_BOTTOM(FREQ_STR_VOFF-1-j), cbuf);
        }
    }
    for (uint8_t i = 0 ; i < sizeof names / sizeof names[0] ; i++) {
        char cbuf[12];
        GPIO_WRITE(GPIO_IDX_FREQ_MONITOR_CSR, i);
        uint32_t csr = GPIO_READ(GPIO_IDX_FREQ_MONITOR_CSR);
        uint32_t rate = csr & 0xc3FFFFFFF;
        if (csr & 0x80000000) {
            sprintf(cbuf, "%3lu.%03lu", rate / 1000000,
                                        (rate / 1000) % 1000);
        }
        else {
            sprintf(cbuf, "%3lu.%06lu", rate / 1000000, rate % 1000000);
        }
        st7789vShowString(20*st7789vCharWidth,
                          LINE_FROM_BOTTOM(FREQ_STR_VOFF-1-i), cbuf);
    }
    return 0;
}

/*
 * Draw FPGA voltages (miss some voltages)
 * TODO: include INA219 values
 */
static void
drawVoltage(int redraw) {
    /*
     *  ________________________________
     *  VOLTAGES [mV]:
     *  vINT: XXX vAUX: XXXX vBRAM: XXX
     *  ________________________________
     */
    uint32_t xadc_values [2];
    xadcUpdate(xadc_values);
    char cbuf[30];
    static uint32_t vccINT_old, vccAUX_old, vBRAM_old;

    if(redraw) {
        st7789vShowString(VOLTAGE_HOFF, VOLTAGE_VOFF,
                          "Voltages [mV]:__________________");
        st7789vShowString(VOLTAGE_HOFF + ST7789V_CHARACTER_WIDTH,
                          VOLTAGE_VOFF + ST7789V_CHARACTER_HEIGHT,
                          "vINT:     vAUX:      vBRAM:   ");
    }

    uint32_t vccINT = 3000 * (xadc_values[0]>>20) / 4096.0,
             vccAUX = 3000 * ((xadc_values[1]&0xFFFF)>> 4) / 4096.0,
             vBRAM  = 3000 * (xadc_values[1]>>20) / 4096.0;

    if(redraw || vccINT != vccINT_old) {
    sprintf(cbuf,"%4lu", vccINT );
    st7789vShowString(VOLTAGE_HOFF + 6*ST7789V_CHARACTER_WIDTH,
                      VOLTAGE_VOFF + ST7789V_CHARACTER_HEIGHT, cbuf);
    }

    if(redraw || vccAUX != vccAUX_old) {
    sprintf(cbuf,"%4lu", vccAUX );
    st7789vShowString(VOLTAGE_HOFF + 17*ST7789V_CHARACTER_WIDTH,
                      VOLTAGE_VOFF + ST7789V_CHARACTER_HEIGHT, cbuf);
    }

    if(redraw || vBRAM != vBRAM_old) {
    sprintf(cbuf,"%4lu", vBRAM );
    st7789vShowString(VOLTAGE_HOFF + 28*ST7789V_CHARACTER_WIDTH,
                      VOLTAGE_VOFF + ST7789V_CHARACTER_HEIGHT, cbuf);
    }
}

/*
 * Draw temperature defined in tempInfo struct.
 * Text color changes in case of threshold exceeding.
 *  ________________________________
 *  TEMPERATURES [C]:
 *   FPGA XX.X  U28 XX.X  U29 XX.X
 *   Fly1 XX.X Fly2 XX.X Fly3 XX.X
 *   Fly4 XX.X Fly5 XX.X Fly6 XX.X
 *  ________________________________
 */
static void
drawAllTemperature(int redraw )
{
    /* HEADER */
    if(redraw) {
        st7789vSetCharacterRGB(ST7789V_WHITE, ST7789V_BLACK);
        st7789vShowString(0, LINE_FROM_BOTTOM(TEMP_STR_VOFF),
                            "Temperatures [C]:_______________");
        for(uint8_t i=0; i<sizeof(tempInfo.tempVal)/
                        sizeof(tempInfo.tempVal[0]); i++) {
            st7789vShowString(tempInfo.x_position[i],
                              tempInfo.y_position[i],
                              tempInfo.description[i]);
            st7789vShowString(tempInfo.x_position[i]+
                                    (1+TEMP_DESC_LENGTH)*st7789vCharWidth,
                              tempInfo.y_position[i],
                              "--.- ");
        }
    }

    /* Temperature printing */
    for(uint8_t i=0; i<sizeof(tempInfo.tempVal)/
                        sizeof(tempInfo.tempVal[0]); i++) {
        int temp = tempInfo.getTemperature[i]();
        int oldTemp = tempInfo.tempVal[i];
        static int alarm;
        if (redraw || (temp != oldTemp)) {
            char cbuf[7];
            if (temp < 640) {
                alarm = ST7789V_GREEN;
            }
            else if (temp > 700) {
                alarm = ST7789V_RED;
            }
            else if ((temp > 650)
                && ((alarm == ST7789V_WHITE)
                || ((alarm == ST7789V_RED) && (temp < 690)))) {
                alarm = ST7789V_YELLOW;
            }
            if (alarm == ST7789V_GREEN) {
                st7789vSetCharacterRGB(ST7789V_GREEN, ST7789V_BLACK);
            }
            else {
                st7789vSetCharacterRGB(ST7789V_BLACK, alarm);
            }
            if (temp > 999) {
                temp = 999;
            }
            if (temp < 0) {
                temp = 0;
            }
            if (temp <= 0) {
                st7789vSetCharacterRGB(ST7789V_YELLOW, ST7789V_BLACK);
                sprintf(cbuf, " INV");
            }
            else {
                sprintf(cbuf, "%2d.%d ", temp / 10, temp % 10);
            }
            st7789vShowString(tempInfo.x_position[i]+(1+TEMP_DESC_LENGTH)*st7789vCharWidth,
                              tempInfo.y_position[i], cbuf);

        }
        tempInfo.tempVal[i] = temp;
    }
    st7789vSetCharacterRGB(ST7789V_WHITE, ST7789V_BLACK);
}

/*
 * Icon indicator for flash register write protection
 */
static void
drawFlashProtection(int redraw ) {
    uint16_t flashIcon [16][16] = {{  0x0,   0x0,   0x0,   0x0,   0x0, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {  0x0,   0x0,   0x0,   0x0, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {  0x0,   0x0,   0x0, 0x841, 0x841,0xFFC0,0xFFC0, 0x841, 0x841,
    0xFFC0,0xFFC0, 0x841, 0x841,0xFFC0,0xFFC0, 0x841},
    {  0x0,   0x0, 0x841, 0x841, 0x841,0xFFC0,0xFFC0, 0x841, 0x841,
    0xFFC0,0xFFC0, 0x841, 0x841,0xFFC0,0xFFC0, 0x841},
    {  0x0, 0x841, 0x841, 0x841, 0x841,0xFFC0,0xFFC0, 0x841, 0x841,
    0xFFC0,0xFFC0, 0x841, 0x841,0xFFC0,0xFFC0, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841,0xFFC0,0xFFC0, 0x841, 0x841,
    0xFFC0,0xFFC0, 0x841, 0x841,0xFFC0,0xFFC0, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841,0xFFC0,0xFFC0, 0x841, 0x841,
    0xFFC0,0xFFC0, 0x841, 0x841,0xFFC0,0xFFC0, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841},
    {0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841,
     0x841, 0x841, 0x841, 0x841, 0x841, 0x841, 0x841}};

    uint8_t flashProtectionStatus;
    static uint8_t oldStatus = 1<<7;

    iicProcTakeControl();
    iicProcSetMux(6);
    if(!iicProcRead(0x21, 0, &flashProtectionStatus, 1)) {
        if(redraw) {
            const int rows = sizeof flashIcon / sizeof flashIcon[0];
            const int cols = sizeof flashIcon[0] / sizeof flashIcon[0][0];
            const int ys = ROW_COUNT - rows - ICON_VERT_OFFSET;
            const int xs = COL_COUNT - cols - FLASH_HOFF;
            st7789vDrawChar(xs, ys, 'X');
        }
        return;
    }
    iicProcRelinquishControl();
    flashProtectionStatus &= 1<<7;
    if( flashProtectionStatus != oldStatus || redraw ){
        const int rows = sizeof flashIcon / sizeof flashIcon[0];
        const int cols = sizeof flashIcon[0] / sizeof flashIcon[0][0];
        const int ys = ROW_COUNT - rows - ICON_VERT_OFFSET;
        const int xs = COL_COUNT - cols - FLASH_HOFF;

        if(flashProtectionStatus == 0) {
            for( uint8_t i=0; i<rows; i++) {
                flashIcon[i][i] = ST7789V_RED;
                if( i < rows-2) {
                    flashIcon[i][i+1] = ST7789V_RED;
                    flashIcon[i][i+2] = ST7789V_RED;
                }
            }
        }
        st7789vDrawRectangle(xs, ys, cols, rows, &flashIcon[0][0]);
        oldStatus = flashProtectionStatus;
    }
}

/*
 * Draws optical low power indicator tables
 */
void
drawFireflyStatus(int redraw) {
    static uint16_t presence;
    if(redraw) {
        st7789vShowString(CHAR_FROM_RIGHT(17+7), 0, "Low Optical Power");
        presence = getFireflyPresence();
        for(uint8_t i=0; i<2*EVIO_XCVR_COUNT; i++) {
            if(i%2) {
                st7789vShowString(0, LINE_FROM_TOP(1+4*(i>>1)),
                                        "  1      4         8         12");
            }
            st7789vFlood(FIREFLY_HOFF, BOX_OFFSET_Y(i), // upline
                       COL_COUNT-2*FIREFLY_HOFF-1, 1,
                        ((presence>>(5-i))&1) ? ST7789V_WHITE : ST7789V_RED);
            st7789vFlood(FIREFLY_HOFF, BOX_OFFSET_Y(i)+FIREFLY_VOFF, // downline
                        COL_COUNT-2*FIREFLY_HOFF-1, 1,
                        ((presence>>(5-i))&1) ? ST7789V_WHITE : ST7789V_RED);
            for(uint8_t j=0; j<=CHANNELS_PER_FIREFLY; j++) {
                // horizontal box edges
                st7789vFlood(BOX_OFFSET_X(j), BOX_OFFSET_Y(i),
                        1, ST7789V_CHARACTER_HEIGHT,
                        ((presence>>(5-i))&1) ? ST7789V_WHITE : ST7789V_RED);
            }
        }
    }
    for (uint8_t i=0; i<EVIO_XCVR_COUNT; i++) {
        uint16_t rxLowPower = getFireflyRxLowPower(i);
        for (uint8_t j=0; j<CHANNELS_PER_FIREFLY; j++) {
            if(presence == 0 || MICROSECONDS_SINCE_BOOT()<EVIO_BOOT_DELAY) {
                return;
            }
            st7789vFlood(BOX_OFFSET_X(j)+1,
                         BOX_OFFSET_Y(2*i)+ST7789V_CHARACTER_HEIGHT+1,
                         BOX_WIDTH, ST7789V_CHARACTER_HEIGHT-1,
                        ((rxLowPower>>j)&0x1) ? ST7789V_RED : ST7789V_GREEN);
        }
    }
    return;
}

/*
 * Bottom line in common for all the screens
 */
static void
bottomLine(int redraw) {
    drawTime(redraw);
    eventMonitorCrank();
    drawHeartbeatIndicator();
    eventMonitorCrank();
    drawFlashProtection(redraw);
    eventMonitorCrank();
    drawIPaddress(redraw);
    eventMonitorCrank();
}

static void
screen1(int redraw) {
    bottomLine(redraw);
    drawEventLog(redraw);
}

static void
screen0(int redraw) {
    uint32_t now = MICROSECONDS_SINCE_BOOT();
    static uint32_t whenDrawn;

    bottomLine(redraw);
    if (redraw || ((now - whenDrawn) > 1000000)) {
        drawMACaddress(redraw);
        eventMonitorCrank();
        drawMMCfirmware(redraw);
        eventMonitorCrank();
        eventMonitorCrank();
        drawFMON(redraw);
        eventMonitorCrank();
        drawAllTemperature(redraw);
        eventMonitorCrank();
        drawVoltage(redraw);
        whenDrawn = now;
    }
}


static void
screen2(int redraw) {

    uint32_t now = MICROSECONDS_SINCE_BOOT();
    static uint32_t whenDrawn;
    bottomLine(redraw);
    if (redraw || ((now - whenDrawn) > 1000000)) {
        drawFireflyStatus(redraw);
        whenDrawn = now;
    }
}

void
displayCrank(void) {
    uint32_t now = MICROSECONDS_SINCE_BOOT();
    int redraw= 0;
    int isDown = displaySwitchPressed();
    static int wasDown = -1;
    static uint32_t usWhenDisplayEnabled;
    static int displayIsOn = 1;
    static int activeScreen = -1;
    static void (*screens[])(int) = {
        screen0,
        screen1,
        screen2
    };


    /*
     * Allow remote 'button presses'
     */
    if (debugFlags & DEBUGFLAG_DISPLAY_PRESS) {
        debugFlags &= ~DEBUGFLAG_DISPLAY_PRESS;
        isDown = 1;
    }

    /*
     * Extend OLED life by turning display off after a while
     */
    if (displayIsOn) {
        if ((now - usWhenDisplayEnabled) > (20*60*1000000)) {
            st7789vBacklightEnable(0);
            displayIsOn = 0;
        }
    }
    else {
        if (isDown) {
            usWhenDisplayEnabled = now;
            st7789vBacklightEnable(1);
            displayIsOn = 1;
            wasDown = 1;
        }
    }

    /*
     * Multiple pages
     */
    if ((isDown && !wasDown) || (activeScreen < 0)) {
        st7789vFlood(0, 0, COL_COUNT, ROW_COUNT, 0);
        redraw = 1;
        if (activeScreen >= ((sizeof screens / sizeof screens[0]) - 1)) {
            activeScreen = 0;
        }
        else {
            activeScreen++;
        }
    }
    screens[activeScreen](redraw);
    wasDown = isDown;
}
