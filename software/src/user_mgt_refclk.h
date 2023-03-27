/*
 * Configure User MGT reference clock (SI570)
 */

#ifndef _USER_MGT_REFCLK_H_
#define _USER_MGT_REFCLK_H_

int userMGTrefClkAdjust(int offsetPPM);

struct si57x_part_numbers {
    uint8_t iicAddr;
    double targetFrequency;
    double startupFrequency;
    int outputEnablePolarity;
    int temperatureStability;
};


#endif
