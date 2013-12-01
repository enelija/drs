/* ************************************************
    DarkRoomServer by ivan & enelija
      
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

// sound
final int POSITION = 0;
final int VELOCITY = 1;
final int BUMP = 2;
final int TOUCH = 3;
final int HIT = 4;
final int NUMBER_INTERACTIONS = 5;
float [] volumes = {1.0, 1.0, 1.0, 1.0, 1.0};
SpatialSoundEvent soundEvents[] = new SpatialSoundEvent[NUMBER_INTERACTIONS];
boolean isSystemOn = true /* false */, isTouchOn = false;

// OSC communication
OscP5 trackingListener, trackingSender, caveListener, caveListenerTcp, soundSender; 
NetAddress caveNetAddress, soundNetAddress;
final int SOUND_SENDER_PORT = 12345;
final int TRACKING_SENDER_PORT = 12346;
final int TRACKING_LISTENER_PORT = 12347;
final int CAVE_LISTENER_PORT = 12348;
final int CAVE_LISTENER_TCP_PORT = 12349;

String caveIP = "127.0.0.1";
String localIP = "127.0.0.1";

String soundPattern = "/SonicCave";                                  // UDP
String trackingPattern = "/tracking";                                // UDP
String caveUserActivityPattern = "/cave_person/activity";            // TCP
String caveUserPositionPattern = "/cave_person/position";            // UDP
String caveUserVelocityPattern = "/cave_person/velocity";            // UDP
String caveUserTouchPattern = "/cave_person/touch";                  // TCP
String caveUserTouchingPattern = "/cave_person/touching";            // UDP
String caveUserHitPattern = "/cave_person/hit";                      // TCP
String caveUserBumpPattern = "/cave_person/bump";                    // TCP
String roomPersonPositionPattern = "/room_person/position";          // UDP
String roomPersonOrientationPattern = "/room_person/orientation";    // UDP
String roomPersonHeartbeatPattern = "/room_person/hearbeat";         // UDP
float centerX = 0.0, centerY = 0.0, 
      roomUserX = 0.0, roomUserY = 0.0, roomUserO = 0.0,
      caveUserX = 0.0, caveUserY = 0.0, caveUserVel = 0.0, 
      maxVelocity = 1.0,
      caveUserSoundDistance = 0.0, caveUserSoundAngle = 0.0;
int roomUserH = 60;                                                  // in beats per minute
int minHearbeat = 60, maxHeartbeat = 180;                            // in beats per minute
int lastHearbeat = 0;

int bumpHitLength = 300; // 300 milliseconds
int bumpHitBegin = 0;
int touchTimeout = 500;  // 500 milliseconds
boolean bumpHitOn = false;

// dimensions of all rooms are in centimeters
//   CAVE: is a right-handed cartesian coordinate system 
//         X: right axis; Y: depth axis into the screen; Z: up axis, counter-clockwise rotation
//   DARK ROOM: 2D coordinate system and square
//              origin is upper/left coordinate of the camera
//   SOUND SYSTEM: 2D coordinate system and square
//                 origin is in the center
float caveVirtualWidth = 500, caveVirtualLength = 500, caveVirtualHeight = 300, 
      darkRoomWidth = 300, darkRoomLength = 300, darkRoomHeight = 200; 

// bluetooth connection
Serial bluetooth;
final int bluetoothPort = 0; // 0: COM1 (Windows) // 1: COM3 (Windows)
int baudRate = 115200;
int maxMotor = 15;
int maxStrength = 63;

int bumpStrength = 50;
int hitStrength = 63;

void setup() {
  setupOscListeners();
  setupOscSenders();
  setupSerial();
  setupSounds();
}

void draw() {}

// setup methods
void setupOscListeners() {
  trackingListener = new OscP5(this, TRACKING_LISTENER_PORT);
  caveListenerTcp = new OscP5(caveIP, CAVE_LISTENER_TCP_PORT, OscP5.TCP);
  caveListener = new OscP5(caveIP, CAVE_LISTENER_PORT);
}

void setupOscSenders() {
  trackingSender = new OscP5(caveIP, TRACKING_SENDER_PORT);
  soundSender = new OscP5(this, SOUND_SENDER_PORT);
  caveNetAddress = new NetAddress(caveIP, TRACKING_SENDER_PORT);
  soundNetAddress = new NetAddress(localIP, SOUND_SENDER_PORT);
}

void setupSerial() {
  for (int i = 0; i < Serial.list().length; ++i)
    println(Serial.list()[i]);
  String portName = Serial.list()[bluetoothPort];  
  bluetooth = new Serial(this, portName, baudRate);
}

void setupSounds() {
  for (int i = 0; i < NUMBER_INTERACTIONS; ++i) {
    soundEvents[i] = new SpatialSoundEvent(i);
    soundEvents[i].setVolume(volumes[i]);
    // turn looped sounds on later: when activity message is received
    if (i == POSITION || i == TOUCH) {
      soundEvents[i].setIsLooped(true);
      soundEvents[i].setIsOn(false);
    }
  }
}

// receive OSC messages and react on them 
void oscEvent(OscMessage message) {
  if (DEBUG) 
    println("OSC message received: " + message.addrPattern() + " " + message.typetag());
  
  // *** receive CAVE person activity ****************************************************************
  if (message.addrPattern() == caveUserActivityPattern && message.checkTypetag("i")) {
    int onState = message.get(0).intValue();
    if (onState == 1) {                                // turn system and looped sounds on
      isSystemOn = true;
      for (int i = 0; i < NUMBER_INTERACTIONS; ++i) {
        if (soundEvents[i].isLooped())
          soundEvents[i].setIsOn(true);
      }
    } else if (onState == 0) {                         // turn system and looped sounds off
      isSystemOn = false;
      for (int i = 0; i < NUMBER_INTERACTIONS; ++i) { 
        if (soundEvents[i].isLooped()) {
          soundEvents[i].setIsOn(false);
          sendSoundEventOff(i);
        }
      }
    }
  }
  
  if (isSystemOn) {
    // *** receive tracking position and orientation *************************************************
    if (message.addrPattern().equals(trackingPattern) && message.checkTypetag("fff")) { 
      roomUserX = message.get(0).floatValue();
      roomUserY = message.get(1).floatValue();
      roomUserO = message.get(2).floatValue();
      
      // send position to CAVE
      OscMessage positionToCave = new OscMessage(roomPersonPositionPattern);
      positionToCave.add(roomUserX);      // TODO: probably map dark room dimensions to CAVE dimensions
      positionToCave.add(roomUserY);
      trackingSender.send(positionToCave, caveNetAddress);
      
      // send orientation to CAVE
      OscMessage orientationToCave = new OscMessage(roomPersonOrientationPattern);
      orientationToCave.add(roomUserO);
      trackingSender.send(orientationToCave, caveNetAddress); 
      
      // send heartbeat to CAVE
      OscMessage heartbeatToCave = new OscMessage(roomPersonHeartbeatPattern);
      heartbeatToCave.add(roomUserH);
      trackingSender.send(heartbeatToCave, caveNetAddress); 
      
      if (DEBUG) 
        println("   tracked X/Y/O: " + roomUserX + " / " + roomUserY + " / " + roomUserO);
    } 
    
    // *** receive CAVE position  ********************************************************************
    else if (message.addrPattern() == caveUserPositionPattern && message.checkTypetag("ff")) {
      caveUserX = message.get(0).floatValue();
      caveUserY = message.get(1).floatValue();
      
      // send to sound system (caveuser)
      caveUserSoundDistance = dist(centerX, centerY, caveUserX, caveUserY);
      caveUserSoundAngle = 180.0 + atan2((centerY - caveUserY), (centerX - caveUserX)) * 180.0 / PI;
      sendSoundChangeEvent(POSITION, caveUserSoundDistance, caveUserSoundAngle);
    }
      
    // *** receive CAVE velocity *********************************************************************
    else if (message.addrPattern() == caveUserVelocityPattern && message.checkTypetag("f")) {
      float velocity = message.get(1).floatValue();
      
      // send to sound system (heartbeat)
      int now = millis();
      // TODO: maybe average last n velocity values to get smoother heartbeat changes
      int heartbeat = int(map(velocity, 0.0, maxVelocity, minHearbeat, maxHeartbeat));
      if (float(now - lastHearbeat) > 1.0 / float(heartbeat) * 60000) {
        sendSoundChangeEvent(VELOCITY, caveUserSoundDistance, caveUserSoundAngle);
        lastHearbeat = now;
      }
    }
    
    // *** receive CAVE touch event ******************************************************************
    else if (message.addrPattern() == caveUserTouchPattern && message.checkTypetag("i")) {
      int onState = message.get(0).intValue();
      
      // send to sound system -> turn sound (touch) on / off    
      if (onState == 1) {
        isTouchOn = true;
        soundEvents[TOUCH].setIsOn(true);
      } else if (onState == 0) {
        isTouchOn = false;
        soundEvents[TOUCH].setIsOn(false);
        sendResetToHapticVest();
      }
    }
    
    // *** receive CAVE touch positions **************************************************************
    else if (isTouchOn && message.addrPattern() == caveUserTouchingPattern && message.checkTypetag("fff")) {      
        //        R         FRONT         L
        //        <--------- 52cm -------->
        //        +--------] _ _ [--------+           0: right shoulder (outer)
        //      / |   0 1 2       3 4 5   | \         1: right shoulder (center)
        //     /  |   <9cm>       <9cm>   |  \        2: right shoulder (inner) 
        //    /    \                     /    \       3: left shoulder (inner)
        //   /    / \                   / \    \      4: left shoulder (center)
        //   |  7|   \                 /   |6  |      5: left shoulder (outer) 
        //   |   |  +-------------------+  |   |      6: left arm
        //   |   |  |8                 9|  |   |      7: right arm
        //   |   |  +-------------------+  |   |      8: right hip
        //               \         /                  9: left hip
        //                \ _____ /
        
        //       L           BACK          R
        //  +-   +--------] _ _ _ [--------+ -+
        //  8cm  |  <------- 30cm ------>  |  |      10: back (left very top)
        //  +-   |  10          _|7cm  11  |  |      11: back (right very top)
        //        \          12 _|14cm    /   |      12: back (center top)
        //         \         13 _|21cm   /    |      13: back (center center top)
        //          \        14 _|28cm  /   62,5cm   14: back (center center bottom)
        //           \       15 _|35cm /      |      15: back (center bottom)
        //            \               /       |
        //             \             /        |
        //              \           /         |
        //               \ _______ /         -+
        //                <- 7cm ->
        
        float touchX = message.get(0).floatValue();
        float touchY = message.get(1).floatValue();
        float touchO = message.get(2).floatValue();
        
        // send touching coordinates to vest -> map to motors
        
        // for touching horizontally: map horizontal vector in cm from -40 (right) - +40 (left) to 
        //                                                             -30 (right) - +30 (left)
        // with -30 - -20 = motor 0
        //      -20 - -10 = motor 1
        //      -10 -   0 = motor 2
        //        0 -  10 = motor 3
        //       10 -  20 = motor 4
        //       20 -  30 = motor 5
        if (true) {
          sendResetToHapticVest();
          sendToHapticVest(0, hitStrength);       // horizontal 0-5
        }
        
        // for touching vertically: map z in cm from 140 (top) - 80 (bottom) to 
        //                                             0 (top) - 60 (bottom)
        // with  0-15 = motor 12
        //      15-30 = motor 13
        //      30-45 = motor 14
        //      45-60 = motor 15
        if (true) {
          sendResetToHapticVest();
          sendToHapticVest(12, hitStrength);      // vertical 12-15
        }
        
        // send touch position to system
        float distance = 0.0, angle = 0.0;
        sendSoundChangeEvent(TOUCH, distance, angle);
      }
    
    // *** receive CAVE hit positions **************************************************************
    else if (message.addrPattern() == caveUserHitPattern && message.checkTypetag("fff")) {
      float hitX = message.get(0).floatValue();
      float hitY = message.get(1).floatValue();
      float hitZ = message.get(2).floatValue();
      
      // new hit event received -> activate motors and sound
      if (newBumpHitEvent()) {
                
        // send hit to vest       
        // TODO: calculate hit position from room user direction and both users positions
        //       map hit coordinates to horizontal/vertical motor row/column on the vest
        
        // horizontal mapping (if touch more on the top / shoulder area)
        if (true)
          sendToHapticVest(0, hitStrength);       // vertical 0-5
        
        // vertical mapping (if touch more in the center / back area) 
        if (true)
          sendToHapticVest(6, hitStrength);       // vertical 12-15
        
        // send hit to sound system
        float distance = 0.0, angle = 0.0;
        sendSoundChangeEvent(HIT, distance, angle);
      } 
      
      // turn off motors
      else
        endBumpHitEvent();
    }
    
    // *** receive CAVE bump positions **************************************************************
    else if (message.addrPattern() == caveUserBumpPattern && message.checkTypetag("ff")) {
      float bumpX = message.get(0).floatValue();
      float bumpY = message.get(1).floatValue();
      
      // new bump event received -> activate motors and sound
      if (newBumpHitEvent()) {
        
        // send bump to vest       
        // TODO: calculate left/center/right bump from room user direction and both users positions
        // map bump coordinates to some selected left/center/right motors on the vest 
                
        //   bump left
        if (true) {
          sendToHapticVest( 5, bumpStrength);
          sendToHapticVest( 6, bumpStrength);
          sendToHapticVest( 9, bumpStrength);
          sendToHapticVest(10, bumpStrength);
        }
        
        //   bump center
        else if (true) {
          sendToHapticVest(12, bumpStrength);
          sendToHapticVest(13, bumpStrength);
          sendToHapticVest(14, bumpStrength);
          sendToHapticVest(15, bumpStrength);
        }
        
        //   bump right
        else if (true) {
          sendToHapticVest( 0, bumpStrength);
          sendToHapticVest( 7, bumpStrength);
          sendToHapticVest( 8, bumpStrength);
          sendToHapticVest(11, bumpStrength);
        }
        
        // send bump to sound system
        float distance = 0.0, angle = 0.0;
        sendSoundChangeEvent(BUMP, distance, angle);
      } 
      
      // turn off motors
      else
        endBumpHitEvent();
    }
  } 
}

boolean newBumpHitEvent() {
  if (!bumpHitOn) {
    resetBumpOrHit();
    bumpHitBegin = millis();
    bumpHitOn = true;
    return true;
  }
  return false;
}

void endBumpHitEvent() {
    // end bump vibrations after bumpHitLength ms
    if (millis() - bumpHitBegin > bumpHitLength) {
      resetBumpOrHit();  
      bumpHitBegin = -1;    
    }
}

// resets currently running bump or hit, starts a new one
void resetBumpOrHit() {
    if (bumpHitBegin != -1)
      sendResetToHapticVest();
    bumpHitBegin = millis(); 
}

// send motor control messages
void sendToHapticVest(int motor, int strength) {
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
  String command = "r";    // TODO: add explicit LR or CF if necessary
  if (DEBUG)
    println("Sending command " + command);
  bluetooth.write(command);
}

// send sound event change to sound system
void sendSoundChangeEvent(int interaction, float distance, float angle) {
    // set distance and angle for spatial sound
    soundEvents[interaction].setDistance(distance);
    soundEvents[interaction].setAngle(angle);
    // send sound change event
    OscMessage message = new OscMessage(soundPattern + "/" + soundEvents[interaction].getNumber());
    message.add(soundEvents[interaction].getVolume());
    message.add(soundEvents[interaction].getDistance());
    message.add(soundEvents[interaction].getAngle());
    if (DEBUG) {
      print("Sending OSC message with pattern " + message.addrPattern());
      print(" and typetag " + message.typetag() + ": " + soundEvents[interaction].getVolume() + " ");
      println(soundEvents[interaction].getDistance() +  " " + soundEvents[interaction].getAngle());
    }
    soundSender.send(message, soundNetAddress);
}

// send sound event off to sound system
void sendSoundEventOff(int interaction) {
    OscMessage message = new OscMessage(soundPattern + "/" + soundEvents[interaction].getNumber());
    message.add(0.0);
    message.add(0.0);
    message.add(0.0);
    if (DEBUG) {
      print("Sending OSC message with pattern " + message.addrPattern());
      print(" and typetag " + message.typetag() + ": 0.0 0.0 0.0");
    }
    soundSender.send(message, soundNetAddress);
}

