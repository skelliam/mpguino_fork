
#include "trip.h"
#include "mathfuncs.h"
#include "parms.h"

Trip::Trip() {      

}      

unsigned long Trip::miles(){      
   unsigned long tmp1[2];
   unsigned long tmp2[2];
   unsigned long tmp3[2];
   init64(tmp1,0,var[Trip::vssPulses]);
   init64(tmp2,0,1000);
   mul64(tmp1,tmp2);
   init64(tmp2,0,parms[vssPulsesPerMileIdx]);
   div64(tmp1,tmp2);
   return tmp1[1];      
}      
 
unsigned long Trip::eocMiles(){      
   unsigned long tmp1[2];
   unsigned long tmp2[2];
   unsigned long tmp3[2];
   init64(tmp1,0,var[Trip::vssEOCPulses]);
   init64(tmp2,0,1000);
   mul64(tmp1,tmp2);
   init64(tmp2,0,parms[vssPulsesPerMileIdx]);
   div64(tmp1,tmp2);
   return tmp1[1];      
}       
 
unsigned long Trip::mph(){      
   unsigned long tmp1[2];
   unsigned long tmp2[2];
   unsigned long tmp3[2];
   if(var[Trip::loopCount] == 0)     
      return 0;     
   init64(tmp1,0,loopsPerSecond);
   init64(tmp2,0,var[Trip::vssPulses]);
   mul64(tmp1,tmp2);
   init64(tmp2,0,3600000);
   mul64(tmp1,tmp2);
   init64(tmp2,0,parms[vssPulsesPerMileIdx]);
   div64(tmp1,tmp2);
   init64(tmp2,0,var[Trip::loopCount]);
   div64(tmp1,tmp2);
   return tmp1[1];      
}      
 
unsigned long  Trip::gallons(){      
   unsigned long tmp1[2];
   unsigned long tmp2[2];
   unsigned long tmp3[2];
   init64(tmp1,0,var[Trip::injHiSec]);
   init64(tmp2,0,1000000);
   mul64(tmp1,tmp2);
   init64(tmp2,0,var[Trip::injHius]);
   add64(tmp1,tmp2);
   init64(tmp2,0,1000);
   mul64(tmp1,tmp2);
   init64(tmp2,0,parms[microSecondsPerGallonIdx]);
   div64(tmp1,tmp2);
   return tmp1[1];      
}      

unsigned long  Trip::idleGallons(){      
   unsigned long tmp1[2];
   unsigned long tmp2[2];
   unsigned long tmp3[2];
   init64(tmp1,0,var[Trip::injIdleHiSec]);
   init64(tmp2,0,1000000);
   mul64(tmp1,tmp2);
   init64(tmp2,0,var[Trip::injIdleHius]);
   add64(tmp1,tmp2);
   init64(tmp2,0,1000);
   mul64(tmp1,tmp2);
   init64(tmp2,0,parms[microSecondsPerGallonIdx]);
   div64(tmp1,tmp2);
   return tmp1[1];      
}      

unsigned long  Trip::fuelCost(){
   unsigned long tmp1[2];
   unsigned long tmp2[2];
   unsigned long tmp3[2];
   init64(tmp1,0,(Trip::gallons()));  /* 0.001 gal/bit */
   init64(tmp2,0,parms[fuelcostIdx]); /* 0.01 dollars/bit */
   mul64(tmp1,tmp2);
   init64(tmp2,0,100);
   div64(tmp1,tmp2);
   return tmp1[1];
}

 
unsigned long  Trip::mpg(){      
   unsigned long tmp1[2];
   unsigned long tmp2[2];
   unsigned long tmp3[2];
   if(var[Trip::vssPulses]==0) return 0;      
   if(var[Trip::injPulses]==0) return 999999000; //who doesn't like to see 999999?  :)      
 
   init64(tmp1,0,var[Trip::injHiSec]);
   init64(tmp3,0,1000000);
   mul64(tmp3,tmp1);
   init64(tmp1,0,var[Trip::injHius]);
   add64(tmp3,tmp1);
   init64(tmp1,0,parms[vssPulsesPerMileIdx]);
   mul64(tmp3,tmp1);
 
   init64(tmp1,0,parms[microSecondsPerGallonIdx]);
   init64(tmp2,0,1000);
   mul64(tmp1,tmp2);
   init64(tmp2,0,var[Trip::vssPulses]);
   mul64(tmp1,tmp2);
 
   div64(tmp1,tmp3);
   return tmp1[1];      
}      
 
//return the seconds as a time mmm.ss, eventually hhh:mm too      
unsigned long Trip::time(){      
   //  return seconds*1000;      
   unsigned char d = 60;      
   unsigned long seconds = var[Trip::loopCount]/loopsPerSecond;     
   return ((seconds/d)*1000) + ((seconds%d) * 10);       
}      
 
 
void Trip::reset(){      
   var[Trip::loopCount]=0;      
   var[Trip::injPulses]=0;      
   var[Trip::injHius]=0;      
   var[Trip::injHiSec]=0;      
   var[Trip::vssPulses]=0;  
   var[Trip::vssPulseLength]=0;
   var[Trip::injIdleHiSec]=0;
   var[Trip::injIdleHius]=0;
   var[Trip::vssEOCPulses]=0;
}      
 
void Trip::update(Trip t) {     
   var[Trip::loopCount]++;  //we call update once per loop     
   var[Trip::vssPulses]+=t.var[Trip::vssPulses];      
   var[Trip::vssPulseLength]+=t.var[Trip::vssPulseLength];
   if ( t.var[Trip::injPulses] == 0 )  //track distance traveled with engine off
   var[Trip::vssEOCPulses]+=t.var[Trip::vssPulses];

   if ( t.var[Trip::injPulses] > 2 && t.var[Trip::injHius]<500000 ) {// chasing ghosts      
      var[Trip::injPulses]+=t.var[Trip::injPulses];      
      var[Trip::injHius]+=t.var[Trip::injHius];      
      if (var[Trip::injHius]>=1000000){  
         // rollover into the var[Trip::injHiSec] counter      
         var[Trip::injHiSec]++;      
         var[Trip::injHius]-=1000000;      
      }
      if(t.var[Trip::vssPulses] == 0) {    
         // track gallons spent sitting still
         var[Trip::injIdleHius]+=t.var[Trip::injHius];      
         if (var[Trip::injIdleHius]>=1000000) {  //r
            var[Trip::injIdleHiSec]++;
            var[Trip::injIdleHius]-=1000000;      
         }      
      }
   }      
}   
 


