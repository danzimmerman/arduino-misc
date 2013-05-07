/*Parallel port controllable matching network switch Arduino code by N3OX ... 
 *Version 2.2, 070709 0418Z, added RX LED output and TX inhibit
 */

/* We have to set up, or "declare" a bunch of variables first.
First, we name the three motor output pins that go to the MOSFET driver circuits.
*/
//****************************************
int redpin = 8;  
int orgpin = 9;
int yelpin = 10;
//****************************************

/*Here are some other pins that do stuff... in my application, there's a LED
that lights up when the switch is moved to "half" positions for low band detuning.  In these positions
+5V is also applied to the rig's accesory port, which makes it impossible to produce RF, helping to protect my
preamp
*/
//****************************************
int rxled = 6; // initialize RX LED output
int txinh = 7; // Transmit inhibit output
//****************************************

/*The Arduino needs some INPUTS, too.
DI12 = RX switch input, pulled up to +5V
DI3 = Pin 2 DB25 = D0
DI4 = Pin 3 DB25 = D1
DI5 = Pin 4 DB25 = D2

The RX switch pin, #12 on the Arduino, is operated from auxiliary contacts on my TX/RX relay.
The three pins #3,4,5 on the Arduino have values set by the parallel port
*/

//****************************************
int inpin[] = {12, 3, 4, 5}; // moved rx switch to #12 to free up pin 2 (for future use of its interrupt for tx_gnd)
int bits[] = {0, 0, 0, 0}; 
//****************************************


//Here's an input for the limit switch, and some other variables that will hold its value, etc.
//****************************************
int limit = 11; 
int lstate = 0;
int lcheck = 0;
//****************************************

//These variables keep track of what motor phase we just pulsed and where we are and where we're going in steps
//****************************************
int curphase = 1; // which step are we on?  red = 1, orange = 2, yellow = 3.  RYO is CW ROY is CCW

int curpos = 99; // what switch positition are we actually on
int stepcnt = 0; //  the difference between where we are and where we're going, signed 
//****************************************

//These variables are related to the front panel band switch potentiometer

//****************************************
int pot = 0;   // analog input pot input pin number
int potval = 0; // value for it
int potcheck = 0; // debounce check
//****************************************

/*These are variables for which band we should command the switch to and whether or not we're in
"RX" mode, with the switch at half position.
*/
//****************************************
int bincode = 0; //the binary number 0 through 7 that represents the band we're on
int rxcode = 0;  //whether or not we should half step to RX.  1 for no, 0 for yes (sorry)
//****************************************

/*  Switch contacts are, in steps away from zero, 

1: 12 
2: 23
3: 33
4: 43
5: 53
6: 63

*/


/* Here we tell the Ardino what's an input, what's an output, and whether or not we should "pull up" input pins to high level
We don't need to pull up the pins that get connected to the parallel port, because it can source voltage.  However, the 
RX Switch pin and the Limit Switch pin we do pull up so we don't need external resistors, just the switch pulling the 
voltage to ground
*/
//****************************************
void setup()                    
{
  pinMode(redpin, OUTPUT); //set up output pins
  pinMode(orgpin, OUTPUT);  
  pinMode(yelpin, OUTPUT); 
  pinMode(rxled,OUTPUT);
  pinMode(txinh,OUTPUT);
  pinMode(limit, INPUT);   //set up input pins
  for (int j=0; j<4; j++){
    pinMode(inpin[j],INPUT);    
    //digitalWrite(inpin[j],HIGH);  //do not pull up pins 3,4,5 anymore, commented out
  }
  digitalWrite(inpin[0],HIGH); //pull up pin 12 (inpin[0]) for RX switch
  digitalWrite(limit,HIGH);    //pull up limit switch pin 11

 

}
//****************************************
//now we get down to doing something... 
void loop()                     
{
  
  while(curpos>70) {             // if current position not defined, run back to the limit switch, set position to zero
    
    
  lstate = digitalRead(limit); // read current state of limit switch
  delay(5);
  lcheck = digitalRead(limit); // and debounce check 10ms later
  
  if ((lstate == lcheck) && (lstate == 0)){    // if already at the limit, just set curpos = 0, right up against the limit switch
     curpos = 0; }
     else 
     
     if ((lstate == lcheck) && (lstate == 1)){      // if not at limit, step counterclockwise till you find the limit switch
     curphase = stepCCW(curphase);
     }
  }
    
    delay(50); //wait a bit
    
    potval = analogRead(pot);  //read the value of the front panel bandswitch input pot
   
    if (potval<25){            //if pot is on "auto", read the digital pins instead of setting the band based on the pot
    for (int i=0;i<4;i++){
      bits[i] = read_debounce(inpin[i]); 
      bincode = (bits[1]<<2) + (bits[2]<<1) + bits[3]; //  combine DI 3,4,5 into a single binary number for parallel port control 
      rxcode = bits[0];} } // check whether we're on "RX" or not
      else {rxcode = read_debounce(inpin[0]);  // now if we're NOT on auto, we need to do something else.  RX code is still the same pin
      
    if ((potval>25)&&(potval<75)) // but we set the "bincode" for the band using the voltage read from the pot instead!
      bincode = B010; 
    if ((potval>150) && (potval<220))
      bincode = B011; 
    if ((potval>270) && (potval<330))
      bincode = B100; 
    if ((potval>380) && (potval<450))
      bincode = B101; 
    if ((potval>510) && (potval<580))
      bincode = B110; 
    if ((potval>650) && (potval<720))
      bincode = B111; 
      }
    if (potval>770) {
      bincode = B000;}
      
  
    // So, now we move the switch.  If the "rxcode" hasn't been set to 0 by pressing the footswitch, we do this part:

   
  if (rxcode == 1) {  // 1 is "transmitting" position
    digitalWrite(rxled,LOW);
    digitalWrite(txinh,LOW);
    if (bincode == B000){
      curpos = moveswitch(curpos,2);}
    if (bincode == B010){
      curpos = moveswitch(curpos,12);}
    if (bincode == B011){
      curpos = moveswitch(curpos,23);}
    if (bincode == B100){
      curpos = moveswitch(curpos,33);}
    if (bincode == B101){
      curpos = moveswitch(curpos,43);}
    if (bincode == B110){
      curpos = moveswitch(curpos,53);}
    if (bincode == B111){
      curpos = moveswitch(curpos,63);}
  
  
  }
  //if RX pin is pulled down, so we're in RX mode, do this part instead.  The only difference is the commanded positions.
  if (rxcode == 0) {
    digitalWrite(rxled,HIGH);
    digitalWrite(txinh,HIGH);
     if (bincode == B000){
      curpos = moveswitch(curpos,2);}
    if (bincode == B010){
      curpos = moveswitch(curpos,17);}
    if (bincode == B011){
      curpos = moveswitch(curpos,28);}
    if (bincode == B100){
      curpos = moveswitch(curpos,38);}
    if (bincode == B101){
      curpos = moveswitch(curpos,48);}
    if (bincode == B110){
      curpos = moveswitch(curpos,58);}
    if (bincode == B111){
      curpos = moveswitch(curpos,68);}
  }
      
    
  
}
  
  //down here, we define some functions used in the code above:
  
  
  //read_debounce(pinno) reads the pin number passed in as pinno, waits 10ms, and reads it again to make sure it's settled down
  //*****************************
  int read_debounce(int pinno){
    int firstval = 0;
    int secondval = 1;
    while (firstval!=secondval){
    firstval = digitalRead(pinno);
    delay(10);
    secondval = digitalRead(pinno);}
    return firstval;
    
    
    }
 //*****************************
   
 //moveswitch(curp,desp) moves the switch.  It has two inputs, the current position and the desired position
 //*****************************
  int moveswitch(int curp, int desp) {    
  
  
  int stepcnt = desp-curp;  
  /* this calculates how far you have to go to the desired location, it can be positive or negative depending on
 which   way you need to go*/
  
    if (stepcnt>0){                      // if the location is CW from here, a positive number, 
      for(int j = stepcnt; j>0; j--){    // step downward, decrementing stepcnt until you reach zero
        curphase = stepCW(curphase);
    }
 return desp; }
    
    else
    
  if (stepcnt<0){
    for (int j = stepcnt; j<0; j++){    // if the location is CCW instead, a negative number
      curphase = stepCCW(curphase);     // step upward and move CCW until you reach zero
    }
  
      
  }
  return desp;  // this "returns" the desired position you told this function, which the main program then takes as the new "current position"
  }

/*This part is the hardest bit to modify
This is the part of the code that does a single step, and you have to tweak it to make your motor run right.
The basic plan is to take the *current phase* as an input .. the main loop keeps track of that,
and then energize the NEXT phase in the right sequence to step CCW.  It's a little complicated
because I found it useful to energize both current and next phase briefly and then "let go" of the 
current phase to make the motor run with reliable smooth power under different loads
*/
int stepCCW(int curphase){  // sequence ROY
  
 if (curphase == 1){           //if red(1), red steps to orange (2) 
 digitalWrite(redpin,HIGH);
 digitalWrite(orgpin,HIGH);
 delay(2);
 digitalWrite(redpin,LOW);
 delay(25);
 digitalWrite(orgpin,LOW);
 curphase = 2;
 return curphase;
 }
 else
 if (curphase == 2) {  

 digitalWrite(orgpin,HIGH); // if orange (2), orange steps to yellow (3)
 digitalWrite(yelpin,HIGH);
 delay(2);
 digitalWrite(orgpin,LOW);
 delay(25);
 digitalWrite(yelpin,LOW);

 
 curphase = 3; 
 return curphase;
 } 
 else 
 if (curphase == 3){         // if yellow (3) yellow steps to red (1)

 digitalWrite(yelpin,HIGH);
 digitalWrite(redpin,HIGH);
 delay(2);
 digitalWrite(yelpin,LOW);
 delay(25);
 digitalWrite(redpin,LOW);   

 curphase = 1; 
 return curphase;
 }
} 

//this is the same as stepCCW, but in the other direction
 //*****************************
 int stepCW(int curphase){   // sequence RYO
  
 if (curphase == 1){           //if red (1),  red steps to yellow (3)
 digitalWrite(redpin,HIGH);
 digitalWrite(yelpin,HIGH);
 delay(2);
 digitalWrite(redpin,LOW);
 delay(25);
 digitalWrite(yelpin,LOW);
 curphase = 3;
 return curphase;
 }
 else
 if (curphase == 2) {    // if orange(2), orange steps to red (1)

 digitalWrite(orgpin,HIGH);
 digitalWrite(redpin,HIGH);
 delay(2);
 digitalWrite(orgpin,LOW);
 delay(25);
 digitalWrite(redpin,LOW);
 // yellow steps to orange
 
 curphase = 1; 
 return curphase;
 } 
 else 
 if (curphase == 3){  // if yellow (3), yellow steps to orange (2)

 digitalWrite(yelpin,HIGH);
 digitalWrite(orgpin,HIGH);
 delay(2);
 digitalWrite(yelpin,LOW);
 delay(25);
 digitalWrite(orgpin,LOW);   
 
 curphase = 2; 
 return curphase;
 }
 
}
