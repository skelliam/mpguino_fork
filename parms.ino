/* default values */
unsigned long parms[]={
   95ul,               /* contrast                                  */
   8208ul,             /* pulses per mile                           */
   500000000ul,        /* us per gallon            1 us/gal/bit?    */
   3ul,                /* pulses per 2 rev                          */
   420000000ul,        /* current trip reset timeout                */
   10300ul,            /* tank size                0.001 gal/bit    */
   500ul,              /* injector settle time                      */
   2400ul,             /* weight                   1 lb/bit         */
   0ul,                /* scratchpad                                */
   2ul,                /* vsspause                                  */
   300ul,              /* fuel cost                0.01 dollars/bit */
};

#if (0)
char *parmLabels[]={
   "Contrast",
   "VSS Pulses/Mile", 
   "MicroSec/Gallon",
   "Pulses/2 revs",
   "Timout(microSec)",
   "Tank Gal * 1000",
   "Injector DelayuS",
   "Weight (lbs)",
   "Scratchpad(odo?)",
   "VSS Delay ms",
   "Fuel Cost($/gal)"
};
#else
char *parmLabels[]={
   "Cntrast:",
   "Pls/mi:", 
   "us/gal:",
   "Pls/2revs:",
   "Timeout (min):",
   "Tank_gal:",
   "Inj_dlay:",
   "Weight:",
   "Memo:",
   "Vss_dlay:",
   "Fuelcost:"
};
#endif

