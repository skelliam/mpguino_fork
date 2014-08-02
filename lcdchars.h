#ifndef LCDCHARS_H
#define LCDCHARS_H

#include "mpguino_conf.h"

#if (CFG_BIGFONT_TYPE)
extern const char chars[];
extern const unsigned char LcdNewChars;
extern char bignumchars1[];
extern char bignumchars2[];
#endif

#if (BARGRAPH_DISPLAY_CFG == 1)
extern const unsigned char LcdBarChars;
extern const char barchars[];
extern char ascii_barmap[];
#endif

#endif
