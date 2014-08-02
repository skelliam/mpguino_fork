#ifndef LCDCHARS_H
#define LCDCHARS_H

#include "mpguino_conf.h"

#define LCD_TopLine                         0
#define LCD_BottomLine                      1
#define LcdCharHeightPix                    8

//sometime we should not need to extern these
#if (CFG_BIGFONT_TYPE)
extern const char chars[];
extern const unsigned char LcdNewChars;
extern const char bignumchars1[];
extern const char bignumchars2[];
#endif

#if (BARGRAPH_DISPLAY_CFG == 1)
extern const char barchars[];
extern const unsigned char LcdBarChars;
extern const char ascii_barmap[];
#endif

static void putCharsToLCD(LiquidCrystal*, const char*, unsigned char);
#endif
