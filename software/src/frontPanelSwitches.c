/*
 * Kicker gate driver control
 */
#include <stdio.h>
#include <stdint.h>
#include "frontPanelSwitches.h"
#include "gpio.h"
#include "util.h"

#define CSR_R_RESET_BUTTON_PRESSED      0x80000000
#define CSR_R_DISPLAY_BUTTON_PRESSED    0x40000000
#define CSR_READ() GPIO_READ(GPIO_IDX_USER_GPIO_CSR)

/*
 * See if reset switch has been pressed for a while
 */
void
checkForReset(void)
{
    uint32_t now = MICROSECONDS_SINCE_BOOT();
    static uint32_t then;
    static uint32_t beenReleased = 0;
    if (resetRecoverySwitchPressed()) {
        if (beenReleased && ((MICROSECONDS_SINCE_BOOT() - then) > 2000000)) {
            resetFPGA(displaySwitchPressed());
        }
    }
    else {
        beenReleased = 1;
        then = now;
    }
}

/*
 * Is reset/recovery switch currently pressed?
 */
int
resetRecoverySwitchPressed(void)
{
    return ((CSR_READ() & CSR_R_RESET_BUTTON_PRESSED) != 0);
}

/*
 * Is display switch pressed?
 */
int
displaySwitchPressed(void)
{
    return ((CSR_READ() & CSR_R_DISPLAY_BUTTON_PRESSED) != 0);
}

