#include "mpguino_conf.h"
#include "lcdchars.h"
#include "LiquidCrystal.h"

#if (CFG_BIGFONT_TYPE == 1)
  const char chars[] PROGMEM = {
    B11111, B00000, B11111, B11111, B00000,
    B11111, B00000, B11111, B11111, B00000,
    B11111, B00000, B11111, B11111, B00000,
    B00000, B00000, B00000, B11111, B00000,
    B00000, B00000, B00000, B11111, B00000,
    B00000, B11111, B11111, B11111, B01110,
    B00000, B11111, B11111, B11111, B01110,
    B00000, B11111, B11111, B11111, B01110};

   /* 32 = 0x20 = space */
   const unsigned char LcdNewChars = 5;
   const char bignumchars1[]={4,1,4,0, 1,4,32,0, 3,3,4,0, 1,3,4,0, 4,2,4,0, 
                              4,3,3,0,  4,3,3,0, 1,1,4,0, 4,3,4,0, 4,3,4,0}; 
   const char bignumchars2[]={4,2,4,0, 2,4,2,0,   4,2,2,0, 2,2,4,0, 32,32,4,0, 
                              2,2,4,0, 4,2,4,0, 32,4,32,0, 4,2,4,0,   2,2,4,0};  

#elif (CFG_BIGFONT_TYPE == 2)
  /* XXX: For whatever reason I can not figure out how 
   * to store more than 8 chars in the LCD CGRAM */
  const char chars[] PROGMEM = {
    B11111, B00000, B11111, B11111, B00000, B11111, B00111, B11100, 
    B11111, B00000, B11111, B11111, B00000, B11111, B01111, B11110, 
    B00000, B00000, B00000, B11111, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B01110, B11111, B11111, B11111,
    B00000, B11111, B11111, B01111, B01110, B11110, B11111, B11111,
    B00000, B11111, B11111, B00111, B01110, B11100, B11111, B11111};

   /* 32 = 0x20 = space */
   /* 255 = 0xFF = all black character */
   const unsigned char LcdNewChars = 8;
   const char bignumchars1[]={  7,1,8,0,  1,255,32,0,   3,3,8,0, 1,3,8,0, 255,2,255,0,  
                              255,3,3,0,     7,3,3,0,   1,1,6,0, 7,3,8,0,     7,3,8,0};
   const char bignumchars2[]={  4,2,6,0, 32,255,32,0, 255,2,2,0, 2,2,6,0, 32,32,255,0,
                                2,2,6,0,     4,2,6,0, 32,7,32,0, 4,2,6,0,     2,2,6,0};
#endif

#if (BARGRAPH_DISPLAY_CFG == 1)
  const unsigned char LcdBarChars = 7;
  const char barchars[] PROGMEM = {
    B00000, B00000, B00000, B00000, B00000, B00000, B00000, 
    B00000, B00000, B00000, B00000, B00000, B00000, B11111, 
    B00000, B00000, B00000, B00000, B00000, B11111, B11111, 
    B00000, B00000, B00000, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B11111, B11111, B11111, 
    B00000, B00000, B11111, B11111, B11111, B11111, B11111, 
    B00000, B11111, B11111, B11111, B11111, B11111, B11111, 
    B11111, B11111, B11111, B11111, B11111, B11111, B11111};

  /* map numbers to bar segments.  Example:
   * ascii_barmap[10] --> all eight segments filled in
   * ascii_barmap[4]  --> four segments filled in */
  const char ascii_barmap[] = {0x20, 0x00, 0x01, 0x02, 0x03, 0x04, 
                               0x05, 0x06, 0xFF, 0xFF, 0xFF}; 
#endif


static void putCharsToLCD(LiquidCrystal *lcd, const char *newchars, unsigned char numnew) {
   unsigned char x, y;
   unsigned char new_glyph[8];

#if (1)
   Serial.print("putChars\n");
#endif

   /* write the character data to the character generator ram */
   for(x=0; x<numnew; x++) {
      memset(new_glyph, 0, sizeof(new_glyph));
      for(y=0; y<LcdCharHeightPix; y++) {
        new_glyph[y] = pgm_read_byte(&newchars[y*numnew+x]);
      }

#if (1)  /* debugging */
      Serial.print("\n");
      for(y=0; y<LcdCharHeightPix; y++) {
        Serial.print(new_glyph[y], HEX);
        Serial.print(" ");
      }
      Serial.print("Sending char...");
      Serial.print(x);
      Serial.print("\n");
#endif

      lcd->createChar(x, new_glyph);
   }

   lcd->clear();
   lcd->home();
}


