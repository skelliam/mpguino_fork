#ifndef UTILS_H
#define UTILS_H

#include <EEPROM.h>

#define ASCII_ZERO                           ((unsigned char)0x30)
#define getAsciiFromDigit(int_digit)         (ASCII_ZERO + int_digit)
#define getDigitFromAscii(ascii_digit)       (ascii_digit - ASCII_ZERO)
#define BUFSIZE                              11

#define MIN(value1, value2)\
    (((value1)>=(value2)) ? (value2) : (value1))

#define MAX(value2, value1)\
    (((value1)>=(value2)) ? (value1) : (value2))

#define LIMIT(value, min, max)\
   ((value > max) ? max : ((value < min) ? min : value))

#define LIMITERR(value, min, max, err)\
   ((value > max) ? err : ((value < min) ? err : value))

#define length(x) (sizeof(x) / sizeof(*x))


/* function prototypes */
/* misc utils */
char * uformat(unsigned long val);  /* convert ulong to string */
unsigned long rformat(char * val);  /* convert string to ulong */
char *format(unsigned long num);    /* format ulong to decimal for display */
char *getStr(const char * str);     /* get string from flash mem */
int memoryTest(void);               /* see how much ram is free */
int insert(int *array, int val, size_t size, size_t at);  /* insert into array */
/* eeprom functions */
void writeEepBlock32(unsigned int start_addr, unsigned long *val, unsigned int size);
void readEepBlock32(unsigned int start_addr, unsigned long *val, unsigned int size);
#endif
