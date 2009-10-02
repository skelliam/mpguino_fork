#define Filter_coeff    400  /* higher number = more filtering */

void CALC_FILTERED_TEMP(void);
void INIT_OUTSIDE_TEMP(void);

extern signed long OUTSIDE_TEMP_FILT;
