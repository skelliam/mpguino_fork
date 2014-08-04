#include "utils.h"

char * uformat(unsigned long val) { 
   static char buf[BUFSIZE];  /* 10 digits + null */
   unsigned char digit, i = BUFSIZE;

   buf[i--] = 0;   /* terminating null */

   /* keep shifting off ones place digit */
   while (val >= 10) {
      digit = (val - ((val / 10) * 10));  /* get the ones place digit */
      val /= 10;  /* shift off the 10's place digit */
      buf[i--] = getAsciiFromDigit(digit);
   }
   buf[i] = getAsciiFromDigit(val);  /* the last digit is in position "i" */

   return &buf[i];  /* return value starting with position i */
}


unsigned long rformat(char * val, unsigned char len) { 
   unsigned long d = 1000000000ul;
   unsigned long v = 0ul;

   for (unsigned char p = 0; p < len ; p++) {
      v = v+(d*(getDigitFromAscii(val[p])));
      d /= 10;
   }

   return v;
} 

/* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
 * format:
 * Take an unsigned long and convert it to a string value that we can display.
 * The function will always divide the input by 1000 and display the result.
 * Some examples with output:
 * 
 * format(1000)    --> "001.00"
 * format(123456)  --> "123.46"  (note rounding of last digit)
 * format(1000000) --> "1000.0"
 * format(100000)  --> "100.00"
 *
 * Question:  Why doesn't this function require the special 
 *            unsigned long math?
 * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * */
 
char *format(unsigned long num) {
   static char fBuff[7];  //used by format
   unsigned char decimalpointpos = 3;
   unsigned char x = 6;

   while (num > 999994) {
      num /= 10;
      decimalpointpos++;
      if( decimalpointpos == 5 ) break; /* We'll lose the top numbers like an odometer */
   }
   if (decimalpointpos == 5) {
      decimalpointpos = 99;
   }                       /* We don't need a decimal point here. */

   /* Round off the non-printed value. */
   if((num % 10) > 4) {
      num += 10;
   }

   num /= 10;

   while (x > 0) {
      x--;
      if (x == decimalpointpos) {
         /* time to poke in the decimal point? */
         fBuff[x]='.';
      }
      else {
         if ( ((x+1) == decimalpointpos) && (num == 0) ) {
            /* decimal point just inserted and nothing left, put in a zero */
            fBuff[x]='0';
         }
         else if ( (x < decimalpointpos) && (num == 0) ) {
            /* we have more to go and decimal point already done, put in spaces */
            fBuff[x]=' ';
         }
         else {
            /* poke the ascii character for the digit. */
            fBuff[x]= getAsciiFromDigit((num % 10));
         }
         num /= 10;
      }
   }

   fBuff[6] = 0;  //terminating null
   return fBuff;
}

//get a string from flash 
char *getStr(const char * str) { 
   static char mBuff[17]; //used by getStr 
   strcpy_P(mBuff, str); 
   return mBuff; 
} 

// this function will return the number of bytes currently free in RAM      
int memoryTest(void){ 
  int free_memory; 
  if((int)__brkval == 0) 
    free_memory = ((int)&free_memory) - ((int)&__bss_end); 
  else 
    free_memory = ((int)&free_memory) - ((int)__brkval); 
  return free_memory; 
} 


int insert(int *array, int val, size_t size, size_t at)
{
   size_t i;

   /* In range? */
   if (at >= size) return -1;

   /* Shift elements to make a hole */
   for (i = size - 1; i > at; i--) {
      array[i] = array[i - 1];
   }

   /* Insertion! */
   array[at] = val;

   return 0;
}
 
void writeEepBlock32(unsigned int start_addr, unsigned long *val, unsigned int size) {
   unsigned char p = 0;
   unsigned char shift = 0;
   int i = 0;
   for (start_addr; p < size; start_addr+=4) {
      for (i=0; i<4; i++) {
         shift = (8 * (3-i));  /* 24, 16, 8, 0 */
         EEPROM.write(start_addr + i, (val[p]>>shift) & 0xFF);
      }
      p++;
   }
}

void readEepBlock32(unsigned int start_addr, unsigned long *val, unsigned int size) {
   unsigned long v = 0;
   unsigned char p = 0;
   unsigned char temp = 0;
   unsigned char i = 0;
   for(start_addr; p < size; start_addr+=4) {
      v = 0;   /* clear the scratch variable every loop! */
      for (i=0; i<4; i++) {
         temp = (i > 0) ? 1 : 0;  /* 0, 1, 1, 1  */
         v = (v << (temp * 8)) + EEPROM.read(start_addr + i);
      }
      val[p] = v;
      p++;
   }
}
