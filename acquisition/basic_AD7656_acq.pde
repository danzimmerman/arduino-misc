#include <stdio.h>
#include <SPI.h>
#include <TimerOne.h>

/*this is a basic tester for the AD7656 6 channel 16 bit analog-to-digital converter.
It reads all six channels and prints them to the serial port in a loop
*/

//SPI defaults: AD7656 SCLK connected to CLK pin 13 (red) and AD7656 DOUT A connected to MISO pin 12 (Orange)
const int CS = 10; //yellow wire, chip select
const int CONVST = 9; //green = CONVST A, grey = CONVST B, and white = CONVST C, conversion initiated on rising edge (idle high seems OK)
const int RESET = 8; //blue wire, reset pin should be pulsed at power up, CONVST should be high during reset pulse, and conversion takes 3us
const int NOTSTBY = 7; // purple wire, should be written high at beginning, leave high for now (can be used to reduce power consumption)

int Vout[6] = {0,0,0,0,0,0}; //array to hold six voltages (bits for now)
long t0 =0;
long t = 0;
void setup()
{
  Serial.begin(115200);
  pinMode(CS,OUTPUT);
  pinMode(CONVST,OUTPUT);
  pinMode(RESET,OUTPUT);
  pinMode(NOTSTBY,OUTPUT);
  
  delayMicroseconds(10); // just to make sure the chip powers up
  digitalWrite(CS,HIGH); //idle high, take low for transfers
  digitalWrite(CONVST,HIGH); //idle high, pulse low and back to high to initiate conversion
  digitalWrite(RESET,LOW); //start low
  digitalWrite(NOTSTBY,HIGH); //leave high always
  delayMicroseconds(1);
  digitalWrite(RESET,HIGH); //reset pulse
  delayMicroseconds(1);
  digitalWrite(RESET,LOW);
  SPI.setClockDivider(SPI_CLOCK_DIV2); //SPI_CLOCK_DIV1 is probably ok (max clock 18MHz) but will slow a little for now
  SPI.begin();
  t0 = millis();
}

void loop()
{
  readADCsample(CS,CONVST,&Vout[0]); //pass a pointer to Vout array
  t = millis();
  Serial.print(t-t0,DEC);
  Serial.print(" ");
  for (int j=0; j<6; j++)
      { 
        Serial.print(Vout[j],DEC);
        Serial.print(" ");
      }
  Serial.print("\r\n"); //newline
   
}

//===========================function definitions========================
void readADCsample(int cs, int convst,int *Vout)  //pass a pointer to Vout // this entire transfer takes about 43 microseconds
                  {
                    byte VHBs[6] = {0,0,0,0,0,0};
                    byte VLBs[6] = {0,0,0,0,0,0};
                    digitalWrite(convst,LOW); //pulse CONVST
                    delayMicroseconds(1); 
                    digitalWrite(convst,HIGH);
                    delayMicroseconds(1); //seems like 8.6us when delay = 4, so try shaving off a few - still works OK
                    digitalWrite(cs,LOW);
                    delayMicroseconds(1);
                    for (int j=0; j<6; j++)  //loop through all six channels getting the high byte, then the low, and moving on to next channel
                        {
                          VHBs[j] = SPI.transfer(0x00);
                          VLBs[j] = SPI.transfer(0x00);
                        }
                    delayMicroseconds(1);
                    digitalWrite(cs,HIGH);
                    //the following should put the two bytes into a word and the (int) casting should handle 2's comp 
                    for (int j=0; j<6; j++)
                        {
                          Vout[j] = (int) word(VHBs[j],VLBs[j]);
                        }
                  }
