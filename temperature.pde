#include "mpguino_conf.h"

#if (OUTSIDE_TEMP_CFG == 1)

#include "temperature.h"

signed long OUTSIDE_TEMP_RAW;
signed long OUTSIDE_TEMP_FILT;
signed long OUTSIDE_TEMP_OLD;

void INIT_OUTSIDE_TEMP() {
   /* initialize all values so we don't have to wait for the filtered value */
   OUTSIDE_TEMP_RAW = READ_RAW_TEMP();
   OUTSIDE_TEMP_FILT = OUTSIDE_TEMP_RAW;
   OUTSIDE_TEMP_OLD = OUTSIDE_TEMP_RAW;
}

/******************************************************
 *                               5000 mV            
 *   degC x10 = Vout (bits)  *  -------  - 500 mV
 *                              1024 bits         
 *   
 *   5000/1024 = 625/128 (simplified)
 *
 *   ((degC x10 * 9)/5) + 320  =  degF x10
 ******************************************************/
signed long READ_RAW_TEMP() {
   signed long temperature;
   temperature = analogRead(1);                /* 0.004882 V/bit */
   temperature = (temperature * 625)/128; 
   temperature -= 500;                         /* offset 500 mV to get degC x10 */
   temperature = (temperature * 9 / 5) + 320;  /* degF x10 */
   temperature *= 100;                         /* degF x1000 for formatting functions */  
   return temperature;
}

void CALC_FILTERED_TEMP() {
   OUTSIDE_TEMP_RAW = READ_RAW_TEMP();
   OUTSIDE_TEMP_OLD = OUTSIDE_TEMP_FILT;
   OUTSIDE_TEMP_FILT += (OUTSIDE_TEMP_RAW-OUTSIDE_TEMP_OLD)/Filter_coeff;
}
#endif
