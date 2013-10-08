#define getAsciiFromDigit(int_digit)         ('0' + int_digit)
#define getDigitFromAscii(ascii_digit)       (ascii_digit - '0')

#define MIN(value1, value2)\
    (((value1) >= (value2)) ? (value2) : (value1))

#define MAX(value2, value1)\
    (((value1)>=(value2)) ? (value1) : (value2))

#define Limit(x, min, max)                   MIN(MAX(x,min),max)

#define length(x) (sizeof x / sizeof *x)
