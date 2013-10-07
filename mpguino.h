#include <avr/pgmspace.h>  
#include "mpguino_conf.h"

/* --- Constants --------------------------------------------- */

#define Sleep_bkl                           0x01
#define Sleep_lcd                           0x02

#define Pos_OK                              10
#define Pos_Cancel                          11
#define Pos_TensDigit                       8
#define Pos_OnesDigit                       9
#define Pos_MaxInput                        9
#define Pos_MinInput                        0
#define Pos_Max                             12


#define Time_TwoMinutes                     240

#if (CFG_SERIAL_TX == 1)
   #define myubbr (16000000/16/9600-1)
#endif

#if (TANK_IN_EEPROM_CFG == 1)
   #define eepBlkAddr_Tank                  0xA0
   #define eepBlkSize_Tank                     9
#endif

#define nil                         3999999999ul
 
#define guinosigold                    B10100101 
#define guinosig                       B11100111 

//Vehicle Interface Pins      
//#define NC                                   1
#define InjectorOpenPin                        2      
#define InjectorClosedPin                      3      
//LCD Pins      
#define DIPin                                  4 // register select RS      
#define EnablePin                              5       
#define ContrastPin                            6      
#define DB4Pin                                 7       
#define DB5Pin                                 8       
#define BrightnessPin                          9      
//#define NC                                  10
//#define NC                                  11
#define DB6Pin                                12       
#define DB7Pin                                13      
#define VSSPin                                14 //analog 0      
//#define NC                                  15
//#define NC                                  16
#define lbuttonPin                            17  // Left Button, on analog 3
#define mbuttonPin                            18  // Middle Button, on analog 4
#define rbuttonPin                            19  // Right Button, on analog 5

/* --- Button bitmasks --- */ 
#define vssBit                              0x01  //  pin14 is a bitmask 1 on port C
#define lbuttonBit                          0x08  //  pin17 is a bitmask 8 on port C
#define mbuttonBit                          0x10  //  pin18 is a bitmask 16 on port C
#define rbuttonBit                          0x20  //  pin19 is a bitmask 32 on port C

// start with the buttons in the right state      
#define buttonsUp   lbuttonBit + mbuttonBit + rbuttonBit

/* --- LCD line buffer size --- */
#define bufsize                               17

/* --- Enums ------------------------------------------------- */

enum displayTypes {dtText=0, dtBigChars, dtBarGraph};

/* --- Typedefs ---------------------------------------------- */

typedef void (* pFunc)(void);//type for display function pointers      

/* --- Macros ------------------------------------------------ */

#define LeftButtonPressed        (!(buttonState & lbuttonBit))
#define RightButtonPressed       (!(buttonState & rbuttonBit))
#define MiddleButtonPressed      (!(buttonState & mbuttonBit))

#define MIN(value1, value2)\
    (((value1) >= (value2)) ? (value2) : (value1))

#define MAX(value2, value1)\
    (((value1)>=(value2)) ? (value1) : (value2))

#define length(x) (sizeof x / sizeof *x)

#if (CFG_IDLE_MESSAGE == 1)
#define IdleDisplayRequested     (IDLE_DISPLAY_DELAY > 0)
#endif

/* --- Globals ----------------------------------------------- */

int CLOCK;
unsigned char DISPLAY_TYPE;
unsigned char SCREEN;      
unsigned char HOLD_DISPLAY; 
static char LCDBUF1[bufsize];
static char LCDBUF2[bufsize];

#if (CFG_IDLE_MESSAGE != 0)
signed char IDLE_DISPLAY_DELAY;
#endif

#if (CFG_FUELCUT_INDICATOR != 0)
unsigned char FCUT_POS;
  #if (CFG_FUELCUT_INDICATOR == 2)
  /* XXX: With the Newhaven LCD, there is no backslash (character 0x5C)...
   * the backslash was replaced with the Yen currency symbol.  Other LCDs
   * might have a proper backslash, so we'll leave this in... */
  char spinner[4] = {'|', '/', '-', '\\'};
  #elif (CFG_FUELCUT_INDICATOR == 3)
  char spinner[4] = {'O', 'o', '.', '.'};
  #endif
#endif

#if (BARGRAPH_DISPLAY_CFG == 1)
/* The mpg() function call in a Trip class returns an unsigned long.
 * This value can be divided by 1000 in order to get 'true' mpg.
 * This means that an unsigned short int will hold 0xFFFF, or 65535
 * (65.535 MPG).  Since 65.535 is potentially realistic, I propose dropping
 * one decimal of precision in favor of a higher maximum -- 655.35 mpg.
 * This way we can save 20 bytes of memory. */
unsigned short PERIODIC_HIST[10];
unsigned short BAR_LIMIT = 4800;  /* 48 mpg (3 mpg/px) */
#endif


/* --- Classes --------------------------------------------- */


