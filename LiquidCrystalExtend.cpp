#include "LiquidCrystalExtend.h"

// here is the extension
void LiquidCrystalExtend::writechars(char * bytes, int num) {
   int i = 0;
   for (i=0; i<num; i++) {
      this->write(bytes[i]);
   }
}

