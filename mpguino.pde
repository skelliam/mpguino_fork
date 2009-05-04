/* YOU NEED TO USE ARDUINO VERSION 0011 !!!!!!  */
//it won't fit with the new math libraries that come with 0012, sorry.
//GPL Software    

#include <avr/pgmspace.h>  
#include <EEPROM.h>
#include "mpguino.h"

/* --- Global Variable Declarations -------------------------- */

unsigned long  parms[]={95ul,8208ul,500000000ul,3ul,420000000ul,10300ul,500ul,2400ul,0ul,2ul};//default values
char *parmLabels[]={"Contrast","VSS Pulses/Mile", "MicroSec/Gallon","Pulses/2 revs","Timout(microSec)","Tank Gal * 1000","Injector DelayuS","Weight (lbs)","Scratchpad(odo?)","VSS Delay ms"};
const unsigned char LcdCharHeightPix = 8;
unsigned long maxLoopLength = 0;            // see if we are overutilizing the CPU      

#if (CFG_BIGFONT_TYPE == 1)
   //32 = 0x20 = space
   const unsigned char LcdNewChars = 5;
   char bignumchars1[]={4,1,4,0, 1,4,32,0, 3,3,4,0, 1,3,4,0, 4,2,4,0,   4,3,3,0, 4,3,3,0, 1,1,4,0,   4,3,4,0, 4,3,4,0}; 
   char bignumchars2[]={4,2,4,0, 2,4,2,0,  4,2,2,0, 2,2,4,0, 32,32,4,0, 2,2,4,0, 4,2,4,0, 32,4,32,0, 4,2,4,0, 2,2,4,0};  
#elif (CFG_BIGFONT_TYPE == 2)
   //255 = 0xFF = all black character
   const unsigned char LcdNewChars = 8;
   char bignumchars1[]={7,1,8,0, 1,255,32,0,  3,3,8,0,   1,3,8,0, 255,2,255,0, 255,3,3,0, 7,3,3,0, 1,1,6,0,   7,3,8,0, 7,3,8,0};
   char bignumchars2[]={4,2,6,0, 32,255,32,0, 255,2,2,0, 2,2,6,0, 32,32,255,0, 2,2,6,0,   4,2,6,0, 32,7,32,0, 4,2,6,0, 2,2,6,0};
#endif

byte brightness[]={255,214,171,128}; //middle button cycles through these brightness settings      
byte brightnessIdx=1;

#define brightnessLength (sizeof(brightness)/sizeof(byte)) //array size

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
void addEvent(byte eventID, unsigned int ms){
  if( ms == 0)
    eventFuncs[eventID]();
  else
    eventFuncCounts[eventID]=ms;
}

/* this ISR gets called every 1.024 milliseconds, we will call that a millisecond for our purposes
go through all the event counts, 
  if any are non zero subtract 1 and call the associated function if it just turned zero.  */
ISR(TIMER2_OVF_vect){
  timer2_overflow_count++;
  for(byte eventID = 0; eventID < eventFuncSize; eventID++){
    if(eventFuncCounts[eventID]!= 0){
      eventFuncCounts[eventID]--;
      if(eventFuncCounts[eventID] == 0)
          eventFuncs[eventID](); 
    }  
  }
}


byte buttonState = buttonsUp;      
 
 
//overflow counter used by millis2()      
unsigned long lastMicroSeconds=millis2() * 1000;   
unsigned long microSeconds (void){     
  unsigned long tmp_timer2_overflow_count;    
  unsigned long tmp;    
  byte tmp_tcnt2;    
  cli(); //disable interrupts    
  tmp_timer2_overflow_count = timer2_overflow_count;    
  tmp_tcnt2 = TCNT2;    
  sei(); // enable interrupts    
  tmp = ((tmp_timer2_overflow_count << 8) + tmp_tcnt2) * 4;     
  if((tmp<=lastMicroSeconds) && (lastMicroSeconds<4290560000ul))    
    return microSeconds();     
  lastMicroSeconds=tmp;   
  return tmp;     
}    
 
unsigned long elapsedMicroseconds(unsigned long startMicroSeconds, unsigned long currentMicroseconds ){      
  if(currentMicroseconds >= startMicroSeconds)      
    return currentMicroseconds-startMicroSeconds;      
  return 4294967295 - (startMicroSeconds-currentMicroseconds);      
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
  long x = elapsedMicroseconds(injHiStart, t)- parms[injectorSettleTimeIdx];       
  if(x >0) tmpTrip.var[Trip::injHius] += x;
  tmpTrip.var[Trip::injPulses]++;      
  if (tmpInstInjStart != nil) {
    if(x >0) tmpInstInjTot += x;     
    tmpInstInjCount++;
  } else {
    tmpInstInjStart = t;
  }
  
  tmpInstInjEnd = t;
}


volatile boolean vssFlop = 0;

void enableVSS(){
//    tmpTrip.var[Trip::vssPulses]++; 
    vssFlop = !vssFlop;
}

unsigned volatile long lastVSS1;
unsigned volatile long lastVSSTime;
unsigned volatile long lastVSS2;

volatile boolean lastVssFlop = vssFlop;

//attach the vss/buttons interrupt      
ISR( PCINT1_vect ){   
  static byte vsspinstate=0;      
  byte p = PINC;//bypassing digitalRead for interrupt performance      
  if ((p & vssBit) != (vsspinstate & vssBit)){      
    addEvent(enableVSSID,parms[vsspause] ); //check back in a couple milli
  }
  if(lastVssFlop != vssFlop){
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
}       
 
 
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
};      
#define displayFuncSize (sizeof(displayFuncs)/sizeof(pFunc)) //array size      
prog_char  * displayFuncNames[displayFuncSize]; 
byte newRun = 0;
void setup (void){
  init2();
  newRun = load();//load the default parameters
  byte x = 0;
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
  LCD::gotoXY(0,0); 
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


}       
 
byte screen=0;      
byte holdDisplay = 0; 



#define looptime 1000000ul/loopsPerSecond //1/2 second      
void loop (void){
  if(newRun !=1) {
    initGuino();//go through the initialization screen
  }
  unsigned long lastActivity =microSeconds();
  unsigned long tankHold;      //state at point of last activity

  while(true){      
    unsigned long loopStart=microSeconds();      
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
    //send out instantmpg * 1000, instantmph * 1000, the injector/vss raw data
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
    
    current.update(instant);   //use instant to update current      
    tank.update(instant);      //use instant to update tank      

//currentTripResetTimeoutUS
    if(instant.var[Trip::vssPulses] == 0 && instant.var[Trip::injPulses] == 0 && holdDisplay==0){
      if(elapsedMicroseconds(lastActivity) > parms[currentTripResetTimeoutUSIdx] && lastActivity != nil){
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
    }else{
      if(lastActivity == nil){//wake up!!!
        #if (SLEEP_CFG & Sleep_bkl)
        analogWrite(BrightnessPin,brightness[brightnessIdx]);    
        #endif
        #if (SLEEP_CFG & Sleep_lcd)
        // Turn on the LCD again.  Display should be restored.
        LCD::LcdCommandWrite(LCD_DisplayOnOffCtrl | LCD_DisplayOnOffCtrl_DispOn);
        // TODO:  Does the above cause a problem if sleep happens during a settings mode? 
        //        Said another way, we don't get the cursor back unless we ask for it.
        #endif
        lastActivity=loopStart;
        current.reset();
        tank.var[Trip::loopCount] = tankHold;
        current.update(instant); 
        tank.update(instant); 
      }else{
        lastActivity=loopStart;
        tankHold = tank.var[Trip::loopCount];
      }
    }
    

 if(holdDisplay==0){
    displayFuncs[screen]();    //call the appropriate display routine      
    LCD::gotoXY(0,0);        
    
//see if any buttons were pressed, display a brief message if so      
      if(!(buttonState&lbuttonBit) && !(buttonState&rbuttonBit)){// left and right = initialize      
          LCD::print(getStr(PSTR("Setup ")));    
          initGuino();  
      }else if (!(buttonState&lbuttonBit) && !(buttonState&mbuttonBit)){// left and middle = tank reset      
          tank.reset();      
          LCD::print(getStr(PSTR("Tank Reset ")));      
      }else if(!(buttonState&mbuttonBit) && !(buttonState&rbuttonBit)){// right and middle = current reset      
          current.reset();      
          LCD::print(getStr(PSTR("Current Reset ")));      
      }else if(!(buttonState&lbuttonBit)){ //left is rotate through screeens to the left      
        if(screen!=0)      
          screen=(screen-1);       
        else      
          screen=displayFuncSize-1;      
        LCD::print(getStr(displayFuncNames[screen]));      
      }else if(!(buttonState&mbuttonBit)){ //middle is cycle through brightness settings      
        brightnessIdx = (brightnessIdx + 1) % brightnessLength;      
        analogWrite(BrightnessPin,brightness[brightnessIdx]);      
        LCD::print(getStr(PSTR("Brightness ")));      
        LCD::LcdDataWrite('0' + brightnessIdx);      
        LCD::print(" ");      
      }else if(!(buttonState&rbuttonBit)){//right is rotate through screeens to the left      
        screen=(screen+1)%displayFuncSize;      
        LCD::print(getStr(displayFuncNames[screen]));      
      }      
      if(buttonState!=buttonsUp)
         holdDisplay=1;
     }else{
        holdDisplay=0;
    } 
    buttonState=buttonsUp;//reset the buttons      
 
      //keep track of how long the loops take before we go int waiting.      
      unsigned long loopX=elapsedMicroseconds(loopStart);      
      if(loopX>maxLoopLength) maxLoopLength = loopX;      
 
      while (elapsedMicroseconds(loopStart) < (looptime));//wait for the end of a second to arrive      
  }      
 
}       
 
 
char fBuff[7];//used by format    

char* format(unsigned long num){
  byte dp = 3;

  while(num > 999999){
    num /= 10;
    dp++;
    if( dp == 5 ) break; // We'll lose the top numbers like an odometer
  }
  if(dp == 5) dp = 99; // We don't need a decimal point here.

// Round off the non-printed value.
  if((num % 10) > 4)
    num += 10;
  num /= 10;
  byte x = 6;
  while(x > 0){
    x--;
    if(x==dp){ //time to poke in the decimal point?{
      fBuff[x]='.';
    }else{
      fBuff[x]= '0' + (num % 10);//poke the ascii character for the digit.
      num /= 10;
    } 
  }
  fBuff[6] = 0;
  return fBuff;
}
 
//get a string from flash 
char mBuff[17];//used by getStr 
char * getStr(prog_char * str){ 
  strcpy_P(mBuff, str); 
  return mBuff; 
} 

 
void doDisplayCustom(){displayTripCombo('M','G',instantmpg(),'S',instantmph(),'G','H',instantgph(),'C',current.mpg());}      
//void doDisplayCustom(){displayTripCombo('I','M',instantmpg(),'S',instantgph(),'R','P',instantrpm(),'C',current.var[Trip::injIdleHiSec]*1000);}      
//void doDisplayCustom(){displayTripCombo('I','M',995,'S',994,'R','P',999994,'C',999995);}      
void doDisplayEOCIdleData(){displayTripCombo('C','E',current.eocMiles(),'G',current.idleGallons(),'T','E',tank.eocMiles(),'G',tank.idleGallons());}      
void doDisplayInstantCurrent(){displayTripCombo('I','M',instantmpg(),'S',instantmph(),'C','M',current.mpg(),'D',current.miles());}      
 
void doDisplayInstantTank(){displayTripCombo('I','M',instantmpg(),'S',instantmph(),'T','M',tank.mpg(),'D',tank.miles());}      

void doDisplayBigInstant() {bigNum(instantmpg(),"INST","MPG ");}      
void doDisplayBigCurrent() {bigNum(current.mpg(),"CURR","MPG ");}      
void doDisplayBigTank()    {bigNum(tank.mpg(),"TANK","MPG ");}      
 
void doDisplayCurrentTripData(void){tDisplay(&current);}   //display current trip formatted data.        
void doDisplayTankTripData(void){tDisplay(&tank);}      //display tank trip formatted data.        
void doDisplaySystemInfo(void){      
  LCD::gotoXY(0,0);LCD::print("C%");LCD::print(format(maxLoopLength*1000/(looptime/100)));LCD::print(" T"); LCD::print(format(tank.time()));     
  unsigned long mem = memoryTest();      
  mem*=1000;      
  LCD::gotoXY(0,1);
  LCD::print("FREE MEM: ");
  LCD::print(format(mem));      
}    //display max cpu utilization and ram.        
 
void displayTripCombo(char t1, char t1L1, unsigned long t1V1, char t1L2, unsigned long t1V2,  char t2, char t2L1, unsigned long t2V1, char t2L2, unsigned long t2V2){ 
  LCD::gotoXY(0,0);LCD::LcdDataWrite(t1);LCD::LcdDataWrite(t1L1);LCD::print(format(t1V1));LCD::LcdDataWrite(' '); 
      LCD::LcdDataWrite(t1L2);LCD::print(format(t1V2)); 
  LCD::gotoXY(0,1);LCD::LcdDataWrite(t2);LCD::LcdDataWrite(t2L1);LCD::print(format(t2V1));LCD::LcdDataWrite(' '); 
      LCD::LcdDataWrite(t2L2);LCD::print(format(t2V2)); 
}      
 
//arduino doesn't do well with types defined in a script as parameters, so have to pass as void * and use -> notation.      
void tDisplay( void * r){ //display trip functions.        
  Trip *t = (Trip *)r;      
  LCD::gotoXY(0,0);LCD::print("MH");LCD::print(format(t->mph()));LCD::print("MG");LCD::print(format(t->mpg()));      
  LCD::gotoXY(0,1);LCD::print("MI");LCD::print(format(t->miles()));LCD::print("GA");LCD::print(format(t->gallons()));      
}      
 
 
 
    
//x=0..16, y= 0..1      
void LCD::gotoXY(byte x, byte y){      
  byte dr=x+0x80;      
  if (y==1)       
    dr += 0x40;      
  if (y==2)       
    dr += 0x14;      
  if (y==3)       
    dr += 0x54;      
  LCD::LcdCommandWrite(dr);        
}      
 
void LCD::print(char * string){      
  byte x = 0;      
  char c = string[x];      
  while(c != 0){      
    LCD::LcdDataWrite(c);       
    x++;      
    c = string[x];      
  }      
}      
 
 
void LCD::init(){
  delay2(16);                    // wait for more than 15 msec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  tickleEnable();
  delay2(5);                     // wait for more than 4.1 msec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  tickleEnable();
  delay2(1);                     // wait for more than 100 usec
  pushNibble(B00110000);  // send (B0011) to DB7-4
  cmdWriteSet();
  tickleEnable();
  delay2(1);                     // wait for more than 100 usec
  pushNibble(B00100000);  // send (B0010) to DB7-4 for 4bit
  cmdWriteSet();
  tickleEnable();
  delay2(1);                     // wait for more than 100 usec

  // ready to use normal LcdCommandWrite() function now!
  LcdCommandWrite(B00101000);   // 4-bit interface, 2 display lines, 5x8 font
  LcdCommandWrite(LCD_DisplayOnOffCtrl | LCD_DisplayOnOffCtrl_DispOn);
  LcdCommandWrite(LCD_EntryMode | LCD_EntryMode_Increment);

//creating the custom fonts:
  LcdCommandWrite(LCD_SetCGRAM | 0x08);  // write to CGen RAM

#if (CFG_BIGFONT_TYPE == 1)
  static byte chars[] PROGMEM = {
    B11111,B00000,B11111,B11111,B00000,
    B11111,B00000,B11111,B11111,B00000,
    B11111,B00000,B11111,B11111,B00000,
    B00000,B00000,B00000,B11111,B00000,
    B00000,B00000,B00000,B11111,B00000,
    B00000,B11111,B11111,B11111,B01110,
    B00000,B11111,B11111,B11111,B01110,
    B00000,B11111,B11111,B11111,B01110};
#elif (CFG_BIGFONT_TYPE == 2)
  /* XXX: For whatever reason I can not figure out how 
   * to store more than 8 chars in the LCD CGRAM */
  static byte chars[] PROGMEM = {
    B11111, B00000, B11111, B11111, B00000, B11111, B00111, B11100, 
    B11111, B00000, B11111, B11111, B00000, B11111, B01111, B11110, 
    B00000, B00000, B00000, B11111, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B00000, B11111, B11111, B11111, 
    B00000, B00000, B00000, B11111, B01110, B11111, B11111, B11111,
    B00000, B11111, B11111, B01111, B01110, B11110, B11111, B11111,
    B00000, B11111, B11111, B00111, B01110, B11100, B11111, B11111};
#endif

    /* write the character data to the character generator ram */
    for(byte x=0;x<LcdNewChars;x++) {
      for(byte y=0;y<LcdCharHeightPix;y++) {
          LcdDataWrite(pgm_read_byte(&chars[y*LcdNewChars+x])); 
      }
    }

  LcdCommandWrite(LCD_ClearDisplay);       // clear display, set cursor position to zero
  LcdCommandWrite(LCD_SetDDRAM);           // set dram to zero
}

void  LCD::tickleEnable(){       
  // send a pulse to enable       
  digitalWrite(EnablePin,HIGH);       
  delayMicroseconds2(1);  // pause 1 ms according to datasheet       
  digitalWrite(EnablePin,LOW);       
  delayMicroseconds2(1);  // pause 1 ms according to datasheet       
}        
 
void LCD::cmdWriteSet(){       
  digitalWrite(EnablePin,LOW);       
  delayMicroseconds2(1);  // pause 1 ms according to datasheet       
  digitalWrite(DIPin,0);       
}       
 
byte LCD::pushNibble(byte value){       
  digitalWrite(DB7Pin, value & 128);       
  value <<= 1;       
  digitalWrite(DB6Pin, value & 128);       
  value <<= 1;       
  digitalWrite(DB5Pin, value & 128);       
  value <<= 1;       
  digitalWrite(DB4Pin, value & 128);       
  value <<= 1;       
  return value;      
}      
 
void LCD::LcdCommandWrite(byte value){       
  value=pushNibble(value);      
  cmdWriteSet();       
  tickleEnable();       
  value=pushNibble(value);      
  cmdWriteSet();       
  tickleEnable();       
  delay2(5);       
}       
 
void LCD::LcdDataWrite(byte value){       
  digitalWrite(DIPin, HIGH);       
  value=pushNibble(value);      
  tickleEnable();       
  value=pushNibble(value);      
  tickleEnable();       
  delay2(5);
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
 
//for display computing
unsigned long tmp1[2];
unsigned long tmp2[2];
unsigned long tmp3[2];

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

//eocMiles
//idleGallons
 
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
  byte d = 60;      
  unsigned long seconds = var[Trip::loopCount]/loopsPerSecond;     
//  if(seconds/60 > 999) d = 3600; //scale up to hours.minutes if we get past 999 minutes      
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
 
void Trip::update(Trip t){     
  var[Trip::loopCount]++;  //we call update once per loop     
  var[Trip::vssPulses]+=t.var[Trip::vssPulses];      
  var[Trip::vssPulseLength]+=t.var[Trip::vssPulseLength];
  if(t.var[Trip::injPulses] ==0 )  //track distance traveled with engine off
    var[Trip::vssEOCPulses]+=t.var[Trip::vssPulses];
  
  if(t.var[Trip::injPulses] > 2 && t.var[Trip::injHius]<500000){//chasing ghosts      
    var[Trip::injPulses]+=t.var[Trip::injPulses];      
    var[Trip::injHius]+=t.var[Trip::injHius];      
    if (var[Trip::injHius]>=1000000){  //rollover into the var[Trip::injHiSec] counter      
      var[Trip::injHiSec]++;      
      var[Trip::injHius]-=1000000;      
    }
    if(t.var[Trip::vssPulses] == 0){    //track gallons spent sitting still
      
      var[Trip::injIdleHius]+=t.var[Trip::injHius];      
      if (var[Trip::injIdleHius]>=1000000){  //r
        var[Trip::injIdleHiSec]++;
        var[Trip::injIdleHius]-=1000000;      
      }      
    }
  }      
}   
 

 
void bigNum (unsigned long t, char * txt1, char * txt2){      
  char  dp = 32;       // 32 = 0x20 = space
  char *r = "009.99";  // default to 999
  if(t<=99500){ 
     r=format(t/10);   // 009.86 
     dp=5; 
  }
  else if(t<=999500){ 
     r=format(t/100);  // 009.86 
  }   
 
  LCD::gotoXY(0,0); 
  LCD::print(bignumchars1+(r[2]-'0')*4); 
  LCD::print(" "); 
  LCD::print(bignumchars1+(r[4]-'0')*4); 
  LCD::print(" "); 
  LCD::print(bignumchars1+(r[5]-'0')*4); 
  LCD::print(" "); 
  LCD::print(txt1); 
 
  LCD::gotoXY(0,1); 
  LCD::print(bignumchars2+(r[2]-'0')*4); 
  LCD::print(" "); 
  LCD::print(bignumchars2+(r[4]-'0')*4); 
  LCD::LcdDataWrite(dp);  /* decimal point */
  LCD::print(bignumchars2+(r[5]-'0')*4); 
  LCD::print(" "); 
  LCD::print(txt2); 
}      



//the standard 64 bit math brings in  5000+ bytes
//these bring in 1214 bytes, and everything is pass by reference
unsigned long zero64[]={0,0};
 
void init64(unsigned long  an[], unsigned long bigPart, unsigned long littlePart ){
  an[0]=bigPart;
  an[1]=littlePart;
}
 
//left shift 64 bit "number"
void shl64(unsigned long  an[]){
 an[0] <<= 1; 
 if(an[1] & 0x80000000)
   an[0]++; 
 an[1] <<= 1; 
}
 
//right shift 64 bit "number"
void shr64(unsigned long  an[]){
 an[1] >>= 1; 
 if(an[0] & 0x1)
   an[1]+=0x80000000; 
 an[0] >>= 1; 
}
 
//add ann to an
void add64(unsigned long  an[], unsigned long  ann[]){
  an[0]+=ann[0];
  if(an[1] + ann[1] < ann[1])
    an[0]++;
  an[1]+=ann[1];
}
 
//subtract ann from an
void sub64(unsigned long  an[], unsigned long  ann[]){
  an[0]-=ann[0];
  if(an[1] < ann[1]){
    an[0]--;
  }
  an[1]-= ann[1];
}
 
//true if an == ann
boolean eq64(unsigned long  an[], unsigned long  ann[]){
  return (an[0]==ann[0]) && (an[1]==ann[1]);
}
 
//true if an < ann
boolean lt64(unsigned long  an[], unsigned long  ann[]){
  if(an[0]>ann[0]) return false;
  return (an[0]<ann[0]) || (an[1]<ann[1]);
}
 
//divide num by den
void div64(unsigned long num[], unsigned long den[]){
  unsigned long quot[2];
  unsigned long qbit[2];
  unsigned long tmp[2];
  init64(quot,0,0);
  init64(qbit,0,1);
 
  if (eq64(num, zero64)) {  //numerator 0, call it 0
    init64(num,0,0);
    return;        
  }
 
  if (eq64(den, zero64)) { //numerator not zero, denominator 0, infinity in my book.
    init64(num,0xffffffff,0xffffffff);
    return;        
  }
 
  init64(tmp,0x80000000,0);
  while(lt64(den,tmp)){
    shl64(den);
    shl64(qbit);
  } 
 
  while(!eq64(qbit,zero64)){
    if(lt64(den,num) || eq64(den,num)){
      sub64(num,den);
      add64(quot,qbit);
    }
    shr64(den);
    shr64(qbit);
  }
 
  //remainder now in num, but using it to return quotient for now  
  init64(num,quot[0],quot[1]); 
}
 
 
//multiply num by den
void mul64(unsigned long an[], unsigned long ann[]){
  unsigned long p[2] = {0,0};
  unsigned long y[2] = {ann[0], ann[1]};
  while(!eq64(y,zero64)) {
    if(y[1] & 1) 
      add64(p,an);
    shl64(an);
    shr64(y);
  }
  init64(an,p[0],p[1]);
} 
  
void save(){
  EEPROM.write(0,guinosig);
  EEPROM.write(1,parmsLength);
  writeEepBlock32(0x04, &parms[0], parmsLength);
}

void writeEepBlock32(unsigned int start_addr, unsigned long *val, unsigned int size) {
  unsigned char p = 0;
  int i = 0;
  for(start_addr; p < size; start_addr+=4) {
    for (i=0; i<4; i++) {
      byte shift = 8 * (3-i);  // 24, 26, 8, 0
      EEPROM.write(start_addr + i, (val[p]>>shift) & 0xFF);
    }
    p++;
  }
}

void readEepBlock32(unsigned int start_addr, unsigned long *val, unsigned int size) {
   unsigned long v;
   unsigned char p = 0;
   unsigned char temp = 0;
   unsigned char i = 0;
   for(start_addr; p < size; start_addr+=4) {
      for (i=0; i<4; i++) {
         temp = (i > 0) ? 1 : 0;  // 0, 1, 1, 1
         v = (v << (temp * 8)) + EEPROM.read(start_addr+i);
      }
      val[p]=v;
      p++;
   }
}

byte load(){ //return 1 if loaded ok
  #ifdef usedefaults
    return 1;
  #endif
  byte b = EEPROM.read(0);
  byte c = EEPROM.read(1);
  if(b == guinosigold)
    c=9; //before fancy parameter counter

  if(b == guinosig || b == guinosigold){
    readEepBlock32(0x04, &parms[0], parmsLength);
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
  unsigned long d = 1000000000ul;
  for(byte p = 0; p < 10 ; p++){
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
  for(byte p = 0; p < 10 ; p++){
    v=v+(d*(val[p]-'0'));
    d/=10;
  }
  return v;
} 


void editParm(byte parmIdx){
  unsigned long v = parms[parmIdx];
  byte p=9;  //right end of 10 digit number
  //display label on top line
  //set cursor visible
  //set pos = 0
  //display v

    LCD::gotoXY(8,0);        
    LCD::print("        ");
    LCD::gotoXY(0,0);        
    LCD::print(parmLabels[parmIdx]);
    LCD::gotoXY(0,1);    
    char * fmtv=    uformat(v);
    LCD::print(fmtv);
    LCD::print(" OK XX");
    LCD::LcdCommandWrite(LCD_DisplayOnOffCtrl | LCD_DisplayOnOffCtrl_DispOn | LCD_DisplayOnOffCtrl_CursOn);
#if (CFG_NICE_CURSOR)
    //do a nice thing and put the cursor at the first non zero number
    for(int x=9 ; x>=0 ;x--){ 
      if(fmtv[x] != '0')
         p=x; 
    }
#else
    /* cursor on 'XX' by default except for contrast */
    (parmIdx == contrastIdx) ? p=8 : p=11;  
#endif
  byte keyLock=1;    
  while(true){

    if(p<10)
      LCD::gotoXY(p,1);   
    if(p==10)     
      LCD::gotoXY(11,1);   
    if(p==11)     
      LCD::gotoXY(14,1);   

     if(keyLock == 0){ 
        if(!(buttonState&lbuttonBit) && !(buttonState&rbuttonBit)){// left & right
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
        }else  if(!(buttonState&lbuttonBit)){// left
            p=p-1;
            if(p==255)p=11;
        }else if(!(buttonState&rbuttonBit)){// right
             p=p+1;
            if(p==12)p=0;
        }else if(!(buttonState&mbuttonBit)){// middle
             if(p==11){  //cancel selected
                LCD::LcdCommandWrite(B00001100);
                return;
             }
             if(p==10){  //ok selected
                LCD::LcdCommandWrite(B00001100);
                parms[parmIdx]=rformat(fmtv);
                return;
             }
             
             byte n = fmtv[p]-'0';
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
  for(int x = 0;x<parmsLength;x++)
    editParm(x);
  save();
  holdDisplay=1;
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
