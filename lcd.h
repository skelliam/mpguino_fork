#define LcdCharHeightPix  8

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
