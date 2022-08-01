/*
 * SSD1331 96x64 display controller
 * Based on CrystalFontz example
 */

// Display is Crystalfontz CFAL9664B-F-B1 or CFAL9664B-F-B2
//   https://www.crystalfontz.com/product/cfal9664bfb1
//   https://www.crystalfontz.com/product/cfal9664bfb2
//
// The controller is a SSD1331
//   https://www.crystalfontz.com/controllers/SolomonSystech/SSD1331/
//

// Set Display Type:
#define CFAL9664BFB1 (1)
#define CFAL9664BFB2 (0)

// Register addresses from CrystalFontz example
#define SSD1331_0x15_Column_Address         (0x15)
#define SSD1331_0x21_Draw_Line              (0x21)
#define SSD1331_0x22_Draw_Rectangle         (0x22)
#define SSD1331_0x23_Copy                   (0x23)
#define SSD1331_0x24_Dim_Window             (0x24)
#define SSD1331_0x25_Clear_Window           (0x25)
#define SSD1331_0x26_Fill_Copy_Options      (0x26)
#define SSD1331_0x27_Scrolling_Options      (0x27)
#define SSD1331_0x2E_Scrolling_Stop         (0x2E)
#define SSD1331_0x2F_Scrolling_Start        (0x2F)
#define SSD1331_0x75_Row_Address            (0x75)
#define SSD1331_0x81_Contrast_A_Blue        (0x81)
#define SSD1331_0x82_Contrast_B_Green       (0x82)
#define SSD1331_0x83_Contrast_C_Red         (0x83)
#define SSD1331_0x87_Master_Current         (0x87)
#define SSD1331_0x8A_Second_Precharge       (0x8A)
#define SSD1331_0xA0_Remap_Data_Format      (0xA0)
#define SSD1331_0xA1_Start_Line             (0xA1)
#define SSD1331_0xA2_Vertical_Offset        (0xA2)
#define SSD1331_0xA4_Mode_Normal            (0xA4)
#define SSD1331_0xA5_Mode_All_On            (0xA5)
#define SSD1331_0xA6_Mode_All_Off           (0xA6)
#define SSD1331_0xA7_Mode_Inverse           (0xA7)
#define SSD1331_0xA8_Multiplex_Ratio        (0xA8)
#define SSD1331_0xAB_Dim_Mode_Setting       (0xAB)
#define SSD1331_0xAD_Master_Configuration   (0xAD)
#define SSD1331_0x8F_Param_Not_External_VCC (0x8F)
#define SSD1331_0x8E_Param_Set_External_VCC (0x8E)
#define SSD1331_0xAC_Display_On_Dim         (0xAC)
#define SSD1331_0xAE_Display_Off_Sleep      (0xAE)
#define SSD1331_0xAF_Display_On_Normal      (0xAF)
#define SSD1331_0xB0_Power_Save_Mode        (0xB0)
#define SSD1331_0x1A_Param_Yes_Power_Save   (0x1A)
#define SSD1331_0x0B_Param_No_Power_Save    (0x0B)
#define SSD1331_0xB1_Phase_1_2_Period       (0xB1)
#define SSD1331_0xB3_Clock_Divide_Frequency (0xB3)
#define SSD1331_0xB8_Gamma_Table            (0xB8)
#define SSD1331_0xB9_Linear_Gamma           (0xB9)
#define SSD1331_0xBB_Precharge_Voltage      (0xBB)
#define SSD1331_0xBE_VCOMH_Voltage          (0xBE)
#define SSD1331_0xFD_Lock_Unlock            (0xFD)
#define SSD1331_0x12_Param_Unlock           (0x12)
#define SSD1331_0x16_Param_Lock             (0x16)  

/*****************************************************************************/
// LBNL application code

#include <stdio.h>
#include <xparameters.h>
#include "gpio.h"
#include "ssd1331.h"
#include "util.h"

#define CSR_R_ENABLE    0x2000000
#define CSR_R_RESET     0x1000000
#define CSR_R_READY     0x10000
#define CSR_W_DATA      0x100
#define CSR_W_LAST      0x10000
#define CSR_W_ENABLE_CONTROLS  0x8000
#define CSR_W_CONTROL_RESET    0x0001
#define CSR_W_CONTROL_ENABLE   0x0002

static uint8_t characterColor, characterBackground;

static void
sendWord(int w)
{
    while (!(GPIO_READ(GPIO_IDX_DISPLAY) & CSR_R_READY)) {
        continue;
    }
    GPIO_WRITE(GPIO_IDX_DISPLAY, w);
}

static void
SPI_sendCommand(int w)
{
    sendWord(w);
}

void
ssd1331WriteData(int w)
{
    sendWord(CSR_W_DATA | w);
}

/*
 * Initialization commands from CrystalFontz example
 */
void
ssd1331Init(void)
{
    characterColor = SSD1331_WHITE;
    characterBackground = SSD1331_BLACK;
    GPIO_WRITE(GPIO_IDX_DISPLAY, CSR_W_ENABLE_CONTROLS | CSR_W_CONTROL_RESET);
    microsecondSpin(5);
    GPIO_WRITE(GPIO_IDX_DISPLAY, CSR_W_ENABLE_CONTROLS | CSR_W_CONTROL_ENABLE);
    microsecondSpin(5);

    //Make sure the chip is not in "lock" mode.
    SPI_sendCommand(SSD1331_0xFD_Lock_Unlock);
    SPI_sendCommand(SSD1331_0x12_Param_Unlock);
  
    //Turn the display off during setup
    SPI_sendCommand(SSD1331_0xAE_Display_Off_Sleep);
    //Set normal display mode (not all on, all off or inverted)
    SPI_sendCommand(SSD1331_0xA4_Mode_Normal);
  
    //Set column address range 0-95
    SPI_sendCommand(SSD1331_0x15_Column_Address);
    SPI_sendCommand(0);  //column address start
    SPI_sendCommand(95); //column address end
    //Set row address range 0-63
    SPI_sendCommand(SSD1331_0x75_Row_Address);
    SPI_sendCommand(0);  //row address start
    SPI_sendCommand(63); //row address end
    //Set the master current control, based on the version of OLED
    SPI_sendCommand(SSD1331_0x87_Master_Current);
    //Old "0x0E"
  #if CFAL9664BFB1
    SPI_sendCommand(6); // 6/16 (60uA of 160uA)
  #else //CFAL9664BFB2
    SPI_sendCommand(9); // 9/16 (90uA of 160uA)
  #endif
  
  //From BM7 current sweeps + maths
  #if CFAL9664BFB1
  //Set current level/fraction for each color channel
  #if 1
    //Target 100 cd/m*m (normal)
    SPI_sendCommand(SSD1331_0x81_Contrast_A_Blue);
    SPI_sendCommand(184);
    SPI_sendCommand(SSD1331_0x82_Contrast_B_Green);
    SPI_sendCommand(145);
    SPI_sendCommand(SSD1331_0x83_Contrast_C_Red);
    SPI_sendCommand(176);
  #else
    //Target 115 cd/m*m (brighter, may reduce life)
    SPI_sendCommand(SSD1331_0x81_Contrast_A_Blue);
    SPI_sendCommand(218);
    SPI_sendCommand(SSD1331_0x82_Contrast_B_Green);
    SPI_sendCommand(169);
    SPI_sendCommand(SSD1331_0x83_Contrast_C_Red);
    SPI_sendCommand(226);
  #endif
  #else //CFAL9664BFB2
  //Set current level/fraction for each color channel
  #if 1
    //Target 100 cd/m*m (normal)
    SPI_sendCommand(SSD1331_0x81_Contrast_A_Blue);
    SPI_sendCommand(85);
    SPI_sendCommand(SSD1331_0x82_Contrast_B_Green);
    SPI_sendCommand(46);
    SPI_sendCommand(SSD1331_0x83_Contrast_C_Red);
    SPI_sendCommand(158);
  #else
    //Target 115 cd/m*m (brighter, may reduce life)
    SPI_sendCommand(SSD1331_0x81_Contrast_A_Blue);
    SPI_sendCommand(102);
    SPI_sendCommand(SSD1331_0x82_Contrast_B_Green);
    SPI_sendCommand(59);
    SPI_sendCommand(SSD1331_0x83_Contrast_C_Red);
    SPI_sendCommand(199);
  #endif
  #endif
  
    //Set pre-charge drive strength/slope
    SPI_sendCommand(SSD1331_0x8A_Second_Precharge);
    SPI_sendCommand(0x61); //A=Blue
    SPI_sendCommand(0x8b); //required token
    SPI_sendCommand(0x62); //B=Green
    SPI_sendCommand(0x8c); //required token
    SPI_sendCommand(0x63); //C=Red
  
    //Configure the controller for our panel
    SPI_sendCommand(SSD1331_0xA0_Remap_Data_Format);
    SPI_sendCommand(0x20);
    // 0010 0000
    // ffsv wmhi
    // |||| ||||--*0 = Horizontal Increment
    // |||| |||    1 = Vertical Increment
    // |||| |||---*0 = Com order is 0 -> 95
    // |||| ||     1 = Com order is 95 -> 0
    // |||| ||----*0 = Normal Order SA,SB,SC
    // |||| ||     1 = Reverse Order SC,SB,SA
    // |||| |-----*0 = No Left/Right COM swap
    // ||||        1 = Swap Left/Right COM
    // ||||------- 0 = Scan COM0 -> COM63
    // |||        *1 = Scan COM63 -> COM0
    // |||-------- 0 = COM not split
    // ||         *1 = COM split odd/even
    // ||---------*00 = 256 color format
    //             01 = 65K color format #1
    //             10 = 65K color format #2
    //             11 = reserved
    //Start at line 0
    SPI_sendCommand(SSD1331_0xA1_Start_Line);
    SPI_sendCommand(0);
    //No vertical offset
    SPI_sendCommand(SSD1331_0xA2_Vertical_Offset);
    SPI_sendCommand(0);
    //Mux ratio = vertical resolution = 64
    SPI_sendCommand(SSD1331_0xA8_Multiplex_Ratio);
    SPI_sendCommand(63);
    //Reset Master configuration
    SPI_sendCommand(SSD1331_0xAD_Master_Configuration);
    SPI_sendCommand(SSD1331_0x8F_Param_Not_External_VCC);
    //Enable power save mode
    SPI_sendCommand(SSD1331_0xB0_Power_Save_Mode);
    SPI_sendCommand(SSD1331_0x1A_Param_Yes_Power_Save);
    //Set the periods for our OLED
    SPI_sendCommand(SSD1331_0xB1_Phase_1_2_Period);
    SPI_sendCommand(0xF1); // Phase 2 period Phase 1 period
    // 1111 0001
    // tttt oooo
    // |||| ||||-- 1 to 15 = Phase 1 period in DCLK
    // ||||------- 1 to 15 = Phase 2 period in DCLK
    //Set Display Clock Divide Ratio/Oscillator Frequency
    SPI_sendCommand(SSD1331_0xB3_Clock_Divide_Frequency);
    SPI_sendCommand(0xD0);
    // 1101 0000
    // ffff dddd
    // |||| ||||-- Divide 0 => /1, 15 => /16
    // ||||------- Frequency (See Figure 28 in SSD1331 datasheet)
    //             Table shows ~800KHz for 2.7v
    //             Original comment is "0.97MHz"
  
    //Set pre-charge voltage level 
    SPI_sendCommand(SSD1331_0xBB_Precharge_Voltage);
    //0x3E => 0.5 * Vcc (See Figure 28 in SSD1331 datasheet)
    SPI_sendCommand(0x3E);
  
    //Set COM deselect voltage level (VCOMH)
    SPI_sendCommand(SSD1331_0xBE_VCOMH_Voltage);
    // 0011 1110
    // --VV VVV-
    // |||| ||||-- reserved = 0
    // |||| |||--- Voltage Code
    // ||            00000 = 0.44 * Vcc (0x00)
    // ||            01000 = 0.52 * Vcc (0x10)
    // ||            10000 = 0.61 * Vcc (0x20)
    // ||            11000 = 0.71 * Vcc (0x30)
    // ||            11111 = 0.83 * Vcc (0x3E)
    // ||--------- reserved = 0
  #if CFAL9664BFB1
    // 0.83 * Vcc (0x3E)
    SPI_sendCommand(0x3E);
  #else //CFAL9664BFB2
    // 0.71 * Vcc (0x30)
    SPI_sendCommand(0x30);
  #endif
  
  #if 0
    //Set default linear gamma / gray scale table
    SPI_sendCommand(SSD1331_0xB9_Linear_Gamma);
  #else
    //Set custom gamma / gray scale table
    //Same curve is used for all channels
    //This table is gamma 2.25
    //See Gamma_Calculations.xlsx
    static const uint8_t gamma[32] = {
      0x01,0x01,0x01,0x02,0x02,0x04,0x05,0x07,
      0x09,0x0B,0x0D,0x10,0x13,0x16,0x1A,0x1E,
      0x22,0x26,0x2B,0x2F,0x34,0x3A,0x3F,0x45,
      0x4B,0x52,0x58,0x5F,0x66,0x6E,0x75,0x7D };
  
    //Send gamma table
    SPI_sendCommand(SSD1331_0xB8_Gamma_Table);
    int i;
    //Send 32 bytes from the table
    for (i = 0; i < 32; i++) {
      SPI_sendCommand(gamma[i]);
    }
  #endif
  
    //Set Master configuration to select external VCC
    SPI_sendCommand(SSD1331_0xAD_Master_Configuration);
    SPI_sendCommand(SSD1331_0x8E_Param_Set_External_VCC);
  
    //As a more reasonable default, set the rectangle
    SPI_sendCommand(SSD1331_0x26_Fill_Copy_Options);
    // 0x00 Draw rectangle outline only
    // 0x01 Draw rectangle outline and fill
    SPI_sendCommand(0x01);
  
    //Clear the screen to 0x00
    SPI_sendCommand(SSD1331_0x25_Clear_Window);
    SPI_sendCommand(0); //X0
    SPI_sendCommand(0); //Y0
    SPI_sendCommand(95); //X0
    SPI_sendCommand(63); //Y0
    //Let it finish.
    microsecondSpin(10);
    //Turn the display on
    SPI_sendCommand(SSD1331_0xAF_Display_On_Normal);
}

void
ssd1331Enable(int enable)
{
    GPIO_WRITE(GPIO_IDX_DISPLAY, CSR_W_ENABLE_CONTROLS |
                                           (enable ? CSR_W_CONTROL_ENABLE : 0));
}

void
ssd1331SetCharacterColor (int character, int background)
{
    characterColor = character;
    characterBackground = background;
}

void
ssd1331FloodRectangle (int left, int upper, int width, int  height, int color)
{
    int n = width * height;
    /*
     * The controller has a 'draw bordered rectangle' command but
     * using it would require knowing the appropriate amount of time
     * to wait while the controller performed the operation.  The 
     * data sheet does not provide this information and there is
     * no way to monitor the busy/ready status of the controller
     * so just do things by hand.
     * Plus there's the issue of color mapping from 8 bit to 16 bit.
     */
    SPI_sendCommand(SSD1331_0x15_Column_Address);
    SPI_sendCommand(left);
    SPI_sendCommand(left + width - 1);
    SPI_sendCommand(SSD1331_0x75_Row_Address);
    SPI_sendCommand(upper);
    SPI_sendCommand(upper + height - 1);
    while (n--) {
        ssd1331WriteData(color);
    }
}

void
ssd1331FloodDisplay (int color)
{
    ssd1331FloodRectangle(0, 0, SSD1331_WIDTH, SSD1331_HEIGHT, color);
}

void
ssd1331SetDrawingRange(int left, int upper, int width, int height)
{
    SPI_sendCommand(SSD1331_0x15_Column_Address);
    SPI_sendCommand(left);
    SPI_sendCommand(left + width - 1);
    SPI_sendCommand(SSD1331_0x75_Row_Address);
    SPI_sendCommand(upper);
    SPI_sendCommand(upper + height - 1);
}

/*
 * 4x7 bitmap characters
 * Hexadecimal values and some punctuation
 */
void
ssd1331DisplayCharacter (int left, int upper, int c)
{
    int pad = (left < (SSD1331_WIDTH - (SSD1331_CHARACTER_WIDTH - 1)));
    int lead = (upper < (SSD1331_HEIGHT - (SSD1331_CHARACTER_HEIGHT - 1)));
    int width = SSD1331_CHARACTER_WIDTH - !pad;
    int height = SSD1331_CHARACTER_HEIGHT - !lead;
    uint32_t bitmap;
    uint32_t b = 1UL << (((SSD1331_CHARACTER_WIDTH - 1) *
                          (SSD1331_CHARACTER_HEIGHT - 1)) - 1);
    uint32_t padAfter = pad ? 0x1111111 : 0;
    if ((left > (SSD1331_WIDTH - (SSD1331_CHARACTER_WIDTH - 1)))
     || (upper > (SSD1331_HEIGHT - (SSD1331_CHARACTER_HEIGHT - 1)))) {
        return;
    }
    switch (c) {
    case '0':               bitmap = 0xF99999F; break;
    case '1':               bitmap = 0x2222222; break;
    case '2':               bitmap = 0xF11F88F; break;
    case '3':               bitmap = 0xF11711F; break;
    case '4':               bitmap = 0x199F111; break;
    case '5':               bitmap = 0xF88F11F; break;
    case '6':               bitmap = 0xF88F99F; break;
    case '7':               bitmap = 0xF111111; break;
    case '8':               bitmap = 0xF99F99F; break;
    case '9':               bitmap = 0xF99F11F; break;
    case 'A':  case 'a':    bitmap = 0x699F999; break;
    case 'B':  case 'b':    bitmap = 0xE9AEA9E; break;
    case 'C':  case 'c':    bitmap = 0x6988896; break;
    case 'D':  case 'd':    bitmap = 0xCA999AC; break;
    case 'E':  case 'e':    bitmap = 0xF88E88F; break;
    case 'F':  case 'f':    bitmap = 0xF88E888; break;
    case '-':               bitmap = 0x0007000; break;
    case ':':               bitmap = 0x0002002; break;
    case '.':               bitmap = 0x0000002; break;
    case '/':               bitmap = 0x1224488; break;
    case ' ':               bitmap = 0x0000000; break;
    default: return;
    }
    ssd1331SetDrawingRange(left, upper, width, height);
    do {
        ssd1331WriteData(b & bitmap ? characterColor : characterBackground);
        if (b & padAfter) {
            ssd1331WriteData(characterBackground);
        }
        b >>= 1;
    } while (b);
    if (lead) {
        while(width--) {
            ssd1331WriteData(characterBackground);
        }
    }
}

void
ssd1331DisplayString(int left, int upper, const char *cp)
{
    while (*cp) {
        ssd1331DisplayCharacter(left, upper, *cp);
        left += SSD1331_CHARACTER_WIDTH;
        cp++;
    }
}

void
ssd1331DisplayNibble (int left, int upper, int n)
{
    if ((n >= 0) && (n <= 9)) n += '0';
    else if ((n >= 0xA) && (n <= 0xF)) n += 'A' - 10;
    else return;
    ssd1331DisplayCharacter(left, upper, n);
}

void
ssd1331DisplayHeartbeat(int left, int upper, int on)
{
    uint32_t b = 0x1UL << 24;
    const uint32_t bitmap = on ? 0xAFFDC4 : 0;
    SPI_sendCommand(SSD1331_0x15_Column_Address);
    SPI_sendCommand(left);
    SPI_sendCommand(left+4);
    SPI_sendCommand(SSD1331_0x75_Row_Address);
    SPI_sendCommand(upper+1);
    SPI_sendCommand(upper+5);
    do {
        ssd1331WriteData(b & bitmap ? SSD1331_GREEN : SSD1331_BLACK);
        b >>= 1;
    } while (b);
}
