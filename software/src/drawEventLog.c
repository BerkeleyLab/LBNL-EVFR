/*
 * Show events as they occur
 */

#include <stdio.h>
#include <stdint.h>
#include "drawEventLog.h"
#include "evio.h"
#include "gpio.h"
#include "ssd1331.h"
#include "util.h"

/* FIXME: Should this be settable?  System parameter?  EPICS PV? */
#define DISPLAY_USEC    700000

/*
 * Ignore event codes 0x70 and up
 *  0x70 and 0x71 are time of day and 0x7D is the seconds latch.  0x7A is
 *  the heartbeat marker.  Correct operation of all these can be seen on
 *  the status line at the bottom of all display pages.  The other codes
 *  above 0x70 are rarely used...he said weakly.
 *  Event code 0x6F (111 decimal) is at the bottom line of the display which
 *  explains why the status line is right justified.
 */
#define MAX_EVENT_CODE      0x6F

#define CSR_R_EVCODE_MASK   0xFF
#define CSR_R_FIFO_EMPTY    0x100
#define CSR_W_READ_FIFO     0x100
#define CSR_RW_RESET        0x200

#define EV_CHARS_WIDTH  7
#define EV_CHARS_HEIGHT 5

struct evInfo {
    struct evInfo *forw;
    struct evInfo *back;
    uint32_t       whenOn;
    uint32_t       bitmap;
    uint8_t        left;
    uint8_t        upper;
    uint8_t        color;
};

void
drawEventLog(int redrawAll)
{
    int evCode;
    uint32_t csr;
    uint32_t now;
    struct evInfo *evp;
    static struct evInfo evTable[MAX_EVENT_CODE];
    static struct evInfo *displayHead, *displayTail;
    static int beenHere;

    if (!beenHere) {
        /* Initialize table */
        int i, j;
        int left, upper;
        static const uint32_t digits[10] = { 0705050507,
                                             0101010101,
                                             0701070407,
                                             0701070107,
                                             0505070101,
                                             0704070107,
                                             0704070507,
                                             0701010101,
                                             0705070507,
                                             0705070107 };
        evCode = 1;
        for (i = 0, upper = 0 ; i <= 12 ; i++, upper += 5) {
            for (j = 1, left = 0 ; j <= 10 ; j++, evCode++) {
                if (evCode > MAX_EVENT_CODE) {
                    break;
                }
                evp = &evTable[evCode - 1];
                evp->bitmap = digits[j % 10];
                if ((i != 0) || (j == 10)) {
                    int t = (i + (j == 10)) % 10;
                    evp->bitmap |= digits[t] << 3;
                }
                evp->left = left;
                evp->upper = upper;
                /*
                 * Provide a little color change between adjacent rows
                 * Eight bit color: RRR GGG BB
                 */

                evp->color = (i & 01) ? 0xFF : 0xFE;
                left += EV_CHARS_WIDTH + 2;
            }
        }
        beenHere = 1;
        redrawAll = 1;
    }
    if (redrawAll) {
        /* Start fresh */
        while (displayHead) {
            displayHead->whenOn = 0;
            displayHead = displayHead->forw;
        }
        displayTail = NULL;
        GPIO_WRITE(GPIO_IDX_EVR_LOG_CSR, CSR_RW_RESET);
        microsecondSpin(1);
        GPIO_WRITE(GPIO_IDX_EVR_LOG_CSR, 0);
    }
    while (!((csr = GPIO_READ(GPIO_IDX_EVR_LOG_CSR)) & CSR_R_FIFO_EMPTY)) {
        GPIO_WRITE(GPIO_IDX_EVR_LOG_CSR, CSR_W_READ_FIFO);
        evCode = csr & CSR_R_EVCODE_MASK;
        if ((evCode <= 0) || (evCode > MAX_EVENT_CODE)) {
            continue;
        }
        if (debugFlags & DEBUGFLAG_SHOW_EVENT_LOG) {
            printf("%d\n", evCode);
        }
        evp = &evTable[evCode-1];
        now = MICROSECONDS_SINCE_BOOT();
        if (now == 0) now = 1;
        if (evp->whenOn) {
            /* 
             * Already on display (and list) so no need to draw event code.
             * Mark up to date by removing from list and relinking at end.
             */
            if (evp->forw) {
                evp->forw->back = evp->back;
            }
            else {
                displayTail = evp->back;
            }
            if (evp->back) {
                evp->back->forw = evp->forw;
            }
            else {
                displayHead = evp->forw;
            }
        }
        else {
            /* Display event code */
            uint32_t b               = 04000000000;
            const uint32_t padAfter  = 01010101010;
            ssd1331SetDrawingRange(evp->left, evp->upper,
                                               EV_CHARS_WIDTH, EV_CHARS_HEIGHT);
            do {
                ssd1331WriteData((b&evp->bitmap) ? evp->color : SSD1331_BLACK);
                if (b & padAfter) {
                    ssd1331WriteData(SSD1331_BLACK);
                }
                b >>= 1;
            } while (b);
        }
        /* Link on to tail */
        evp->forw = NULL;
        if (displayHead == NULL) {
            displayHead = evp;
        }
        evp->back = displayTail;
        if (displayTail) {
            displayTail->forw = evp;
        }
        displayTail = evp;
        evp->whenOn = now;
    }
    /* Remove stale events from display and from list */
    now = MICROSECONDS_SINCE_BOOT();
    while (displayHead && ((int32_t)(now-displayHead->whenOn) > DISPLAY_USEC)) {
        ssd1331FloodRectangle(displayHead->left, displayHead->upper,
                                                EV_CHARS_WIDTH, EV_CHARS_HEIGHT,
                                                SSD1331_BLACK);
        displayHead->whenOn = 0;
        displayHead = displayHead->forw;
        if (displayHead) {
            displayHead->back = NULL;
        }
        else {
            displayTail = NULL;
        }
        now = MICROSECONDS_SINCE_BOOT();
    }
}
