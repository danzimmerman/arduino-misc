
/*
Ultrasound stepper rotator v 1.2 / July 16, 2009 by Axl
Now set up for worm gear drive, ratio 17.50:1 XXXXX this is wrong.  Actual drive ratio 35:1 !!

Approximately 0.05143 degrees per step, 7000 steps give one revolution of the output shaft
*/
#include <Messenger.h> //we need the "Messenger" library to do some of the command handling.
Messenger message = Messenger();

int lim = 2; // limit switch input pin
 
int brn = 4; // brown wire, phase one 
int blu = 5; // blue wire, phase two
int yel = 6; // yellow wire, phase three
int red = 7; // red wire, phase four
int mot[] = {brn, blu, yel, red}; // this is the array of motor pins: 0  = brn, 1 = blu, 2 = yel, 3 = red.

int curpos = 7001; // variable to hold current position, range 0-7000 steps (for one full revolution, actually can only go 290 degrees without hitting something)
int commandpos = 0; // variable to hold the commanded position in STEPS
int curphase = 0; // this is the  motor phase 0 thru 4
int welcome = 1; // initialize to "true" to go through welcome screen once
int commandangle = 0;  // variable to hold the commanded angle read from the serial port

// phase rotation sequence is: brown, blue, yellow, red (0,1,2,3) is counterclockwise as viewed from motor face

void setup()
{
  pinMode(lim,INPUT);      //set limit switch pin as an output
  digitalWrite(lim,HIGH);  //set limit switch pullup resistor on
  for (int j = 0; j<4; j++) {//loop to initialize the output pins
    pinMode(mot[j],OUTPUT); }
    Serial.begin(115200);
   
}

void loop(){
  
  while(welcome > 0){
    Serial.println("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
    
    Serial.println("Welcome to Ultrasound Rotator v. 1.3");
    Serial.println();
    Serial.println("Enter integer 0-290 degrees and <Enter>, or -1 to reset to limit.");
       Serial.println();
    welcome = 0;}
  //First, step back until the limit switch is found
  restart:
  while(curpos>7000){
   
  int lstate = digitalRead(lim);  // read limit switch current position
  delay(5);
  int lcheck = digitalRead(lim);  // read again 5ms later for debounce check
  
  if ((lstate == lcheck) && (lstate == 0)){ //once limit switch pin is pulled low, set the current position to "0" and move on
  curpos = 0; digitalWrite(mot[curphase],LOW);}
    else
    if ((lstate == lcheck) && (lstate == 1)){
    curphase = stepCCW(curphase);
    delay(5);
    
  
    }
    
  }
  
  
   
  while(Serial.available()==0){  //when nothing has been input over the serial connection, display "Waiting" and little twirly slash to show activity
    
    Serial.print(13,BYTE);
    Serial.print("Waiting for command    /");
    delay(50);
    Serial.print(13,BYTE);
    Serial.print("Waiting for command    |");
    delay(50);
    Serial.print(13,BYTE);
    Serial.print("Waiting for command    \\");
    delay(50);
    Serial.print(13,BYTE);
    Serial.print("Waiting for command    -");
    delay(50);
   
   
    };
 
  
  while(Serial.available()) { //when something becomes available on the serial port, use the Messenger library functions to get the angle
    
    if( message.process(Serial.read()) ) {
      while(message.available()) { 
        commandangle = message.readInt();
        
      }
      
      delay(500); // half second delay to make the interface feel "causal"
        if (commandangle == -1) {  // -1 means "reset"
          Serial.println("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
          Serial.print("Received ");
          Serial.print(commandangle,DEC);
          Serial.println("; Resetting to limit switch... \n \n");
          curpos = 7001;
          goto restart;
      
    }
          else
          if (commandangle <-1 || commandangle > 290){ // if out of the range of allowed angles, send an error message
        Serial.println("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
        Serial.print(commandangle,DEC);
        Serial.println(" degrees out of range.  Enter 0-290 and <Enter>, -1 to reset.");
          }
       
      else {
        commandpos = round(commandangle/0.05143); // if angle is in the range of allowed angles, then calculate the nearest position in steps
      Serial.println("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n");
      Serial.print("Rotating transducer to ");
       Serial.print(commandangle,DEC); 
       Serial.print(" degrees...");
        curpos = rotate(curpos,commandpos); // and move the output shaft to that position
  
  Serial.print("      done.\n\n\n");
    }
  }
}
}
 

//********FUNCTION DEFINITIONS BELOW*********
  //********************************************
  int stepCCW(int curphase ){ // sequence is 0 1 2 3, this function does one step counterclockwise, the current phase is the input, and it returns the new phase
  digitalWrite(mot[curphase],LOW);
  digitalWrite(mot[(curphase+1)%4],HIGH); 
  return (curphase+1)%4;}
  //********************************************
  int stepCW(int curphase){ // sequence is 3 2 1 0, this function does one step clockwise, I/O same as above
  digitalWrite(mot[curphase],LOW);
  digitalWrite(mot[(curphase+3)%4],HIGH);
  return (3+curphase)%4;} 
  
  //********************************************
  int rotate(int pos, int cmd){  // this function takes the CURRENT position and the COMMANDED position and steps the right direction until commanded is reached
  
  int stepcnt = cmd-pos;
  
  if (stepcnt>0){              // if the desired location is clockwise from the current one
    for(int j = stepcnt; j>0; j--){
      curphase = stepCW(curphase);
      delay(5);
    }
     digitalWrite(mot[curphase],LOW);
    return cmd;
  }
  
  else
  
  if(stepcnt<0){              // if it's counterclockwise instead 
    for(int j = stepcnt; j<0; j++){
      curphase = stepCCW(curphase);
      delay(5);
    }
     digitalWrite(mot[curphase],LOW);
    return cmd;
  }
  
   }
    
    
    
    
