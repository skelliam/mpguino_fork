#ifndef UTILS_H
#define UTILS_H

#define getAsciiFromDigit(int_digit)         ('0' + int_digit)
#define getDigitFromAscii(ascii_digit)       (ascii_digit - '0')

#define MIN(value1, value2)\
    (((value1)>=(value2)) ? (value2) : (value1))

#define MAX(value2, value1)\
    (((value1)>=(value2)) ? (value1) : (value2))

#define length(x) (sizeof x / sizeof *x)

#endif
