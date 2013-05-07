/*Arduino Parallel Emulator for Station Control v. 1.1 by N3OX (http://www.n3ox.net) 

This code replaces the all-too-rare parallel port 
using an Arduino microcontroller (http://www.arduino.cc).  This is intended for ham radio station
control purposes.  

The code determines operating frequency using a serial connection to rig control software.
It works with Ham Radio Deluxe (http://http://www.ham-radio-deluxe.com) using the "3rd party serial port." 

Frequency is read, converted to "band" and a single 74HC595 8-bit output shift register is set to control station gear. 
The shift register is used to conserve Arduino pins and can be expanded to MANY more outputs by cascading shift registers.

See:
http://www.arduino.cc/en/Tutorial/ShiftOut
for hardware information.

 */

 
 //declare variables

int ledpin=13;     //status led
int latch =5;      //shift register latch pin
int ds = 6;        //shift register data pin
int clk = 7;       //shift register clock pin
int currband=255;  //variable to hold the current band
int lastband=255; //we'll only change things when bands change
float kHz = 0;     //frequency in kHz 
int kHint =0; 
char buffer[15]={0}; //serial receive buffer, one more space for null char (IMPORTANT!!!)
char freqstr[12]={0}; // 11 digit + null
long freqint = 0;     //long integer frequency in Hertz derived from char string freqstr
int parval = 0; //array to write to parallel port, 0-255




void setup() {                
  Serial.begin(57600);    //57600 for HRD.  Not LP-Steplink compatible 
  UCSR0C = UCSR0C | B00001000; //sets 2 stop bits  (? maybe matters, maybe doesn't)

  //initialize I/O pins
 pinMode(ledpin,OUTPUT); 
 pinMode(latch, OUTPUT);
 pinMode(ds, OUTPUT);
 pinMode(clk, OUTPUT);


 //preload the shift register with zeroes (turn all outputs off):
 digitalWrite(latch,LOW);
 delay(5);
 shiftOut(ds,clk,MSBFIRST,0x00);  
 delay(5);
 digitalWrite(latch,HIGH);
}

//********BEGIN void loop()*************
void loop() {

//********BEGIN "no serial recieved" WHILE LOOP *************
  while (Serial.available()==0) { //ask HRD for the frequency
      delay(50);
      Serial.print("FA;");    // FA; is the command to get VFO A... this seems to be the "active" one

      delay(50);
    
  

delay(5);

//Serial.println(currband); un-comment to print band over serial  for debugging 
delay(5);
  

//check to see if new calculated band is the same as the last band, and then decide what to do

//********BEGIN band change SWITCH/CASE*************
switch(currband-lastband){  
  case 0:   //if we haven't changed bands, we don't want to update the shift register, but we'll turn on the LED

  digitalWrite(ledpin,HIGH);
  break;
  
  default:  //if we have changed bands, we update the shift register

  digitalWrite(ledpin,LOW);
  
  
       
//********BEGIN currband SWITCH/CASE*************

/* In the following switch/case section, we do stuff based on the band.  This code emulates 
       the original Ham Radio Deluxe parallel port settings at N3OX.  The values we write using the function
       "writereg" are hex versions of the binary pattern we want on the parallel port.  For example:
       =================
       0x12  is 00010010, which gives the following output on the parallel port:
       ----------------------
       D7 D6 D5 D4 D3 D2 D1 D0
       0  0  0  1  0  0  1  0
       ----------------------       
       
       The required values below will be different for every station.  These values don't have to be in
       hex, they could be a single number from 0-255 or literal binary written with a leading "B": 
      like:  B00010110   
       

       */  
     switch (currband) {  
       
       
       
       case 160 :
       writereg(ds,clk,0x12);  
       lastband=160;

       break;
       
       case 80:
       writereg(ds,clk,0x16);  
       lastband=80;

       break;
       
              
       case 75:
       writereg(ds,clk,0x11);  
       lastband=75;

       break;
       
       case 60:
       writereg(ds,clk,0x00);
       lastband=60;

       break; 
       
       case 40:
       writereg(ds,clk,0x15);
       lastband=40;

       break;
       
       case 30:
       writereg(ds,clk,0x13);
       lastband=30;

       break;
       
       case 20:
       writereg(ds,clk,0x0F);
       lastband=20;

       break;
       
       case 17:
       writereg(ds,clk,0x4F);
       lastband=17;

       break;
       
       case 15:
       writereg(ds,clk,0x20);
       lastband=15;

       break;
       
       case 12:
       writereg(ds,clk,0x20);
       lastband=12;

       break;
       
       case 10:
       writereg(ds,clk,0x20);
       lastband=10;

       break;
       
       case 6:
       writereg(ds,clk,0x00);
       lastband=6;

       break;
       
       case 2:
       writereg(ds,clk,0x00);
       lastband=2;

       break;
       
       case 70:
       writereg(ds,clk,0x00);
       lastband=70;

       break;
       
       default:
       writereg(ds,clk,0x00);
       lastband=255; 

       break;
       }
//********END of currband SWITCH/CASE here *************
    }
//********END of band change SWITCH/CASE here *************
    
     delay(50);
    
   }
 //********END "no serial recieved" WHILE LOOP here *************

//****** BEGIN "do nothing while HRD is transmitting back data" ***********
 while (Serial.available()>0 && Serial.available()<14){
 
}
//****** END "do nothing while HRD is transmitting back data" **************

//****** BEGIN serial string parser **************
  //once 14 characters have come in ( FA###########; )  read them in to a single array.
  if (Serial.available()>=14) {  for (int x=0; x<14; x++) {
  buffer[x] = Serial.read();
  }
    delay(5);
  //parse the 11 frequency characters and store those in "freqstr"
  for (int i=2; i<13; i++){
    freqstr[i-2]=buffer[i];}
    Serial.flush();
     freqint=atol(freqstr);  //change freqstr from a char array to a long integer
    
    kHz = freqint/1000;  //the test conditions in bandval() are easier to read if frequency is in kHz
   
    currband = bandval(kHz);  //figure out the band from the frequency
     
     
  }
//****** END serial string parser **************
     
 
    
    
     
    
     delay(50);

 }
//********END loop()****************

//**************BEGIN FUNCTION DEFINITIONS BELOW***************


  /*define ham bands... "70" = 70cm, otherwise band is in meters.
  Each band has 5kHz of padding on the edges to avoid spurious switching
  when operating close to the band edge.  These can be modified to add bands, etc.
  */
  
int bandval(float input_freq){ 
  int band=255; //return 255 if no bands match
  if (input_freq>=1795 && input_freq<=2005){band=160;}
  if (input_freq>=3495 && input_freq<=3650){band=80;}
  if (input_freq>3650 && input_freq<=4005){band=75;}
  if (input_freq>5100 && input_freq<5500){band=60;}
  if (input_freq>=6995 && input_freq<=7305){band=40;}
  if (input_freq>=10095 && input_freq<=10155){band=30;}
  if (input_freq>=13995 && input_freq<=14355){band=20;}
  if (input_freq>=18063 && input_freq<=18171){band=17;}
  if (input_freq>=20995 && input_freq<=21455){band=15;}
  if (input_freq>=24885 && input_freq<=24995){band=12;}
  if (input_freq>=27995 && input_freq<=29705){band=10;}
  if (input_freq>=49995 && input_freq<=54005){band=6;}
  if (input_freq>=143995 && input_freq<=148005){band=2;}
  if (input_freq>=419995 && input_freq<=450005){band=70;}
  return band;

}

//writereg() loads data onto the shift register when the band changes.
void writereg(int dpin, int clpin, int regval) {
digitalWrite(latch,LOW);
delay(5);
shiftOut(dpin,clpin,MSBFIRST,regval);
delay(5);
digitalWrite(latch,HIGH);
}
