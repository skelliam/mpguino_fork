#define Filter_coeff    100  /* higher number = more filtering */

void CALC_FILTERED_TEMP(void);
void INIT_OUTSIDE_TEMP(void);

extern signed long OUTSIDE_TEMP_FILT;
extern signed long OUTSIDE_TEMP_HOLD;
