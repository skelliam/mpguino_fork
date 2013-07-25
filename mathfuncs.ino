//the standard 64 bit math brings in  5000+ bytes 
//these bring in 1214 bytes, and everything is pass by reference

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
  unsigned long zero64[]={0,0};
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
  unsigned long zero64[]={0,0};

  while(!eq64(y,zero64)) {
    if(y[1] & 1) 
      add64(p,an);
    shl64(an);
    shr64(y);
  }
  init64(an,p[0],p[1]);
} 
