/*spi_ADC_xbee Version 2.0 Written 10/15/09 by Axl Modified to fix 2's complement problem!

This Arduino microcontroller code reads values from a Microchip MCP-3553 22 bit SPI-compatable serial A/D converter and
transmits those values over a conventional 115200bps serial connection (115200 baud 8N1).

This serial connection can be made wireless with XBee serial wireless devices 

*/

    #define DATOUT 11 // pin 11 : SPI data output : here unused, MCP-3553 needs no config information
    #define DATIN 12  // pin 12 : SPI data input
    #define SCLOCK 13 // pin 13 : SPI clock pin
    #define CHIPSEL 10 // pin 10 : Slave Chip Select 1 : also unused, MCP-3553 in "Continuous Conversion" mode
    #define STATLED 8 // pin 8: flashing status LED
   
    /* The MCP-3553 has 24 bits of output data queued in its SPI register after each conversion:
| OVL | OVH | 21 | 20 | 19 | 18 | 17 | 16 | 15 | 14 | 13 | 12 | 11 | 10 | 09 | 08 | 07 | 06 | 05 | 04 | 03 | 02 | 01 | 00 |

The Atmega168/Arduino conducts SPI transfers in one-byte chunks.  Writing a byte of data to the SPDR register
starts an automatic transfer of the Arduino's byte to the peripheral device and simultaneously transfers one byte
from the MCP-3553 to the SPDR register.  In this case, we'll just write dummy bytes to SPDR to make the transfer go,
and collect the incoming bytes.  Since the data to be read is 24 bits (22 data plus low side and high side overload)
we'll do three transfers to get the following:

topbyte: | OVL | OVH | 21 | 20 | 19 | 18 | 17 | 16 |
midbyte: | 15 | 14 | 13 | 12 | 11 | 10 | 09 | 08 |
lowbyte: | 07 | 06 | 05 | 04 | 03 | 02 | 01 | 00 |

*/



    byte topbyte;
    byte midbyte;
    byte lowbyte;
     long torque; //all three bytes together
     long tbl; // long topbyte
     long mbl; // long midbyte
     long lbl; // long lowbyte
    long torqueout;
   
    byte clr; // somewhere to dump SPI Status and SPI Data registers to initially clear them out
   
     byte spi_transfer(volatile char data) //define the function spi_transfer
    {
       SPDR = data;                // write to SPDR, starting transmission
       while (!(SPSR & (1<<SPIF))) // waits until bit 7, SPI status register, goes high signifiying done with transfer
        {
        };                         // do nothing 
       
      return SPDR;
    }

void setup()
{
  //initialize the XBee-side serial port
      Serial.begin(115200);
 
  //initialize the SPI pins 
      pinMode(DATOUT, OUTPUT);
      pinMode(DATIN, INPUT);
      pinMode(SCLOCK, OUTPUT);
      pinMode(CHIPSEL, OUTPUT);
      pinMode(STATLED,OUTPUT);
      digitalWrite(CHIPSEL,HIGH); // initialize chip select
     
 
  /* Set up SPI Control Register; SPCR = 01011011 :
  | 7 Disable SPI Interrupt | 6 Enable SPI | 5 MSB First | 4 Master Mode | 3 Clock Idles High | 2 Data Latched Rising Edge | 1 SPR1 | 0 SPR0 |
  | 7 SPIE  | 6 SPE* | 5 DORD | 4 MSTR* | 3 CPOL* | 2 CPHA* | 1 SPR1* | 0 SPR0* | (marked * must be set to 1)
 
 
  Speed bits set to 11 for debugging, that's slowest speed.  I think it's 250kHz
 
  The names (SPIE, MSTR, etc) are associated with their numbers in the compiler somewhere,
  so the bitwise-OR of bitshifted "1"s below actually works.
 
  */
 
        SPCR = ((1<<SPE)|(1<<MSTR)|(1<<CPOL)|(1<<CPHA)|(1<<SPR1)|(1<<SPR0)); // You wouldn't think from the datasheet that CPHA = 1, but I think that's what SPI(1,1) means   
        clr = SPSR; // apparently assigning the SPI Status Register to a dummy variable clears it out
        clr = SPDR; // the same goes for the SPI Data Register
 
        delay(10); //wait awhile;
 
 //print "hi" and a newline out the serial port to show setup is complete      
        Serial.print('h',BYTE);
        Serial.print('i',BYTE);
        Serial.print('\n',BYTE);
        //this sends "OK" in morse code via the status LED
        digitalWrite(STATLED,HIGH); delay(200);
        digitalWrite(STATLED,LOW);delay(200);
        digitalWrite(STATLED,HIGH);delay(200);
        digitalWrite(STATLED,LOW);delay(200);
        digitalWrite(STATLED,HIGH);delay(200);
        digitalWrite(STATLED,LOW);delay(200);
        delay(400);
        digitalWrite(STATLED,HIGH);delay(200);
        digitalWrite(STATLED,LOW);delay(200);
        digitalWrite(STATLED,HIGH);delay(66.6);
        digitalWrite(STATLED,LOW);delay(200);
        digitalWrite(STATLED,HIGH);delay(300);
        digitalWrite(STATLED,LOW);delay(300);
        
        delay(10); //wait a while again
       
}       

void loop()
{
/*this seems very simple, but the MCP-3553 does no conversion once the clocked transfer starts.  It resumes converting after
all 24 bits are clocked out, so it should work out. */
digitalWrite(STATLED,LOW);
digitalWrite(CHIPSEL,LOW);
delay(2);
digitalWrite(CHIPSEL,HIGH);
delay(22);

  digitalWrite(CHIPSEL,LOW); delayMicroseconds(128);
    topbyte = spi_transfer(0xAA);delayMicroseconds(24);
    midbyte = spi_transfer(0x55);delayMicroseconds(24);
    lowbyte = spi_transfer(0xAA);delayMicroseconds(24);
  digitalWrite(CHIPSEL,HIGH);
  


    digitalWrite(STATLED,HIGH);
  
   // make each byte a long
   tbl = topbyte;
   mbl = midbyte;
   lbl = lowbyte;
   //put bytes together
  
   torque = (tbl<<16)+(mbl<<8)+lbl;
  
long testcon = pow(2,21);
   long oset = pow(2,22);
   //int zerro = 0;
  if (torque>=testcon)
 torqueout = (torque-oset);
 else
 torqueout = torque;
     
   /* some binary printing for the sake of debugging, ignore
   
    Serial.print(topbyte,BIN);
    Serial.print(' ',BYTE); 
    Serial.print(midbyte,BIN);
    
    Serial.println(lowbyte,BIN);*/
  //Serial.println(torqueout,DEC);
  Serial.print((long)testcon,DEC);
  Serial.print(' ',BYTE);
  Serial.print((long)oset,DEC);
  Serial.print(' ',BYTE);
  Serial.print((long)torque,DEC);
  Serial.print(' ',BYTE);
  Serial.println((long)torqueout,DEC);//print the real thing.  Numbers greater than 2^21 represent the negatives... 2's complement encoding 
   
    delay(6); // speed it up later; this is the bulk of the delay; empirically set to total delay = 20ms
} 
  
   
// that might be it?
    
