#ifndef LIQUIDCRYSTALEXTEND_H
#define LIQUIDCRYSTALEXTEND_H
#include <LiquidCrystal.h>

class LiquidCrystalExtend : public LiquidCrystal {
   public:
      LiquidCrystalExtend(int pin1, int pin2, int pin3, int pin4, int pin5, int pin6)
         : LiquidCrystal(pin1, pin2, pin3, pin4, pin5, pin6)
      {
      }
      void writechars(char * bytes, int num);
};


#endif
