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

//do contrast first to get display dialed in
#define contrastIdx                            0  
#define vssPulsesPerMileIdx                    1
#define microSecondsPerGallonIdx               2
#define injPulsesPer2Revolutions               3
#define currentTripResetTimeoutUSIdx           4
#define tankSizeIdx                            5 
#define injectorSettleTimeIdx                  6
#define weightIdx                              7
#define scratchpadIdx                          8
#define vsspause                               9

//array size      
#define parmsLength (sizeof(parms)/sizeof(unsigned long)) 

#define nil                         3999999999ul
 
#define guinosigold                    B10100101 
#define guinosig                       B11100111 

//Vehicle Interface Pins      
#define InjectorOpenPin                        2      
#define InjectorClosedPin                      3      
#define VSSPin                                14 //analog 0      
 
//LCD Pins      
#define DIPin                                  4 // register select RS      
#define DB4Pin                                 7       
#define DB5Pin                                 8       
#define DB6Pin                                12       
#define DB7Pin                                13      
#define ContrastPin                            6      
#define EnablePin                              5       
#define BrightnessPin                          9      

/* --- LCD Commands --- */
#define LCD_ClearDisplay                    0x01
#define LCD_ReturnHome                      0x02

#define LCD_EntryMode                       0x04
  #define LCD_EntryMode_Increment           0x02

#define LCD_DisplayOnOffCtrl                0x08
  #define LCD_DisplayOnOffCtrl_DispOn       0x04
  #define LCD_DisplayOnOffCtrl_CursOn       0x02
  #define LCD_DisplayOnOffCtrl_CursBlink    0x01

#define LCD_SetCGRAM                        0x40
#define LCD_SetDDRAM                        0x80
  /* you can OR the memory address with each of the above */
 
#define lbuttonPin                            17  // Left Button, on analog 3
#define mbuttonPin                            18  // Middle Button, on analog 4
#define rbuttonPin                            19  // Right Button, on analog 5
 
#define vssBit                              0x01  //  pin14 is a bitmask 1 on port C
#define lbuttonBit                          0x08  //  pin17 is a bitmask 8 on port C
#define mbuttonBit                          0x10  //  pin18 is a bitmask 16 on port C
#define rbuttonBit                          0x20  //  pin19 is a bitmask 32 on port C

// start with the buttons in the right state      
#define buttonsUp   lbuttonBit + mbuttonBit + rbuttonBit

// how many times will we try and loop in a second     
#define loopsPerSecond                         2   


/* --- Typedefs ---------------------------------------------- */

typedef void (* pFunc)(void);//type for display function pointers      



/* --- Classes --------------------------------------------- */

class Trip{      
public:      
  //enum tripvars {loopCount=0, injPulses, injHiSec, injHius, injIdleHiSec, 
  //      injIdleHius, vssPulses, vssEOCPulses, vssPulseLength};
  unsigned long loopCount; //how long has this trip been running      
  unsigned long injPulses; //rpm      
  unsigned long injHiSec;// seconds the injector has been open      
  unsigned long injHius;// microseconds, fractional part of the injectors open       
  unsigned long injIdleHiSec;// seconds the injector has been open      
  unsigned long injIdleHius;// microseconds, fractional part of the injectors open       
  unsigned long vssPulses;//from the speedo      
  unsigned long vssEOCPulses;//from the speedo      
  unsigned long vssPulseLength; // only used by instant
  //these functions actually return in thousandths,       
  unsigned long miles();        
  unsigned long gallons();      
  unsigned long mpg();        
  unsigned long mph();        
  unsigned long time(); //mmm.ss        
  unsigned long eocMiles();  //how many "free" miles?        
  unsigned long idleGallons();  //how many gallons spent at 0 mph?        
  void update(Trip t);      
  void reset();      
  Trip();      
};      
 
//LCD prototype      
namespace LCD{      
  void gotoXY(byte x, byte y);      
  void print(char * string);      
  void init();      
  void tickleEnable();      
  void cmdWriteSet();      
  void LcdCommandWrite(byte value);      
  void LcdDataWrite(byte value);      
  byte pushNibble(byte value);      
};      
