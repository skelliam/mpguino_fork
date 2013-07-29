#include <avr/pgmspace.h>  
#include "mpguino_conf.h"

/* --- Constants --------------------------------------------- */

#define Sleep_bkl                           0x01
#define Sleep_lcd                           0x02

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
#define PIN_INJECTOROPEN                        2      
#define PIN_INJECTORCLOSED                      3      
//LCD Pins      
#define PIN_DI                                  4 // register select RS      
#define PIN_ENABLE                              5       
#define PIN_CONTRAST                            6      
#define PIN_DB4                                 7       
#define PIN_DB5                                 8       
#define PIN_BRIGHTNESS                          9      
//#define NC                                  10
//#define NC                                  11
#define PIN_DB6                                12       
#define PIN_DB7                                13      
#define PIN_VSS                                14 //analog 0      
//#define NC                                  15
//#define NC                                  16
#define PIN_LBUTTON                            17  // Left Button, on analog 3
#define PIN_MBUTTON                            18  // Middle Button, on analog 4
#define PIN_RBUTTON                            19  // Right Button, on analog 5

/* --- Button bitmasks --- */ 
#define vssBit                              0x01  //  pin14 is a bitmask 1 on port C
#define lbuttonBit                          0x08  //  pin17 is a bitmask 8 on port C
#define mbuttonBit                          0x10  //  pin18 is a bitmask 16 on port C
#define rbuttonBit                          0x20  //  pin19 is a bitmask 32 on port C

// start with the buttons in the right state      
#define buttonsUp   lbuttonBit + mbuttonBit + rbuttonBit

// how many times will we try and loop in a second     
#define loopsPerSecond                         2   

/* --- LCD line buffer size --- */
#define bufsize                               17

/* --- Enums ------------------------------------------------- */

enum displayTypes {dtText=0, dtBigChars, dtBarGraph};

/* --- Typedefs ---------------------------------------------- */

typedef void (* pFunc)(void);//type for display function pointers      

/* --- Macros ------------------------------------------------ */

#define GetLeftButtonPressed()        (!(buttonState & lbuttonBit))
#define GetRightButtonPressed()       (!(buttonState & rbuttonBit))
#define GetMiddleButtonPressed()      (!(buttonState & mbuttonBit))

#define MIN(value1, value2)\
    (((value1) >= (value2)) ? (value2) : (value1))

#define MAX(value2, value1)\
    (((value1)>=(value2)) ? (value1) : (value2))

#define length(x) (sizeof x / sizeof *x)

#define looptime 1000000ul/loopsPerSecond /* 0.5 second */

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

enum longparms { contrastIdx = 0, 
                 vssPulsesPerMileIdx, 
                 microSecondsPerGallonIdx, 
                 injPulsesPer2Revolutions, 
                 currentTripResetTimeoutUSIdx, 
                 tankSizeIdx, 
                 injectorSettleTimeIdx, 
                 weightIdx, 
                 scratchpadIdx, 
                 vsspauseIdx,
                 fuelcostIdx,
                 parmsCount };  /* this is always last */

/* default values */
unsigned long parms[]={
   95ul,               /* contrast                                  */
   8208ul,             /* pulses per mile                           */
   500000000ul,        /* us per gallon            1 us/gal/bit?    */
   3ul,                /* pulses per 2 rev                          */
   420000000ul,        /* current trip reset timeout                */
   10300ul,            /* tank size                0.001 gal/bit    */
   500ul,              /* injector settle time                      */
   2400ul,             /* weight                   1 lb/bit         */
   0ul,                /* scratchpad                                */
   2ul,                /* vsspause                                  */
   300ul,              /* fuel cost                0.01 dollars/bit */
};

char *parmLabels[]={
   "Contrast",
   "VSS Pulses/Mile", 
   "MicroSec/Gallon",
   "Pulses/2 revs",
   "Timout(microSec)",
   "Tank Gal * 1000",
   "Injector DelayuS",
   "Weight (lbs)",
   "Scratchpad(odo?)",
   "VSS Delay ms",
   "Fuel Cost($/gal)"
};

/* --- Classes --------------------------------------------- */

class Trip{      
   public:      
     enum varnames { loopCount=0, 
                     injPulses, 
                     injHiSec, 
                     injHius, 
                     injIdleHiSec, 
                     injIdleHius, 
                     vssPulses, 
                     vssEOCPulses, 
                     vssPulseLength,
                     varCount };       /* this is always last ! */

     unsigned long var[varCount];

     /* ----
        loopCount      -- how long has this trip been running      
        injPulses      -- rpm      
        injHiSec       -- seconds the injector has been open      
        injHius        -- microseconds, fractional part of the injectors open
        injIdleHiSec   -- seconds the injector has been open
        injIdleHius    -- microseconds, fractional part of the injectors open
        vssPulses      -- from the speedo
        vssEOCPulses   -- from the speedo
        vssPulseLength -- only used by instant
     ---- */

     //these functions actually return in thousandths,       
     unsigned long miles();        
     unsigned long gallons();      
     unsigned long mpg();        
     unsigned long mph();        
     unsigned long time();         //mmm.ss        
     unsigned long eocMiles();     //how many "free" miles?        
     unsigned long idleGallons();  //how many gallons spent at 0 mph?        
     unsigned long fuelCost();
     void update(Trip t);      
     void reset();      
     Trip();      
};      
 

