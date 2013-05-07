/*
Serial interface for serial-mode Analog Devices AD9850 DDS + arduino by N3OX 9/18/2012

Tested with inexpensive module from eBay seller ci_tynight209 item 170679340328

http://www.ebay.com/itm/AD9850-Module-DDS-Signal-Generator-0-40MHz-2-Sine-Wave-/170679340328
*/

#include <stdio.h>
#include <Messenger.h> //The Messenger library does some of the command handling.
 
/* Note: it's not explicit in the data sheet, and I don't know that the AD9850 behaves well with other
SPI devices, but the transfer timing requirements for loading tuning and phase words are the same as
SPI mode 0.  So, for convenience, we use the SPI library and SPI.transfer() to load tuning bytes.
*/
#include <SPI.h> 
Messenger message = Messenger();

//pins and pinouts
//blue wire is +5V, purply-grey is ground
int RESET = 9;  //reset on AD9850 connected with green wire 
int FQ_UD = 10; //AD9850 frequency update pin connected with yellow wire, equivalent to chip select
//Pre-defined MOSI pin (11) is connected to AD9850 D7 (serial input) pin with red wire
//Pre-defined CLK pin (13) connected to AD9850 W_CLK clock pin 6 with orange wire
int welcome = 1; // initialize to "true" to go through welcome screen once
float frequency = 7000000.0;  //initialize to 7MHz 
uint64_t CLOCKFREQ = 124.999170e6; //tweaked in comparison to my HF rig, nominally 125MHz.
uint64_t TWO_E32 = pow(2,32);
unsigned long delta = (unsigned long) frequency*TWO_E32/CLOCKFREQ;
char stringbuffer[32];

void setup()
          {
            pinMode(RESET, OUTPUT);      // set status LED as output
            pinMode(FQ_UD,OUTPUT);         // set chip select pin as output
            digitalWrite(FQ_UD,LOW);      // start cspin low to save power
            digitalWrite(RESET,LOW);
            SPI.setDataMode(SPI_MODE0);    // mode 0 seems to be the right one
            SPI.setClockDivider(SPI_CLOCK_DIV4); //try to go pretty fast
            SPI.setBitOrder(LSBFIRST);
            SPI.begin();
            Serial.begin(115200);
          }

void loop()
{
  while(welcome > 0)
       {
          writefreq(frequency,FQ_UD);
          Serial.write(12); //"form feed" clears the screen
          Serial.println("Welcome to AD9850 Controller v. 0.2 by N3OX");
          Serial.println("");
          Serial.println("Enter integer in Hz and enter");
          Serial.println("");
          welcome = 0;
       }
       
  while(Serial.available()==0)
       {  
          Serial.write(13);
          Serial.print("Waiting for command    /");
          delay(50);
          Serial.write(13);
          Serial.print("Waiting for command    |");
          delay(50);
          Serial.write(13);
          Serial.print("Waiting for command    \\");
          delay(50);
          Serial.write(13);
          Serial.print("Waiting for command    -");
          delay(50);
       }
 
  while(Serial.available()) 
       { 
          if (message.process(Serial.read())) 
             {  
                while(message.available()) 
                     { 
                        frequency = message.readLong();
                        writefreq(frequency,FQ_UD);
                     }
     
                delay(100); // short delay to make the interface feel "causal"
        
                if (frequency<0 or frequency>60e6) //out of range
                   { 
                      Serial.write(12);
                      Serial.println("\n");
                      Serial.print(dtostrf(frequency/1.0e6,0,6,stringbuffer));
                      Serial.println("MHz out of range.  Enter 0 to 60 000 000 Hz and <Enter>");
                   }
                else 
                   {
                      Serial.write(12);
                      writefreq(frequency,FQ_UD);
                      Serial.println("\n");
                      Serial.print("Setting frequency to ");
                      Serial.print(dtostrf(frequency/1.0e6,0,6,stringbuffer)); 
                      Serial.println(" MHz\n");
                      writefreq(frequency,FQ_UD);
                      
                   }
             }
       }
}
 
//==========FUNCTION DEFS ====================
void writefreq(long freq, int chip_select) 
     {  //power saving version keeps chip select low
       delta = (unsigned long) freq*TWO_E32/CLOCKFREQ; 
       byte W[5] = {0,0,0,0,0};
       W[0] = (byte) delta;
       W[1] = (byte) (delta >> 8);
       W[2] = (byte) (delta >> 16);
       W[3] = (byte) (delta >> 24);
       W[4] = 0; //phase zero
       digitalWrite(chip_select,HIGH);
       delayMicroseconds(2); 
       digitalWrite(chip_select,LOW);
       delayMicroseconds(4);
       for (int j = 0; j<5;j++)
           {
             SPI.transfer(W[j]);
           }
       delayMicroseconds(4);
       digitalWrite(chip_select,HIGH);
       delay(1);
       digitalWrite(chip_select,LOW);
      }

