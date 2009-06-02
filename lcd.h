#define LcdCharHeightPix  8

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
/* you can OR a memory address with each of the above */

//LCD prototype      
namespace LCD{      
  void gotoXY(unsigned char x, unsigned char y);      
  void print(char * string);      
  void init();      
  void writeCGRAM(char *newchars, unsigned char numnew);
  void tickleEnable();      
  void cmdWriteSet();      
  void LcdCommandWrite(unsigned char value);      
  void LcdDataWrite(unsigned char value);
  unsigned char pushNibble(unsigned char value);      
};      
