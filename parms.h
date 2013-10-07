#define loopsPerSecond                         2   
#define looptime 1000000ul/loopsPerSecond /* 0.5 second */


enum longparms { contrastIdx = 0, 
                 vssPulsesPerMileIdx, 
                 microSecondsPerGallonIdx, 
                 injPulsesPer2Revolutions, 
                 currentTripResetTimeoutUSIdx, 
                 tankSizeIdx, 
                 injectorSettleTimeIdx, 
                 weightIdx, 
                 scratchpadIdx, 
                 vsspauseIdx,
                 fuelcostIdx,
                 parmsCount };  /* this is always last */

extern unsigned long parms[parmsCount];
extern char *parmLabels[parmsCount];
