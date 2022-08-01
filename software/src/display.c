/*
 * Front panel display
 */

// Top area:
//     Startup screen is event display.
//     Alternate screen is IP address and FPGA temperature.
// Bottom line always date and time, with heartbeat separator.

#include <stdio.h>
#include <stdint.h>
#include <xparameters.h>
#include "display.h"
#include "drawEventLog.h"
#include "eventMonitor.h"
#include "gpio.h"
#include "ssd1331.h"
#include "systemParameters.h"
#include "util.h"
#include "xadc.h"

#define CHAR_FROM_RIGHT(n) (SSD1331_WIDTH+1-(((n)+1) * SSD1331_CHARACTER_WIDTH))
#define LINE_FROM_TOP(n) ((n)*SSD1331_CHARACTER_HEIGHT)

/*
 * Draw hearbeat marker between time and date
 */
static void
drawHeartbeat(void)
{
    int hb = ((GPIO_READ(GPIO_IDX_EVR_MONITOR_CSR) &
                                             EVR_MONITOR_CSR_R_HEARTBEAT) != 0);
    static int hbOld;

    if (hb != hbOld) {
        ssd1331DisplayHeartbeat(CHAR_FROM_RIGHT(8),
                           SSD1331_HEIGHT - (SSD1331_CHARACTER_HEIGHT - 1), hb);
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
    const int top = SSD1331_HEIGHT - (SSD1331_CHARACTER_HEIGHT - 1);

    if (redraw) {
        ssd1331SetCharacterColor(SSD1331_WHITE, SSD1331_BLACK);
        ssd1331DisplayCharacter(CHAR_FROM_RIGHT(18), top, '2');
        ssd1331DisplayCharacter(CHAR_FROM_RIGHT(14), top, '-');
        ssd1331DisplayCharacter(CHAR_FROM_RIGHT(11), top, '-');
        ssd1331DisplayCharacter(CHAR_FROM_RIGHT(5), top, ':');
        ssd1331DisplayCharacter(CHAR_FROM_RIGHT(2), top, ':');
        then = now - 1;
        memset(cbuf, 0, sizeof cbuf);
    }
    else if (now == then) return;
    if (now != (then + 1)) redraw = 1;
    then = now;
    cp = cbuf + 11;
    ssd1331SetCharacterColor(SSD1331_WHITE, SSD1331_BLACK);

    n = now % 60;
    c = (n % 10) + '0';
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(0), top, c);
    c = (n / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(1), top, c);
    if ((n != 0) && !redraw) return;

    n = (now / 60) % 60;
    c = (n % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(3), top, c);
    c = (n / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(4), top, c);
    if ((n != 0) && !redraw) return;

    n = (now / 3600) % 24;
    c = (n % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(6), top, c);
    c = (n / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(7), top, c);
    if ((n != 0) && !redraw) return;

    civil_from_days(now / 86400, &year, &month, &day);
    c = (day % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(9), top, c);
    c = (day / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(10), top, c);
    if ((day != 1) && !redraw) return;

    c = (month % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(12), top, c);
    c = (month / 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(13), top, c);
    if ((month != 1) && !redraw) return;

    c = (year % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(15), top, c);
    c = ((year / 10) % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp-- = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(16), top, c);
    c = ((year / 100) % 10) + '0';
    if ((c == *cp) && !redraw) return;
    *cp = c;
    ssd1331DisplayCharacter(CHAR_FROM_RIGHT(17), top, c);
}

static void
drawMACaddress(int redraw)
{
    if (redraw) {
        char cbuf[24];
        sprintf(cbuf, "%s", formatMAC(&systemParameters.netConfig.ethernetMAC));
        ssd1331DisplayString(0, LINE_FROM_TOP(0), cbuf);
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
        sprintf(cbuf, "%s/%d", formatIP(&systemParameters.netConfig.np.address),                               i);
        ssd1331DisplayString(0, LINE_FROM_TOP(1), cbuf);
    }
}

static void
drawFPGAtemperature(int redraw)
{
    int temp = xadcGetFPGAtemp();
    static int oldTemp;
    static int alarm;
    if (redraw || (temp != oldTemp)) {
        char cbuf[12];
        if (temp < 640) {
            alarm = SSD1331_GREEN;
        }
        else if (temp > 700) {
            alarm = SSD1331_RED;
        }
        else if ((temp > 650)
              && ((alarm == SSD1331_WHITE)
               || ((alarm == SSD1331_RED) && (temp < 690)))) {
            alarm = SSD1331_YELLOW;
        }
        if (alarm == SSD1331_GREEN) {
            ssd1331SetCharacterColor(SSD1331_GREEN, SSD1331_BLACK);
        }
        else {
            ssd1331SetCharacterColor(SSD1331_BLACK, alarm);
        }
        if (temp > 999) {
            temp = 999;
        }
        if (temp < 0) {
            temp = 0;
        }
        sprintf(cbuf, " %2d.%d C ", temp / 10, temp % 10);
        ssd1331DisplayString(0, LINE_FROM_TOP(2), cbuf);
        oldTemp = temp;
        ssd1331SetCharacterColor(SSD1331_WHITE, SSD1331_BLACK);
    }
}

static void
screen0(int redraw)
{
    drawTime(redraw);
    eventMonitorCrank();
    drawHeartbeat();
    eventMonitorCrank();
    drawEventLog(redraw);
}

static void
screen1(int redraw)
{
    uint32_t now = MICROSECONDS_SINCE_BOOT();
    static uint32_t whenDrawn;

    drawTime(redraw);
    eventMonitorCrank();
    drawHeartbeat();
    eventMonitorCrank();
    if (redraw || ((now - whenDrawn) > 1000000)) {
        drawMACaddress(redraw);
        eventMonitorCrank();
        drawIPaddress(redraw);
        eventMonitorCrank();
        drawFPGAtemperature(redraw);
        whenDrawn = now;
    }
}

void
displayCrank(void)
{
    uint32_t now = MICROSECONDS_SINCE_BOOT();
    int redraw= 0;
    int isDown = displaySwitchPressed();
    static int wasDown = -1;
    static uint32_t usWhenDisplayEnabled;
    static int displayIsOn = 1;
    static int activeScreen = -1;
    static void (*screens[])(int) = {
        screen0,
        screen1
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
            ssd1331Enable(0);
            displayIsOn = 0;
        }
    }
    else {
        if (isDown) {
            usWhenDisplayEnabled = now;
            ssd1331Enable(1);
            displayIsOn = 1;
            wasDown = 1;
        }
    }

    /*
     * Multiple pages
     */
    if ((isDown && !wasDown) || (activeScreen < 0)) {
        ssd1331FloodRectangle(0, 0, SSD1331_WIDTH,SSD1331_HEIGHT,SSD1331_BLACK);
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
