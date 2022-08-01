/*
 * SSD1331 96x64 Display Controller
 */
#ifndef _SSD_1331_
#define _SSD_1331_

#define SSD1331_WIDTH   96
#define SSD1331_HEIGHT  64

#define SSD1331_CHARACTER_WIDTH    5
#define SSD1331_CHARACTER_HEIGHT   8

#define SSD1331_RED     0xE0
#define SSD1331_GREEN   0x1C
#define SSD1331_BLUE    0x03
#define SSD1331_YELLOW  (SSD1331_RED|SSD1331_GREEN)
#define SSD1331_CYAN    (SSD1331_GREEN|SSD1331_BLUE)
#define SSD1331_MAGENTA (SSD1331_RED|SSD1331_BLUE)
#define SSD1331_WHITE   (SSD1331_RED|SSD1331_GREEN|SSD1331_BLUE)
#define SSD1331_BLACK   0x00

void ssd1331Init(void);
void ssd1331Enable(int enable);
void ssd1331SetCharacterColor(int character, int background);
void ssd1331FloodRectangle(int left,int upper,int width,int  height,int color);
void ssd1331FloodDisplay(int color);
void ssd1331SetDrawingRange(int left, int upper, int width, int height);
void ssd1331WriteData(int b);

void ssd1331DisplayCharacter(int left, int upper, int c);
void ssd1331DisplayString(int left, int upper, const char *cp);
void ssd1331DisplayNibble(int left, int upper, int n);
void ssd1331DisplayHeartbeat(int left, int upper, int on);

#endif /* _SSD_1331_ */
