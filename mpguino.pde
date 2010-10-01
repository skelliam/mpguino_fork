/* YOU NEED TO USE ARDUINO VERSION 0011 !!!!!!  */
//it won't fit with the new math libraries that come with 0012, sorry.
//GPL Software    

#include <EEPROM.h>
#include "mpguino.h"
#include "lcd.h"

/* --- Global Variable Declarations -------------------------- */

unsigned long MAXLOOPLENGTH = 0;            // see if we are overutilizing the CPU      

//for display computing
static unsigned long tmp1[2];
static unsigned long tmp2[2];
static unsigned long tmp3[2];

#if (CFG_BIGFONT_TYPE == 1)
  static char chars[] PROGMEM = {
    B11111, B00000, B11111, B11111, B00000,
    B11111, B00000, B11111, B11111, B00000,
    B11111, B00000, B11111, B11111, B00000,
    B00000, B00000, B00000, B11111, B00000,
    B00000, B00000, B00000, B11111, B00000,
    B00000, B11111, B11111, B11111, B01110,
    B00000, B11111, B11111, B11111, B01110,
    B00000, B11111, B11111, B11111, B01110};
#elif (CFG_BIGFONT_TYPE == 2)
  /* XXX: For whatever reason I can not figure out how 
   * to store more than 8 chars in the LCD CGRAM */
  static char chars[] PROGMEM = {
    B11111, B00000, B11111, B11111, B00000, B11111, B00111, B11100, 
    B11111, B00000, B11111, B11111, B00000, B11111, B01111, B11110, 
    B00000, B00000, B00000, B11111, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B01110, B11111, B11111, B11111,
    B00000, B11111, B11111, B01111, B01110, B11110, B11111, B11111,
    B00000, B11111, B11111, B00111, B01110, B11100, B11111, B11111};
#endif

#if (BARGRAPH_DISPLAY_CFG == 1)
  const unsigned char LcdBarChars = 7;
  static char barchars[] PROGMEM = {
    B00000, B00000, B00000, B00000, B00000, B00000, B00000, 
    B00000, B00000, B00000, B00000, B00000, B00000, B11111, 
    B00000, B00000, B00000, B00000, B00000, B11111, B11111, 
    B00000, B00000, B00000, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B11111, B11111, B11111, 
    B00000, B00000, B11111, B11111, B11111, B11111, B11111, 
    B00000, B11111, B11111, B11111, B11111, B11111, B11111, 
    B11111, B11111, B11111, B11111, B11111, B11111, B11111};

  /* map numbers to bar segments.  Example:
   * ascii_barmap[10] --> all eight segments filled in
   * ascii_barmap[4]  --> four segments filled in */
  char ascii_barmap[] = {0x20, 0x01, 0x02, 0x03, 0x04, 0x05, 
                         0x06, 0x07, 0xFF, 0xFF, 0xFF}; 
#endif

#if (CFG_BIGFONT_TYPE == 1)
   /* 32 = 0x20 = space */
   const unsigned char LcdNewChars = 5;
   char bignumchars1[]={4,1,4,0, 1,4,32,0, 3,3,4,0, 1,3,4,0, 4,2,4,0, 
                        4,3,3,0,  4,3,3,0, 1,1,4,0, 4,3,4,0, 4,3,4,0}; 
   char bignumchars2[]={4,2,4,0, 2,4,2,0,   4,2,2,0, 2,2,4,0, 32,32,4,0, 
                        2,2,4,0, 4,2,4,0, 32,4,32,0, 4,2,4,0,   2,2,4,0};  
#elif (CFG_BIGFONT_TYPE == 2)
   /* 32 = 0x20 = space */
   /* 255 = 0xFF = all black character */
   const unsigned char LcdNewChars = 8;
   char bignumchars1[]={  7,1,8,0,  1,255,32,0,   3,3,8,0, 1,3,8,0, 255,2,255,0,  
                        255,3,3,0,     7,3,3,0,   1,1,6,0, 7,3,8,0,     7,3,8,0};
   char bignumchars2[]={  4,2,6,0, 32,255,32,0, 255,2,2,0, 2,2,6,0, 32,32,255,0,
                          2,2,6,0,     4,2,6,0, 32,7,32,0, 4,2,6,0,     2,2,6,0};
#endif

//middle button cycles through these brightness settings      
unsigned char brightness[]={255,214,171,128};
unsigned char brightnessIdx=1;

#define brightnessLength (sizeof(brightness)/sizeof(unsigned char)) //array size

volatile unsigned long timer2_overflow_count;

/* --- End Global Variable Declarations ---------------------- */


/*** Set up the Events ***
We have our own ISR for timer2 which gets called about once a millisecond.
So we define certain event functions that we can schedule by calling addEvent
with the event ID and the number of milliseconds to wait before calling the event. 
The milliseconds is approximate.

Keep the event functions SMALL!!!  This is an interrupt!

*/
//event functions

void enableLButton(){PCMSK1 |= (1 << PCINT11);}
void enableMButton(){PCMSK1 |= (1 << PCINT12);}
void enableRButton(){PCMSK1 |= (1 << PCINT13);}
//array of the event functions
pFunc eventFuncs[] ={enableVSS, enableLButton,enableMButton,enableRButton};
#define eventFuncSize (sizeof(eventFuncs)/sizeof(pFunc)) 
//define the event IDs
#define enableVSSID 0
#define enableLButtonID 1
#define enableMButtonID 2
#define enableRButtonID 3
//ms counters
unsigned int eventFuncCounts[eventFuncSize];

//schedule an event to occur ms milliseconds from now
void addEvent(unsigned char eventID, unsigned int ms){
   if(ms == 0) {
      eventFuncs[eventID]();
   }
   else {
      eventFuncCounts[eventID]=ms;
   }
}

/* this ISR gets called every 1.024 milliseconds, we will call that a 
 * millisecond for our purposes go through all the event counts, if any 
 * are non zero subtract 1 and call the associated function if it just 
 * turned zero.  */
ISR(TIMER2_OVF_vect) {
   unsigned char eventID;
   timer2_overflow_count++;
   for(eventID = 0; eventID < eventFuncSize; eventID++) {
      if(eventFuncCounts[eventID]!= 0) {
         eventFuncCounts[eventID]--;
         if(eventFuncCounts[eventID] == 0) {
            eventFuncs[eventID](); 
         }
      }  
   }
} /* ISR(TIMER2_OVF_vect) */

unsigned char buttonState = buttonsUp;      
 
//overflow counter used by millis2()      
unsigned long lastMicroSeconds=millis2() * 1000;   
unsigned long microSeconds(void) {     
   unsigned long tmp_timer2_overflow_count;    
   unsigned long tmp;    
   unsigned char tmp_tcnt2;    
   cli(); //disable interrupts    
   tmp_timer2_overflow_count = timer2_overflow_count;    
   tmp_tcnt2 = TCNT2;    
   sei(); // enable interrupts    
   tmp = ((tmp_timer2_overflow_count << 8) + tmp_tcnt2) * 4;     
   if((tmp<=lastMicroSeconds) && (lastMicroSeconds<4290560000ul)) {
      return microSeconds();     
   }
   lastMicroSeconds=tmp;   
   return tmp;     
}    
 
unsigned long elapsedMicroseconds(unsigned long startMicroSeconds, unsigned long currentMicroseconds) {      
   if(currentMicroseconds >= startMicroSeconds) {
      return currentMicroseconds-startMicroSeconds;      
   }
   return 0xFFFFFFFF - (startMicroSeconds-currentMicroseconds);      
}      

unsigned long elapsedMicroseconds(unsigned long startMicroSeconds ){      
   return elapsedMicroseconds(startMicroSeconds, microSeconds());
}      
 
 
//main objects we will be working with:      
unsigned long injHiStart; //for timing injector pulses      
Trip tmpTrip;      
Trip instant;      
Trip current;      
Trip tank;
#if (BARGRAPH_DISPLAY_CFG == 1)
Trip periodic;
#endif

unsigned volatile long instInjStart=nil; 
unsigned volatile long tmpInstInjStart=nil; 
unsigned volatile long instInjEnd; 
unsigned volatile long tmpInstInjEnd; 
unsigned volatile long instInjTot; 
unsigned volatile long tmpInstInjTot;     
unsigned volatile long instInjCount; 
unsigned volatile long tmpInstInjCount;     


void processInjOpen(void){      
   injHiStart = microSeconds();  
}      
 
void processInjClosed(void){      
   long t =  microSeconds();
   long x = elapsedMicroseconds(injHiStart, t) - parms[injectorSettleTimeIdx];       
   if (x >0) {
      tmpTrip.var[Trip::injHius] += x;
   }
   tmpTrip.var[Trip::injPulses]++;      
   if (tmpInstInjStart != nil) {
      if (x >0) {
         tmpInstInjTot += x;
      }
      tmpInstInjCount++;
   } 
   else {
      tmpInstInjStart = t;
   }
   tmpInstInjEnd = t;
}

volatile boolean vssFlop = 0;

void enableVSS(){
   /*  tmpTrip.var[Trip::vssPulses]++;  */
   vssFlop = !vssFlop;
}

unsigned volatile long lastVSS1;
unsigned volatile long lastVSSTime;
unsigned volatile long lastVSS2;

volatile boolean lastVssFlop = vssFlop;

//attach the vss/buttons interrupt      
ISR(PCINT1_vect) {   
   static unsigned char vsspinstate=0;      
   unsigned char p = PINC;//bypassing digitalRead for interrupt performance      

   if ((p & vssBit) != (vsspinstate & vssBit)){      
      addEvent(enableVSSID, parms[vsspauseIdx]); //check back in a couple milli
   }
   if (lastVssFlop != vssFlop) {
      lastVSS1=lastVSS2;
      unsigned long t = microSeconds();
      lastVSS2=elapsedMicroseconds(lastVSSTime,t);
      lastVSSTime=t;
      tmpTrip.var[Trip::vssPulses]++; 
      tmpTrip.var[Trip::vssPulseLength] += lastVSS2;
      lastVssFlop = vssFlop;
   }
   vsspinstate = p;      
   buttonState &= p;      
} /* ISR(PCINT1_vect) */
 
 
pFunc displayFuncs[] ={ 
   doDisplayCustom, 
   doDisplayInstantCurrent, 
   doDisplayInstantTank, 
   doDisplayBigInstant, 
   doDisplayBigCurrent, 
   doDisplayBigTank, 
   doDisplayCurrentTripData, 
   doDisplayTankTripData, 
   doDisplayEOCIdleData, 
   doDisplaySystemInfo,
   #if (BARGRAPH_DISPLAY_CFG == 1)
   doDisplayBarGraph,
   #endif
   #if (DTE_CFG == 1)
   doDisplayBigDTE,
   #endif
};      

#define displayFuncSize (sizeof(displayFuncs)/sizeof(pFunc)) //array size      

prog_char  * displayFuncNames[displayFuncSize]; 
unsigned char newRun = 0;

void setup (void) {
   unsigned char x = 0;

   CLOCK = 0;
   SCREEN = 0;
   HOLD_DISPLAY = 0;

   #if (CFG_IDLE_MESSAGE != 0)
   IDLE_DISPLAY_DELAY = 0;
   #endif

   init2();
   newRun = load();//load the default parameters

   displayFuncNames[x++]=  PSTR("Custom  "); 
   displayFuncNames[x++]=  PSTR("Instant/Current "); 
   displayFuncNames[x++]=  PSTR("Instant/Tank "); 
   displayFuncNames[x++]=  PSTR("BIG Instant "); 
   displayFuncNames[x++]=  PSTR("BIG Current "); 
   displayFuncNames[x++]=  PSTR("BIG Tank "); 
   displayFuncNames[x++]=  PSTR("Current "); 
   displayFuncNames[x++]=  PSTR("Tank "); 
   displayFuncNames[x++]=  PSTR("EOC mi/Idle gal "); 
   displayFuncNames[x++]=  PSTR("CPU Monitor ");      
   #if (BARGRAPH_DISPLAY_CFG == 1)
   displayFuncNames[x++]=  PSTR("Bargraph ");
   #endif
   #if (DTE_CFG == 1)
   displayFuncNames[x++]=  PSTR("BIG DTE ");
   #endif

   pinMode(BrightnessPin,OUTPUT);      
   analogWrite(BrightnessPin,brightness[brightnessIdx]);      
   pinMode(EnablePin,OUTPUT);       
   pinMode(DIPin,OUTPUT);       
   pinMode(DB4Pin,OUTPUT);       
   pinMode(DB5Pin,OUTPUT);       
   pinMode(DB6Pin,OUTPUT);       
   pinMode(DB7Pin,OUTPUT);       
   delay2(500);      

   pinMode(ContrastPin,OUTPUT);      
   analogWrite(ContrastPin,parms[contrastIdx]);  
   LCD::init();      
   LCD::LcdCommandWrite(LCD_ClearDisplay);            // clear display, set cursor position to zero         
   LCD::LcdCommandWrite(LCD_SetDDRAM);                // set dram to zero
   LCD::print(getStr(PSTR("OpenGauge       ")));      
   LCD::gotoXY(0,1);      
   LCD::print(getStr(PSTR("  MPGuino v0.75S")));

   pinMode(InjectorOpenPin, INPUT);       
   pinMode(InjectorClosedPin, INPUT);       
   pinMode(VSSPin, INPUT);            
   attachInterrupt(0, processInjOpen, FALLING);      
   attachInterrupt(1, processInjClosed, RISING);      

   pinMode( lbuttonPin, INPUT );       
   pinMode( mbuttonPin, INPUT );       
   pinMode( rbuttonPin, INPUT );      

   //"turn on" the internal pullup resistors      
   digitalWrite( lbuttonPin, HIGH);       
   digitalWrite( mbuttonPin, HIGH);       
   digitalWrite( rbuttonPin, HIGH);       
   //  digitalWrite( VSSPin, HIGH);       

   //low level interrupt enable stuff      
   PCMSK1 |= (1 << PCINT8);
   enableLButton();
   enableMButton();
   enableRButton();
   PCICR |= (1 << PCIE1);       

   delay2(1500);       
} /* void setup (void) */
 
void loop (void) {
   unsigned long lastActivity;
   unsigned long tankHold;      //state at point of last activity
   unsigned long loopStart;
   unsigned long temp;          //scratch variable

   lastActivity = microSeconds();

   if(newRun !=1) {
      //go through the initialization screen
      initGuino();
   }

   while (true) {      
      #if (CFG_FUELCUT_INDICATOR != 0)
      FCUT_POS = 0;
      #endif
      loopStart = microSeconds();      
      instant.reset();           //clear instant      
      cli();
      instant.update(tmpTrip);   //"copy" of tmpTrip in instant now      
      tmpTrip.reset();           //reset tmpTrip first so we don't lose too many interrupts      
      instInjStart=tmpInstInjStart; 
      instInjEnd=tmpInstInjEnd; 
      instInjTot=tmpInstInjTot;     
      instInjCount=tmpInstInjCount;
      
      tmpInstInjStart=nil; 
      tmpInstInjEnd=nil; 
      tmpInstInjTot=0;     
      tmpInstInjCount=0;

      sei();

      #if (CFG_SERIAL_TX == 1)
      /* send out instantmpg * 1000, instantmph * 1000, the injector/vss raw data */
      simpletx(format(instantmpg()));
      simpletx(",");
      simpletx(format(instantmph()));
      simpletx(",");
      simpletx(format(instant.var[Trip::injHius]*1000));
      simpletx(",");
      simpletx(format(instant.var[Trip::injPulses]*1000));
      simpletx(",");
      simpletx(format(instant.var[Trip::vssPulses]*1000));
      simpletx("\n");
      #endif

      /* --- update all of the trip objects */
      current.update(instant);       //use instant to update current      
      tank.update(instant);          //use instant to update tank
      #if (BARGRAPH_DISPLAY_CFG == 1)
      if (lastActivity != nil) {
         periodic.update(instant);   //use instant to update periodic 
      }
      #endif

      #if (BARGRAPH_DISPLAY_CFG == 1)
      /* --- For bargraph: reset periodic every 2 minutes */
      if (periodic.var[Trip::loopCount] >= 240) {
         temp = MIN((periodic.mpg()/10), 0xFFFF);
         /* add temp into first element and shift items in array */
         insert((int*)PERIODIC_HIST, (unsigned short)temp, length(PERIODIC_HIST), 0);
         periodic.reset();   /* reset */
      }
      #endif

      /* --- Decide whether to go to sleep or wake up */
      if (    (instant.var[Trip::vssPulses] == 0) 
            && (instant.var[Trip::injPulses] == 0) 
            && (HOLD_DISPLAY==0) 
          ) 
      {
         if(   (elapsedMicroseconds(lastActivity) > parms[currentTripResetTimeoutUSIdx])
            && (lastActivity != nil)
           )
         {
            #if (TANK_IN_EEPROM_CFG)
            writeEepBlock32(eepBlkAddr_Tank, &tank.var[0], eepBlkSize_Tank);
            #endif
            #if (SLEEP_CFG & Sleep_bkl)
            analogWrite(BrightnessPin,brightness[0]);    //nitey night
            #endif
            #if (SLEEP_CFG & Sleep_lcd)
            LCD::LcdCommandWrite(LCD_DisplayOnOffCtrl);  //LCD off unless explicitly told ON
            #endif
            lastActivity = nil;
         }
      }
      else {
         /* wake up! */
         if (lastActivity == nil) {
            #if (SLEEP_CFG & Sleep_bkl)
            analogWrite(BrightnessPin,brightness[brightnessIdx]);    
            #endif
            #if (SLEEP_CFG & Sleep_lcd)
            /* Turn on the LCD again.  Display should be restored. */
            LCD::LcdCommandWrite(LCD_DisplayOnOffCtrl | LCD_DisplayOnOffCtrl_DispOn);
            /* TODO:  Does the above cause a problem if sleep happens during a settings mode? 
             *        Said another way, we don't get the cursor back unless we ask for it. */
            #endif
            lastActivity=loopStart;
            current.reset();
            tank.var[Trip::loopCount] = tankHold;
            current.update(instant); 
            tank.update(instant); 
            #if (BARGRAPH_DISPLAY_CFG == 1)
            periodic.reset();
            periodic.update(instant);
            #endif
         }
         else {
            lastActivity=loopStart;
            tankHold = tank.var[Trip::loopCount];
         }
      }
       

   if (HOLD_DISPLAY == 0) {

      #if (CFG_IDLE_MESSAGE == 0)
      displayFuncs[SCREEN]();    //call the appropriate display routine      
      #elif (CFG_IDLE_MESSAGE == 1)
      /* --- during idle, jump to EOC information */
      if (    (instant.var[Trip::injPulses] >  0) 
           && (instant.var[Trip::vssPulses] == 0) 
         ) 
      {
         /* the intention of the below logic is to avoid the display flipping 
            in stop and go traffic.  When you come to a stop, the delay timer 
            starts incrementing.  When you drive off, it decrements.  When the
            timer is zero, the display is always at the user-specified screen */
         if (IDLE_DISPLAY_DELAY < 6) {
            /* count up until delay time is reached */
            IDLE_DISPLAY_DELAY++;
         }
      }
      else {
         if (IdleDisplayRequested) {
            /* count from delay time back down to zero */
            IDLE_DISPLAY_DELAY--;
         }
         else if (IDLE_DISPLAY_DELAY < 0) {
            /* if the user selected a new screen while stopped, reset 
               the delay timer after driveoff */
            IDLE_DISPLAY_DELAY = 0;
         }
      }

      if (IdleDisplayRequested) {
         doDisplayEOCIdleData();
      }
      else {
         displayFuncs[SCREEN]();
      }
      #endif

      #if (CFG_FUELCUT_INDICATOR != 0)
      /* --- insert visual indication that fuel cut is happening */
      if (    (instant.var[Trip::injPulses] == 0) 
           && (instant.var[Trip::vssPulses] >  0) 
         ) 
      {
         #if (CFG_FUELCUT_INDICATOR == 1)
         LCDBUF1[FCUT_POS] = 'x';
         #elif ((CFG_FUELCUT_INDICATOR == 2) || (CFG_FUELCUT_INDICATOR == 3))
         LCDBUF1[FCUT_POS] = spinner[CLOCK & 0x03];
         #endif
      }
      #endif

      /* --- ensure that we have terminating nulls */
      LCDBUF1[16] = 0;
      LCDBUF2[16] = 0;

      /* print line 1 */
      LCD::LcdCommandWrite(LCD_ReturnHome);
      LCD::print(LCDBUF1);

      /* print line 2 */
      LCD::gotoXY(0,1);
      LCD::print(LCDBUF2);

      LCD::LcdCommandWrite(LCD_ReturnHome);

      /* --- see if any buttons were pressed, display a brief message if so --- */
      if (LeftButtonPressed && RightButtonPressed) {
         // left and right = initialize      
         LCD::print(getStr(PSTR("Setup ")));    
         initGuino();  
      }
      else if (LeftButtonPressed && MiddleButtonPressed) {
         // left and middle = tank reset      
         tank.reset();      
         LCD::print(getStr(PSTR("Tank Reset ")));      
      }
      else if (MiddleButtonPressed && RightButtonPressed) {
         // right and middle = current reset      
         current.reset();      
         LCD::print(getStr(PSTR("Current Reset ")));      
      }
      #if (CFG_IDLE_MESSAGE == 1)
      else if ((LeftButtonPressed || RightButtonPressed) && (IdleDisplayRequested)) {
         /* if the idle display is up and the user hits the left or right button,
          * intercept this press (nonoe of the elseifs will be hit below) 
          * only in this circumstance and get out of the idle display for a while.
          * This will return the user to his default screen. */
         IDLE_DISPLAY_DELAY = -60;
      }
      #endif
      else if (LeftButtonPressed) {
         // left is rotate through screeens to the left      
         if (SCREEN!=0) {
             SCREEN = (SCREEN-1);       
         }
         else {
            SCREEN=displayFuncSize-1;      
         }
         LCD::print(getStr(displayFuncNames[SCREEN]));      
      }
      else if (MiddleButtonPressed) {
         // middle is cycle through brightness settings      
         brightnessIdx = (brightnessIdx + 1) % brightnessLength;      
         analogWrite(BrightnessPin,brightness[brightnessIdx]);      
         LCD::print(getStr(PSTR("Brightness ")));      
         LCD::LcdDataWrite('0' + brightnessIdx);      
         LCD::print(" ");      
      }
      else if (RightButtonPressed) {
         // right is rotate through screeens to the left      
         SCREEN=(SCREEN+1)%displayFuncSize;      
         LCD::print(getStr(displayFuncNames[SCREEN]));      
      }      

      #if (CFG_IDLE_MESSAGE == 1)
      if (LeftButtonPressed || RightButtonPressed) {
         /* When the user wants to change screens, continue to 
          * avoid the idle screen for a while */
         IDLE_DISPLAY_DELAY = -60;
      }
      #endif

      if (buttonState!=buttonsUp) {
         HOLD_DISPLAY = 1;
      }

   }  /* if (HOLD_DISPLAY == 0) */
   else {
      HOLD_DISPLAY = 0;
   } 

   // reset the buttons      
   buttonState=buttonsUp;
    
   // keep track of how long the loops take before we go int waiting.      
   MAXLOOPLENGTH = MAX(MAXLOOPLENGTH, elapsedMicroseconds(loopStart));

   while (elapsedMicroseconds(loopStart) < (looptime)) {
      // wait for the end of the loop to arrive (0.5 sec)
      continue;
   }

   CLOCK++;

   } /* while (true) */
} /* loop (void) */
 
 
char *format(unsigned long num) {
   static char fBuff[7];  //used by format
   unsigned char dp = 3;
   unsigned char x = 6;

   while (num > 999999) {
      num /= 10;
      dp++;
      if( dp == 5 ) break; /* We'll lose the top numbers like an odometer */
   }
   if (dp == 5) {
      dp = 99;
   }                       /* We don't need a decimal point here. */

   /* Round off the non-printed value. */
   if((num % 10) > 4) {
      num += 10;
   }

   num /= 10;


   while (x > 0) {
      x--;
      if (x == dp) {
         /* time to poke in the decimal point? */
         fBuff[x]='.';
      }
      else {
         /* poke the ascii character for the digit. */
         fBuff[x]= '0' + (num % 10);
         num /= 10;
      }
   }

   fBuff[6] = 0;
   return fBuff;
}
 
//get a string from flash 
char *getStr(prog_char * str) { 
   static char mBuff[17]; //used by getStr 
   strcpy_P(mBuff, str); 
   return mBuff; 
} 

 
void doDisplayCustom() { 
   displayTripCombo('I','m',instantmpg(),'s',instantmph(),'G','H',instantgph(),'m',current.mpg());
}      

#if (0)
void doDisplayCustom() { 
   displayTripCombo('I','M',instantmpg(),'S',instantgph(),'R','P',instantrpm(),'C',current.var[Trip::injIdleHiSec]*1000);
}      

void doDisplayCustom() { 
   displayTripCombo('I','M',995,'S',994,'R','P',999994,'C',999995);
}      
#endif

void doDisplayEOCIdleData() {
   displayTripCombo('C','e',current.eocMiles(),'g',current.idleGallons(),'T','e',tank.eocMiles(),'g',tank.idleGallons());
}      

void doDisplayInstantCurrent() {
   displayTripCombo('I','m',instantmpg(),'s',instantmph(),'C','m',current.mpg(),'d',current.miles());
}      
 
void doDisplayInstantTank() {
   displayTripCombo('I','m',instantmpg(),'s',instantmph(),'T','m',tank.mpg(),'d',tank.miles());
}      

void doDisplayBigInstant() {
   bigNum(instantmpg(),"INST","MPG ");
}      

void doDisplayBigCurrent() {
   bigNum(current.mpg(),"CURR","MPG ");
}      

void doDisplayBigTank()    {
   bigNum(tank.mpg(),"TANK","MPG ");
}      

void doDisplayCurrentTripData(void) {
   /* display current trip formatted data */
   tDisplay(&current);
}   

void doDisplayTankTripData(void) {
   /* display tank trip formatted data */
   tDisplay(&tank);
}      

void doDisplaySystemInfo(void) {      
   /* display max cpu utilization and ram */
   strcpy(&LCDBUF1[0], "C%");
   strcpy(&LCDBUF1[2], format(MAXLOOPLENGTH*1000/(looptime/100)));
   strcpy(&LCDBUF1[8], " T");
   strcpy(&LCDBUF1[10], format(tank.time()));

   unsigned long mem = memoryTest();      
   mem*=1000;      
   strcpy(&LCDBUF2[0], "FREE MEM: ");
   strcpy(&LCDBUF2[10], format(mem));
}    

#if (BARGRAPH_DISPLAY_CFG == 1)
void doDisplayBarGraph(void) {
   signed char temp = 0;
   unsigned char i = 0;
   unsigned char j = 0;
   unsigned short stemp = 0;

   /* Load the bargraph characters if necessary */
   if (DISPLAY_TYPE != dtBarGraph) {
      LCD::writeCGRAM(&barchars[0], LcdBarChars);
      DISPLAY_TYPE = dtBarGraph;
   }

   /* plot bars */
   for(i=8; i>0; i--) {
      /* limit size -- print oldest first */
      stemp = MIN(PERIODIC_HIST[i-1], BAR_LIMIT)/10;
      /* round up if necessary */
      if ((stemp % 10) > 4) {
         stemp += 10;
      }
      /* convert to a number from 0-16 */
      temp = (signed char)((stemp * 16) / (BAR_LIMIT/10));
      temp = MIN(temp, 16);  /* should not be necessary... */
      /* line 1 graph */
      LCDBUF1[j] = ascii_barmap[MAX(temp-8,0)];
      /* line 2 graph */
      LCDBUF2[j] = ascii_barmap[MIN(temp,8)];
      j++;
   }
   
   if (CLOCK & 0x04) {
      /* end of line 1: show current mpg */
      LCDBUF1[8] = ' ';
      LCDBUF1[9] = 'C';
      strcpy(&LCDBUF1[10], format(current.mpg()));
   }
   else {
      LCDBUF1[8] = ' ';
      LCDBUF1[9] = '$';
      strcpy(&LCDBUF1[10], format(current.fuelCost()));
   }

   /* end of line 2: show periodic mpg */
   LCDBUF2[8] = ' ';
   LCDBUF2[9] = 'P';
   strcpy(&LCDBUF2[10], format(periodic.mpg()));

   #if (CFG_FUELCUT_INDICATOR != 0)
   /* where should the fuel cut indication go? */
   FCUT_POS = 8;
   #endif
}
#endif

#if (DTE_CFG == 1)
void doDisplayBigDTE(void) {
   unsigned long dte;
   signed long gals_remaining;
   /* TODO: user configurable safety factor see minus zero below */
   gals_remaining = (parms[tankSizeIdx] - tank.gallons()) - 0;  /* 0.001 gal/bit */
   gals_remaining = MAX(gals_remaining, 0);
   dte = gals_remaining * (tank.mpg()/100);                     /* mpg() = 0.1 mpg/bit */
   dte /= 10; /* divide by 10 here to avoid precision loss */
   /* dividing a signed long by 10 for some reason adds 100 bytes to program size?
    * otherwise I would've divided gals by 10 earlier! */
   bigNum(dte, "DIST", "TO E");
}
#endif
 
void displayTripCombo(char t1, char t1L1, unsigned long t1V1, char t1L2, unsigned long t1V2, 
                      char t2, char t2L1, unsigned long t2V1, char t2L2, unsigned long t2V2) {
   /* Process line 1 of the display */
   LCDBUF1[0] = t1;
   LCDBUF1[1] = t1L1;
   strcpy(&LCDBUF1[2], format(t1V1));
   LCDBUF1[8] = ' ';
   LCDBUF1[9] = t1L2;
   strcpy(&LCDBUF1[10], format(t1V2));

   /* Process line 2 of the display */
   LCDBUF2[0] = t2;
   LCDBUF2[1] = t2L1;
   strcpy(&LCDBUF2[2], format(t2V1));
   LCDBUF2[8] = ' ';
   LCDBUF2[9] = t2L2;
   strcpy(&LCDBUF2[10], format(t2V2));

   #if (CFG_FUELCUT_INDICATOR != 0)
   FCUT_POS = 8;
   #endif
}      
 
//arduino doesn't do well with types defined in a script as parameters, so have to pass as void * and use -> notation.      
void tDisplay( void * r){ //display trip functions.        
   Trip *t = (Trip *)r;      

   strcpy(&LCDBUF1[0], " s");
   strcpy(&LCDBUF1[2], format(t->mph()));
   strcpy(&LCDBUF1[8], " m");
   strcpy(&LCDBUF1[10], format(t->mpg()));

   strcpy(&LCDBUF2[0], " d");
   strcpy(&LCDBUF2[2], format(t->miles()));
   strcpy(&LCDBUF2[8], " g");
   strcpy(&LCDBUF2[10], format(t->gallons()));
}      
    
 
// this function will return the number of bytes currently free in RAM      
extern int  __bss_end; 
extern int  *__brkval; 
int memoryTest(){ 
  int free_memory; 
  if((int)__brkval == 0) 
    free_memory = ((int)&free_memory) - ((int)&__bss_end); 
  else 
    free_memory = ((int)&free_memory) - ((int)__brkval); 
  return free_memory; 
} 
 
Trip::Trip(){      
}      
 

unsigned long instantmph(){      
  //unsigned long vssPulseTimeuS = (lastVSS1 + lastVSS2) / 2;
  unsigned long vssPulseTimeuS = instant.var[Trip::vssPulseLength]/instant.var[Trip::vssPulses];
  
  init64(tmp1,0,1000000000ul);
  init64(tmp2,0,parms[vssPulsesPerMileIdx]);
  div64(tmp1,tmp2);
  init64(tmp2,0,3600);
  mul64(tmp1,tmp2);
  init64(tmp2,0,vssPulseTimeuS);
  div64(tmp1,tmp2);
  return tmp1[1];
}

unsigned long instantmpg(){     
  unsigned long imph=instantmph();
  unsigned long igph=instantgph();
  if(imph == 0) return 0;
  if(igph == 0) return 999999000;
  init64(tmp1,0,1000ul);
  init64(tmp2,0,imph);
  mul64(tmp1,tmp2);
  init64(tmp2,0,igph);
  div64(tmp1,tmp2);
  return tmp1[1];
}


unsigned long instantgph(){      
//  unsigned long vssPulseTimeuS = instant.var[Trip::vssPulseLength]/instant.var[Trip::vssPulses];
  
//  unsigned long instInjStart=nil; 
//unsigned long instInjEnd; 
//unsigned long instInjTot; 
  init64(tmp1,0,instInjTot);
  init64(tmp2,0,3600000000ul);
  mul64(tmp1,tmp2);
  init64(tmp2,0,1000ul);
  mul64(tmp1,tmp2);
  init64(tmp2,0,parms[microSecondsPerGallonIdx]);
  div64(tmp1,tmp2);
  init64(tmp2,0,instInjEnd-instInjStart);
  div64(tmp1,tmp2);
  return tmp1[1];      
}
/*
unsigned long instantrpm(){      
  init64(tmp1,0,instInjCount);
  init64(tmp2,0,120000000ul);
  mul64(tmp1,tmp2);
  init64(tmp2,0,1000ul);
  mul64(tmp1,tmp2);
  init64(tmp2,0,parms[var[Trip::injPulses]Per2Revolutions]);
  div64(tmp1,tmp2);
  init64(tmp2,0,instInjEnd-instInjStart);
  div64(tmp1,tmp2);
  return tmp1[1];      
} */

unsigned long Trip::miles(){      
  init64(tmp1,0,var[Trip::vssPulses]);
  init64(tmp2,0,1000);
  mul64(tmp1,tmp2);
  init64(tmp2,0,parms[vssPulsesPerMileIdx]);
  div64(tmp1,tmp2);
  return tmp1[1];      
}      
 
unsigned long Trip::eocMiles(){      
  init64(tmp1,0,var[Trip::vssEOCPulses]);
  init64(tmp2,0,1000);
  mul64(tmp1,tmp2);
  init64(tmp2,0,parms[vssPulsesPerMileIdx]);
  div64(tmp1,tmp2);
  return tmp1[1];      
}       
 
unsigned long Trip::mph(){      
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
  init64(tmp1,0,(Trip::gallons()));  /* 0.001 gal/bit */
  init64(tmp2,0,parms[fuelcostIdx]); /* 0.01 dollars/bit */
  mul64(tmp1,tmp2);
  init64(tmp2,0,100);
  div64(tmp1,tmp2);
  return tmp1[1];
}

 
unsigned long  Trip::mpg(){      
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
 

 
void bigNum (unsigned long t, char * txt1, char * txt2){      
  char dp = ' ';       // decimal point is a space
  char *r = "009.99";  // default to 999
  if (DISPLAY_TYPE != dtBigChars) {
     LCD::writeCGRAM(&chars[0], LcdNewChars);
     DISPLAY_TYPE = dtBigChars;
  }
  if(t<=99500){ 
     r=format(t/10);   // 009.86 
     dp=5;             // special character 5
  }
  else if(t<=999500){ 
     r=format(t/100);  // 009.86 
  }   
 
  strcpy(&LCDBUF1[0], (bignumchars1+(r[2]-'0')*4));
  LCDBUF1[3] = ' ';
  strcpy(&LCDBUF1[4], (bignumchars1+(r[4]-'0')*4));
  LCDBUF1[7] = ' ';
  strcpy(&LCDBUF1[8], (bignumchars1+(r[5]-'0')*4));
  LCDBUF1[11] = ' ';
  strcpy(&LCDBUF1[12], txt1);
 
  strcpy(&LCDBUF2[0], (bignumchars2+(r[2]-'0')*4));
  LCDBUF2[3] = ' ';
  strcpy(&LCDBUF2[4], (bignumchars2+(r[4]-'0')*4));
  LCDBUF2[7] = dp;
  strcpy(&LCDBUF2[8], (bignumchars2+(r[5]-'0')*4));
  LCDBUF2[11] = ' ';
  strcpy(&LCDBUF2[12], txt2);

  #if (CFG_FUELCUT_INDICATOR != 0)
  FCUT_POS = 3;
  #endif
  
}      

int insert(int *array, int val, size_t size, size_t at)
{
  size_t i;

  /* In range? */
  if (at >= size)
    return -1;

  /* Shift elements to make a hole */
  for (i = size - 1; i > at; i--)
    array[i] = array[i - 1];
  /* Insertion! */
  array[at] = val;

  return 0;
}
  
void save(){
  EEPROM.write(0,guinosig);
  EEPROM.write(1,parmsCount);
  writeEepBlock32(0x04, &parms[0], parmsCount);
}

void writeEepBlock32(unsigned int start_addr, unsigned long *val, unsigned int size) {
  unsigned char p = 0;
  unsigned char shift = 0;
  int i = 0;
  for(start_addr; p < size; start_addr+=4) {
    for (i=0; i<4; i++) {
      shift = (8 * (3-i));  /* 24, 16, 8, 0 */
      EEPROM.write(start_addr + i, (val[p]>>shift) & 0xFF);
    }
    p++;
  }
}

void readEepBlock32(unsigned int start_addr, unsigned long *val, unsigned int size) {
   unsigned long v = 0;
   unsigned char p = 0;
   unsigned char temp = 0;
   unsigned char i = 0;
   for(start_addr; p < size; start_addr+=4) {
      v = 0;   /* clear the scratch variable every loop! */
      for (i=0; i<4; i++) {
         temp = (i > 0) ? 1 : 0;  /* 0, 1, 1, 1  */
         v = (v << (temp * 8)) + EEPROM.read(start_addr + i);
      }
      val[p] = v;
      p++;
   }
}

unsigned char load(){ //return 1 if loaded ok
  #ifdef usedefaults
    return 1;
  #endif
  unsigned char b = EEPROM.read(0);
  unsigned char c = EEPROM.read(1);
  if(b == guinosigold)
    c=9; //before fancy parameter counter

  if(b == guinosig || b == guinosigold){
    readEepBlock32(0x04, &parms[0], parmsCount);
    #if (TANK_IN_EEPROM_CFG == 1)
    /* read out the tank variables on boot */
    /* TODO:  eepBlkSize_Tank is appropriate for size? */
    readEepBlock32(eepBlkAddr_Tank, &tank.var[0], eepBlkSize_Tank);  
    #endif
    return 1;
  }
  return 0;
}

char * uformat(unsigned long val){ 
  static char mBuff[17];
  unsigned long d = 1000000000ul;
  unsigned char p;
  for(p = 0; p < 10 ; p++){
    mBuff[p]='0' + (val/d);
    val=val-(val/d*d);
    d/=10;
  }
  mBuff[10]=0;
  return mBuff;
} 

unsigned long rformat(char * val){ 
  unsigned long d = 1000000000ul;
  unsigned long v = 0ul;
  for(unsigned char p = 0; p < 10 ; p++){
    v=v+(d*(val[p]-'0'));
    d/=10;
  }
  return v;
} 


void editParm(unsigned char parmIdx){
   unsigned long v = parms[parmIdx];
   unsigned char p=9;  //right end of 10 digit number
   unsigned char keyLock=1;    
   char *fmtv = uformat(v);

   /* -- line 1 -- */
   strcpy(&LCDBUF1[0], parmLabels[parmIdx]);

   /* -- line 2 -- */
   strcpy(&LCDBUF2[0], fmtv);
   strcpy(&LCDBUF2[10], " OK XX");

   /* -- write to display -- */
   LCDBUF1[16] = 0; 
   LCDBUF2[16] = 0;
   LCD::LcdCommandWrite(LCD_ClearDisplay);
   LCD::print(LCDBUF1);
   LCD::gotoXY(0,1);    
   LCD::print(LCDBUF2);

   /* -- turn the cursor on -- */
   LCD::LcdCommandWrite(LCD_DisplayOnOffCtrl | LCD_DisplayOnOffCtrl_DispOn | LCD_DisplayOnOffCtrl_CursOn);

#if (CFG_NICE_CURSOR)
   //do a nice thing and put the cursor at the first non zero number
   for(int x=9 ; x>=0 ;x--) { 
      if(fmtv[x] != '0') {
         p=x; 
      }
   }
#else
   /* cursor on 'XX' by default except for contrast */
   (parmIdx == contrastIdx) ? p=8 : p=11;  
#endif

  while(true){

    if(p<10)
      LCD::gotoXY(p,1);   
    if(p==10)     
      LCD::gotoXY(11,1);   
    if(p==11)     
      LCD::gotoXY(14,1);   

     if(keyLock == 0) { 
        if (LeftButtonPressed && RightButtonPressed) {
            if (p<10)
               p=10;
            else if (p==10) 
               p=11;
#if (CFG_NICE_CURSOR)
            //do a nice thing and put the cursor at the first non zero number
            else{
              for(int x=9 ; x>=0 ;x--){ 
                if(fmtv[x] != '0')
               p=x; 
              }
            }
#else
            else {
               /* cursor on 'XX' by default except for contrast */
               (parmIdx == contrastIdx) ? p=8 : p=11;  
            }
#endif
        }else if (LeftButtonPressed) {
            p=p-1;
            if(p==255)p=11;
        }else if(RightButtonPressed) {
             p=p+1;
            if(p==12)p=0;
        }else if(MiddleButtonPressed) {
             if(p==11){  //cancel selected
                LCD::LcdCommandWrite(B00001100);
                return;
             }
             if(p==10){  //ok selected
                LCD::LcdCommandWrite(B00001100);
                parms[parmIdx]=rformat(fmtv);
                return;
             }
             
             unsigned char n = fmtv[p]-'0';
             n++;
             if (n > 9) n=0;
             if(p==0 && n > 3) n=0;
             fmtv[p]='0'+ n;
             LCD::gotoXY(0,1);        
             LCD::print(fmtv);
             LCD::gotoXY(p,1);        
             if(parmIdx==contrastIdx)//adjust contrast dynamically
                 analogWrite(ContrastPin,rformat(fmtv));  
        }

      if(buttonState!=buttonsUp)
         keyLock=1;
     }else{
        keyLock=0;
     }
      buttonState=buttonsUp;
      delay2(125);
  }      
  
}

void initGuino(){ //edit all the parameters
  for(int x = 0; x<parmsCount; x++) {
    editParm(x);
  }
  save();
  HOLD_DISPLAY=1;
}  

unsigned long millis2(){
	return timer2_overflow_count * 64UL * 2 / (16000000UL / 128000UL);
}

void delay2(unsigned long ms){
	unsigned long start = millis2();
	while (millis2() - start < ms);
}

/* Delay for the given number of microseconds.  Assumes a 16 MHz clock. 
 * Disables interrupts, which will disrupt the millis2() function if used
 * too frequently. */
void delayMicroseconds2(unsigned int us){
	uint8_t oldSREG;
	if (--us == 0)	return;
	us <<= 2;
	us -= 2;
	oldSREG = SREG;
	cli();
	// busy wait
	__asm__ __volatile__ (
		"1: sbiw %0,1" "\n\t" // 2 cycles
		"brne 1b" : "=w" (us) : "0" (us) // 2 cycles
	);
	// reenable interrupts.
	SREG = oldSREG;
}

void init2(){
	// this needs to be called before setup() or some functions won't
	// work there
	sei();
	
	// timer 0 is used for millis2() and delay2()
	timer2_overflow_count = 0;
	// on the ATmega168, timer 0 is also used for fast hardware pwm
	// (using phase-correct PWM would mean that timer 0 overflowed half as often
	// resulting in different millis2() behavior on the ATmega8 and ATmega168)
        TCCR2A=1<<WGM20|1<<WGM21;
	// set timer 2 prescale factor to 64
        TCCR2B=1<<CS22;


//      TCCR2A=TCCR0A;
//      TCCR2B=TCCR0B;
	// enable timer 2 overflow interrupt
	TIMSK2|=1<<TOIE2;
	// disable timer 0 overflow interrupt
	TIMSK0&=!(1<<TOIE0);
}


#if (CFG_SERIAL_TX == 1)
void simpletx( char * string ){
 if (UCSR0B != (1<<TXEN0)){ //do we need to init the uart?
    UBRR0H = (unsigned char)(myubbr>>8);
    UBRR0L = (unsigned char)myubbr;
    UCSR0B = (1<<TXEN0);//Enable transmitter
    UCSR0C = (3<<UCSZ00);//N81
 }
 while (*string)
 {
   while ( !( UCSR0A & (1<<UDRE0)) );
   UDR0 = *string++; //send the data
 }
}
#endif
