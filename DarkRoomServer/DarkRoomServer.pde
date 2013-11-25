/* ************************************************
    DarkRoomServer by enelija
      
      to use with the local audio system
                  the local tracking system
                  the via Bluetooth connected haptic vest
                  the remotely connected CAVE
      
   ************************************************ */
// import libraries
import oscP5.*;
import netP5.*;
import processing.serial.*;

final boolean DEBUG = true;

// tracking related variables
OscP5 oscP5;
NetAddress theRemoteLocation;
final int LISTENERPORT = 12346;
float trackedX = 0.0, trackedY = 0.0, trackedO = 0.0;
String oscTrackingPattern = "/tracking";
String oscCavePersonActivityPattern = "/cave_person/activity";

// Bluetooth connection
Serial bluetooth;
int baudRate = 115200;
int maxMotor = 15;
int maxStrength = 63;

void setup() {
  setupOscListener();
  setupSerial();
}

void draw() {
}

void setupOscListener() {
  oscP5 = new OscP5(this, LISTENERPORT);
}

void setupSerial() {
  for (int i = 0; i < Serial.list().length; ++i)
    println(Serial.list()[i]);
  String portName = Serial.list()[1];      // COM3 
  bluetooth = new Serial(this, portName, baudRate);
  
  // for testing only
  sendToHapticVest(0, 0);
  sendToHapticVest(15, 63);
}

// receive position x/y and orientation
void oscEvent(OscMessage message) {
  if (DEBUG) 
    println("OSC message received: " + message.addrPattern() + " " + message.typetag());
      
  if (message.addrPattern().equals(oscTrackingPattern) && message.checkTypetag("fff")) { 
    trackedX = message.get(0).floatValue();
    trackedY = message.get(1).floatValue();
    trackedO = message.get(2).floatValue();
    
    // TODO: forward this message to cave (other port and IP) here
    
    if (DEBUG) 
      println("   " + trackedX + " / " + trackedY + " / " + trackedO);
  } 
  
  // TODO: react on other OSC messages
  //else if (message.addrPattern() == oscTrackingPattern && message.checkTypetag("fff")) {
  // TODO: forward this message to cave (other port and IP)
  //       see http://www.interface.ufg.ac.at/vrprojectwiki/index.php/Communication_Protocol
  // }
}

// send motor control messages
void sendToHapticVest(int motor, int strength) {
  // TODO: implement sending to Bluetooth  
  //       see http://www.interface.ufg.ac.at/vrprojectwiki/index.php/Communication_Protocol#X_.E2.86.92_HAPTIC_VEST
  if (motor < maxMotor && strength < maxStrength) {
    char motorFlag = char(65 + motor);
    char strengthFlag = char(48 + strength); 
    String command = "p" + motorFlag + strengthFlag;    // TODO: add explicit LR or CF if necessary
    if (DEBUG)
      println("Sending command " + command);
    bluetooth.write(command);
  }
}

// send reset motor control message
void sendResetToHapticVest() {
  // TODO: implement sending to Bluetooth  
  //       see http://www.interface.ufg.ac.at/vrprojectwiki/index.php/Communication_Protocol#X_.E2.86.92_HAPTIC_VEST
  String command = "r";    // TODO: add explicit LR or CF if necessary
  if (DEBUG)
    println("Sending command " + command);
  bluetooth.write(command);
}

// send volume, distance, angle for a sound event
void sendToSoundSystem() {
}

