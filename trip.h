class Trip{      
   public:      
     enum varnames { loopCount=0, 
                     injPulses, 
                     injHiSec, 
                     injHius, 
                     injIdleHiSec, 
                     injIdleHius, 
                     vssPulses, 
                     vssEOCPulses, 
                     vssPulseLength,
                     varCount };       /* this is always last ! */

     unsigned long var[varCount];

     /* ----
        loopCount      -- how long has this trip been running      
        injPulses      -- rpm      
        injHiSec       -- seconds the injector has been open      
        injHius        -- microseconds, fractional part of the injectors open
        injIdleHiSec   -- seconds the injector has been open
        injIdleHius    -- microseconds, fractional part of the injectors open
        vssPulses      -- from the speedo
        vssEOCPulses   -- from the speedo
        vssPulseLength -- only used by instant
     ---- */

     //these functions actually return in thousandths,       
     unsigned long miles();        
     unsigned long gallons();      
     unsigned long mpg();        
     unsigned long mph();        
     unsigned long time();         //mmm.ss        
     unsigned long eocMiles();     //how many "free" miles?        
     unsigned long idleGallons();  //how many gallons spent at 0 mph?        
     unsigned long fuelCost();
     void update(Trip t);      
     void reset();      
     Trip();      
};      
 

