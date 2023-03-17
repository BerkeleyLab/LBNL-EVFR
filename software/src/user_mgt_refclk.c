/*
 * Configure User MGT reference clock (SI570)
 * Complicated by the fact that the SI570 I2C address differs between boards.
 */

#include <stdio.h>
#include <stdint.h>
#include "iicProc.h"
#include "util.h"

/* Si57x defines and variables */
#define fDCO_min 4.85*1000000000
#define fDCO_max 5.67*1000000000
#define targetFrequency 100000000.0
static uint8_t si570Address = 0; // 7-bit address
static uint8_t Si570_reg_idx = 13; // internal register address

static int
setReg(int reg, int value)
{
    uint8_t cv = value;
    return iicProcWrite(si570Address, reg, &cv, 1);
}

static int
refAdjust(int offsetPPM)
{
    int i;
    uint8_t buf[5];
    uint64_t rfreq;

    if (offsetPPM > 3500) offsetPPM = 3500;
    else if (offsetPPM < -3500) offsetPPM = -3500;
    if (!iicProcSetMux(IIC_MUX_PORT_PORT_EXPANDER)) return 0;
    if (!iicProcRead(si570Address, Si570_reg_idx+1, buf, 5)) return 0;
    rfreq = buf[0] & 0x3F;
    for (i = 1 ; i < 5 ; i++) {
        rfreq = (rfreq << 8) | buf[i];
    }
    rfreq = ((rfreq * (1000000 + offsetPPM)) + 500000) / 1000000;
    for (i = 4 ; i > 0 ; i--) {
        buf[i] = rfreq & 0xFF;
        rfreq >>= 8;
    }
    buf[0] = (buf[0] & ~0x3F) | (rfreq & 0x3F);

    if (!setReg(137, 0x10)) return 0;
    if (!iicProcWrite(si570Address, Si570_reg_idx+1, buf, 5)) return 0;
    if (!setReg(137, 0x00)) return 0;
    if (!setReg(135, 0x40)) return 0;
    return 1;
}

 /**
 Set the Si570 target frequency and configure U39 IO0_0 polarity. 
 Note: it require to call iicProcTakeControl() before
 @param  defaultFrequency the initial frequency of the batch.
 @param  SetPolarityLow insert 1 in case of Si570_OE active low, otherwise set it 0.
 @param  temperatureStability use 1 for 7 ppm type, otherwise set it 0 for  20 ppm and 50 ppm.
*/
static int
refInit100MHz(double defaultFrequency, uint8_t SetPolarityLow, uint8_t temperatureStability)
{
    int i;
    uint8_t buf[6], hsdiv_reg, hsdiv_new=11, n1_reg, n1_new=128;
    uint64_t rfreq_reg;
    static const uint8_t hsdiv_values[] = { 11, 9, 7, 6, 5, 4 };

    // Internal register address definition according temperature stability (see datasheet)
    if(temperatureStability == 1)
        Si570_reg_idx = 13;
    else if (temperatureStability == 0)
        Si570_reg_idx = 7;

    if (!iicProcSetMux(IIC_MUX_PORT_PORT_EXPANDER)) return 0; //select Y6 and U39 channel

    if(SetPolarityLow == 1) // reverse the output polarity of U39 (IO0_0)
    {
        uint8_t U39polReg;
        if (!iicProcRead(0x21, 0, &U39polReg, 1)) return 0; // read polarity register IO0 
        U39polReg |= 0x1; // set the bit IO0_0
        if (!iicProcWrite(0x21, 4, &U39polReg, 1)) return 0; // write polarity register IO0 
    }

    if (!setReg(135, 0x01)) return 0; // Reset the device to initial frequency
    if (!iicProcRead(si570Address, Si570_reg_idx, buf, 6)) return 0; // read the device registers

    /*  Buffer structure:
        [0] |HS_DIV[2:0] N1[6:2] |
        [1] |N1[1:0] RFREQ[37:32]|
        [2] |    RFREQ[31:24]    |
        [3] |    RFREQ[23:16]    |
        [4] |    RFREQ[15:8]     |
        [5] |    RFREQ[7:0]      |  */
    // Data decodification
    hsdiv_reg = (buf[0] >> 5) + 4;
    n1_reg = ((buf[0] & 0x1F)<<2 | (buf[1] >> 6)) + 1;
    rfreq_reg = (buf[1] & 0x3F);
    for (i = 2 ; i < 6 ; i++) {
        rfreq_reg = (rfreq_reg << 8) | buf[i];
    }

    // Internal cristal frequency
    double f_xtal = (defaultFrequency * hsdiv_reg * n1_reg)/(rfreq_reg/268435456.0);

    // Calculate HSDIV, N1, RFREQ with lower power consumption
    uint8_t Si57x_param_calculation_done = 0;
    double fDCO_min_fOUT_ratio_threshold = fDCO_min / targetFrequency;
    for(uint8_t j=0; j<6 && !Si57x_param_calculation_done; j++)
    {
        uint8_t hsdiv_tmp = hsdiv_values[j];
        double ratio = fDCO_min_fOUT_ratio_threshold/hsdiv_tmp;
        uint8_t n1_tmp = ((ratio)-((uint32_t) ratio))*10 > 0 ? ratio+1 : ratio;
        if(n1_tmp & 1) n1_tmp++;
        if( (hsdiv_tmp*n1_tmp) < (hsdiv_new*n1_new) )
        {
            n1_new = n1_tmp;
            hsdiv_new = hsdiv_tmp;
        }
    }
    rfreq_reg = (uint64_t)( (( (double) targetFrequency * hsdiv_new * n1_new / f_xtal))*268435456.0);
    buf[0] = ((hsdiv_new-4)<<5 & 0xE0) | ((n1_new-1)>>2 & 0x1F);
    buf[1] = ((n1_new-1)<<6 & 0xC0) | (rfreq_reg>>32 & 0x3F);
    for (i = 2; i < 6; i++)
    {
        buf[i]= (rfreq_reg>>((5-i)*8) & 0xFF);
    }

    // Command to set new frequency
    if (!setReg(137, 0x10)) return 0; // Freeze the DCO (bit4 - reg137)
    if (!iicProcWrite(si570Address, Si570_reg_idx, buf, 6)) return 0; // Writing the data registers
    if (!setReg(137, 0x00)) return 0; // Unfreeze the DCO (bit4 - reg137)
    if (!setReg(135, 0x40)) return 0; // Trigger new frequency (bit4 - reg135)
    return 1;
}


int
userMGTrefClkAdjust(int offsetPPM)
{
    int r = 0;
    iicProcTakeControl();
    if (si570Address == 0) {
        if (iicProcSetMux(IIC_MUX_PORT_PORT_EXPANDER)) {
            int i;
            static const uint8_t addrList[] = { 0x55, 0x75, 0x77 };
            for (i = 0 ; i < sizeof(addrList)/sizeof(addrList[0]) ; i++) {
                if (iicProcWrite(addrList[i], -1, NULL, 0)) {
                    si570Address = addrList[i];
                    break;
                }
            }
        }
    }
    if (si570Address) {
        switch (si570Address)
        {
        case 0x55: // Part number 570BBC000121DG
            r = refInit100MHz(100000000, 0, 0);
            break;
        case 0x75: // Part number ???
            r = refInit100MHz(125000000, 0, 0);
            break;
        case 0x77: // Part number 570NCB000933DG
            r = refInit100MHz(125000000, 1, 1);
            break;
        }
        r &= refAdjust(offsetPPM);
    }
    iicProcRelinquishControl();
    if (r) {
        printf("Updated MGT SI570 0x%02X (7-bit address).\n", si570Address);
    }
    else {
        warn("Unable to update MGT SI570");
    }
    return r;
}
