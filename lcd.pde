#include "lcd.h"

//x=0..16, y= 0..1      
void LCD::gotoXY(unsigned char x, unsigned char y){      
  unsigned char dr=x+0x80;
  switch (y) {
     case 1:
       dr += 0x40;      
       break;
     case 2:
       dr += 0x14;      
       break;
     case 3:
       dr += 0x54;      
       break;
  }
  LCD::LcdCommandWrite(dr);        
}      
 
void LCD::print(char * string){      
  unsigned char x = 0;      
  char c = string[x];      
  while(c != 0){      
    LCD::LcdDataWrite(c);       
    x++;      
    c = string[x];      
  }      
}      
 
 
void LCD::init(){
  delay2(16);                    // wait for more than 15 msec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  tickleEnable();
  delay2(5);                     // wait for more than 4.1 msec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  tickleEnable();
  delay2(1);                     // wait for more than 100 usec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  tickleEnable();
  delay2(1);                     // wait for more than 100 usec
  pushNibble(B00100000);  // send (B0010) to DB7-4 for 4bit
  cmdWriteSet();
  tickleEnable();
  delay2(1);                     // wait for more than 100 usec

  // ready to use normal LcdCommandWrite() function now!
  LcdCommandWrite(B00101000);   // 4-bit interface, 2 display lines, 5x8 font
  LcdCommandWrite(LCD_DisplayOnOffCtrl | LCD_DisplayOnOffCtrl_DispOn);
  LcdCommandWrite(LCD_EntryMode | LCD_EntryMode_Increment);

//creating the custom fonts:
  LcdCommandWrite(LCD_SetCGRAM | 0x08);  // write to CGen RAM



  writeCGRAM(&chars[0], LcdNewChars);

  LcdCommandWrite(LCD_ClearDisplay);       // clear display, set cursor position to zero
  LcdCommandWrite(LCD_SetDDRAM);           // set dram to zero
}

void  LCD::writeCGRAM(char *newchars, unsigned char numnew) {
   unsigned char x, y;
   /* write the character data to the character generator ram */
   for(x=0; x<numnew; x++) {
      for(y=0; y<LcdCharHeightPix; y++) {
         LcdDataWrite(pgm_read_byte(&newchars[y*LcdNewChars+x])); 
      }
   }
}

void  LCD::tickleEnable(){       
  // send a pulse to enable       
  digitalWrite(EnablePin,HIGH);       
  delayMicroseconds2(1);  // pause 1 ms according to datasheet       
  digitalWrite(EnablePin,LOW);       
  delayMicroseconds2(1);  // pause 1 ms according to datasheet       
}        
 
void LCD::cmdWriteSet(){       
  digitalWrite(EnablePin,LOW);       
  delayMicroseconds2(1);  // pause 1 ms according to datasheet       
  digitalWrite(DIPin,0);       
}       
 
unsigned char LCD::pushNibble(unsigned char value){       
  digitalWrite(DB7Pin, value & 128);       
  value <<= 1;       
  digitalWrite(DB6Pin, value & 128);       
  value <<= 1;       
  digitalWrite(DB5Pin, value & 128);       
  value <<= 1;       
  digitalWrite(DB4Pin, value & 128);       
  value <<= 1;       
  return value;      
}      
 
void LCD::LcdCommandWrite(unsigned char value){       
  value=pushNibble(value);      
  cmdWriteSet();       
  tickleEnable();       
  value=pushNibble(value);      
  cmdWriteSet();       
  tickleEnable();       
  delay2(5);       
}       
 
void LCD::LcdDataWrite(unsigned char value){       
  digitalWrite(DIPin, HIGH);       
  value=pushNibble(value);      
  tickleEnable();       
  value=pushNibble(value);      
  tickleEnable();       
  delay2(5);
}       
 
