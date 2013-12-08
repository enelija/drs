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

// CONFIGURATION
// ==================================================================================
// COORDINATE SYSTEMS:
//   CAVE:   3D right-handed cartesian coordinate system
//           X: left to right axis; Y: bottom to top; 
//           Z: towards the screen
//           origin is on the floor in the center 
//           units are given in centimeters with 2000 cm in each dimension 
//           w/l: [-1000, 1000] h: [0, 2000]
//   ROOM:   2D cartesian coordinate system
//           origin is upper/left coordinate of the camera (one room corner)
//           units given in pixels with 1024 x 768 pixels 
//           w: [0, 1024] h: [0, 768]
//   SOUND:  2D polar coordinate system
//           origin is in the center
//           radius is 1.0 [0.0, 1.0] in 360 degrees
//   AVATAR: 3D cartesian coordinate system
//           origin is the bottom center
//           width/height/depth are 100.0/130.0/20.0 centimeters: 
//           [-50.0, 50.0] / [0.0, 130.0] / [-10.0, 10.0]
//   VEST:   2D cartesian coordinate system with back and front side
//           origin is the bottom center
//           width and height are 52 and 62,5 centimeters: [-25.1, 25.1] and [0, 62.5]

float caveLeft = -1350.0, caveRight = 1350.0, caveBottom = 0.0, caveTop = 2700.0, // cm
      roomWidth = 640.0, roomHeight = 480.0,                                     // px
      soundRadius = 1.0,                                                          // normalized
      avatarLeft = -50.0, avatarRight = 50.0, avatarTop = 130.0,                  // cm
      avatarBack = -10.0, avatarFront = 10.0,                                     // cm
      vestLeft = -25.1, vestRight = 25.1, vestBottom = 0.0, vestTop = 62.5;       // cm

String caveIP = "127.0.0.1";
String localIP = "127.0.0.1";

final int SOUND_LISTENER_PORT = 12344;
final int SOUND_SENDER_PORT = 12345;
final int TRACKING_LISTENER_PORT = 12347;

final int CAVE_SENDER_TCP_PORT = 2377;
final int CAVE_LISTENER_TCP_PORT = 2378;
final int CAVE_SENDER_PORT = 2379;
final int CAVE_LISTENER_PORT = 2380;

final int BLUETOOTH_PORT = 0; // 0: COM1 (Windows) // 1: COM3 (Windows)

int minHearbeat = 50, maxHeartbeat = 100;                            // in beats per minute

int bumpHitLength = 300; // 300 milliseconds

int touchStrength = 30;
int bumpStrength = 50;
int hitStrength = 63;
// ==================================================================================

// sound
final int POSITION = 0;
final int VELOCITY = 1;
final int BUMP = 2;
final int TOUCH = 3;
final int HIT = 4;
final int NUMBER_INTERACTIONS = 5;
float [] volumes = {1.0, 1.0, 1.0, 1.0, 1.0};
SpatialSoundEvent soundEvents[] = new SpatialSoundEvent[NUMBER_INTERACTIONS];
boolean isTouchOn = false, isSystemOn = true /* false // false is defaut, true is for testing only*/;

// OSC communication
OscP5 soundOSC, trackingOSC, caveOSC, caveOSCtcp; 
NetAddress caveNetAddress, soundNetAddress;

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
float centerX = 0.0, centerY = 0.0, 
      roomUserX = 0.0, roomUserY = 0.0, roomUserO = 0.0,
      caveUserX = 0.0, caveUserY = 0.0, caveUserVel = 0.0, 
      caveUserXdefault = 0.0, caveUserYdefault = 0.0,
      maxVelocity = 100.0,
      caveUserSoundDistance = 0.0, caveUserSoundAngle = 0.0;
int lastHearbeat = 0;

int bumpHitBegin = 0;
boolean bumpHitOn = false;

// bluetooth connection
Serial bluetooth;
int baudRate = 57600;
int maxMotor = 15;
int maxStrength = 63;

void setup() {
  setupOscListeners();
  setupOscSenders();
  setupSerial();
  setupSounds();
}

void draw() {
  triggerHeartbeat();
}

void setupOscListeners() {
  soundOSC = new OscP5(this, SOUND_LISTENER_PORT);
  trackingOSC = new OscP5(this, TRACKING_LISTENER_PORT);
  caveOSC = new OscP5(this, CAVE_LISTENER_PORT);                 
  caveOSCtcp = new OscP5(caveIP, CAVE_LISTENER_TCP_PORT, OscP5.TCP);
  
  // need to plug TCP methods since oscEvent can not mix UDP with TCP
  trackingOSC.plug(this, "tracking", trackingPattern);
  
  caveOSCtcp.plug(this, "touch", caveUserTouchPattern);  
  caveOSCtcp.plug(this, "hit", caveUserHitPattern);  
  caveOSCtcp.plug(this, "bump", caveUserBumpPattern);
  
  caveOSC.plug(this, "activity", caveUserActivityPattern);
  caveOSC.plug(this, "position", caveUserPositionPattern);
  caveOSC.plug(this, "velocity", caveUserVelocityPattern);
  caveOSC.plug(this, "touching", caveUserTouchingPattern);
}

void setupOscSenders() {
  caveNetAddress = new NetAddress(caveIP, CAVE_SENDER_PORT);
  soundNetAddress = new NetAddress(localIP, SOUND_SENDER_PORT);
}

void setupSerial() {
  for (int i = 0; i < Serial.list().length; ++i)
    println(Serial.list()[i]);
  String portName = Serial.list()[BLUETOOTH_PORT];  
  bluetooth = new Serial(this, portName, baudRate);
}

void setupSounds() {
  for (int i = 0; i < NUMBER_INTERACTIONS; ++i) {
    soundEvents[i] = new SpatialSoundEvent(i);
    soundEvents[i].setVolume(volumes[i]);
    // turn looped sounds on later: when activity message is received
    if (i == POSITION) {
      soundEvents[i].setIsLooped(true);
      if (isSystemOn) {
        soundEvents[i].setIsOn(true);      
        // send to sound system (caveuser)
        updateSoundPosition(POSITION, caveUserXdefault, caveUserYdefault);
      } else
        soundEvents[i].setIsOn(false);
    } else if (i == TOUCH) {
      soundEvents[i].setIsLooped(true);
      soundEvents[i].setIsOn(false);
    }
  }
}

// *** receive CAVE person activity ****************************************************************
//     to start / stop the system 
void activity(int onState) {
  if (DEBUG) 
    println("-> RECEIVED " + caveUserActivityPattern + " i - " + onState);
  
  if (onState == 1) {                                // turn system and looped sounds on
    isSystemOn = true;
    for (int i = 0; i < NUMBER_INTERACTIONS; ++i) {
      if (soundEvents[i].isLooped()) {
        soundEvents[i].setIsOn(true);
        // send to sound system (caveuser)
        updateSoundPosition(POSITION, caveUserXdefault, caveUserYdefault);
      }
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

// *** receive tracking position and orientation *************************************************
//     forward them to the CAVE in appropriate dimensions
//     store them for later calculations
void tracking(float roomUserX, float roomUserY, float roomUserO) {
  if (isSystemOn) {
    if (DEBUG)
      println("-> RECEIVED " + trackingPattern + " fff - " + roomUserX + " " + roomUserY + " " + roomUserO);

    // send position to CAVE
    OscMessage positionToCave = new OscMessage(roomPersonPositionPattern);
    positionToCave.add(map(roomUserX, 0.0, roomWidth, caveLeft, caveRight));
    positionToCave.add(map(roomUserY, 0.0, roomHeight, caveLeft, caveRight));
    caveOSC.send(positionToCave, caveNetAddress);
    
    // send orientation to CAVE
    OscMessage orientationToCave = new OscMessage(roomPersonOrientationPattern);
    orientationToCave.add(roomUserO);
    caveOSC.send(orientationToCave, caveNetAddress); 
  }
}

// *** receive CAVE touch event ******************************************************************
//     this is a on/off message to start the touch and end it
//     enable/disable the touch sound 
void touch(int touchOn) {  
  if (isSystemOn) {
    if (DEBUG)
      println("-> RECEIVED " + caveUserTouchPattern + " i - " + touchOn);
      
    // send to sound system -> turn sound (touch) on / off    
    if (touchOn == 1) {
      isTouchOn = true;
      soundEvents[TOUCH].setIsOn(true);
    } else if (touchOn == 0) {
      isTouchOn = false;
      soundEvents[TOUCH].setIsOn(false);
      sendSoundEventOff(TOUCH);
      sendResetToHapticVest();
    }
  }
}

// *** receive CAVE hit positions **************************************************************
//     activate the motors next to the hit positions
//     trigger the hit sound
void hit(float hitX, float hitY, float hitZ) {
  if (isSystemOn) {
    if (DEBUG)
      println("-> RECEIVED " + caveUserHitPattern + " fff - " + hitX + " " + hitY + " " + hitZ);
        
    // new hit event received -> activate motors and sound
    if (newBumpHitEvent()) {    
      // send hit coordinates to vest -> map to motors       
      sendResetToHapticVest();
      sendToHapticVest(getBumpHitMotorId(hitX, hitY, hitZ), hitStrength); 
        
      // send hit event to the sound system
      updateSoundPosition(HIT, hitX, hitY);
    } 
    
    // turn off motors
    else
      continueBumpHitEvent();
  }
}

// *** receive CAVE bump positions **************************************************************
//     activate some motors for a certain period of time to make the bump a haptic experience
//     trigger the bump sound
void bump(float bumpX, float bumpY) {
  if (isSystemOn) {
    if (DEBUG)
      println("-> RECEIVED " + caveUserBumpPattern + " ff - " + bumpX + " " + bumpY);
          
    // new bump event received -> activate motors and sound
    if (newBumpHitEvent()) {      
      // send bump to vest       
      float x = map(bumpX, avatarLeft, avatarRight, vestLeft, vestRight);
      float y = map(bumpY, 0.0, avatarTop, 0.0, vestTop);
      if (x < vestLeft / 3.0 * 2.0) {        // left bump
        sendToHapticVest( 5, bumpStrength);
        sendToHapticVest( 6, bumpStrength);
        sendToHapticVest( 9, bumpStrength);
        sendToHapticVest(10, bumpStrength);
      } else if (x > vestRight / 3.0 ) {      // right bump
        sendToHapticVest( 0, bumpStrength);
        sendToHapticVest( 7, bumpStrength);
        sendToHapticVest( 8, bumpStrength);
        sendToHapticVest(11, bumpStrength);
      } else {                   // center bump
        sendToHapticVest(12, bumpStrength);
        sendToHapticVest(13, bumpStrength);
        sendToHapticVest(14, bumpStrength);
        sendToHapticVest(15, bumpStrength);
      }
      // send bump event to the sound system
      updateSoundPosition(BUMP, bumpX, bumpY);
                                
    // turn off motors
    } else
      continueBumpHitEvent();
  }
}

// *** receive CAVE position  ********************************************************************
//     forward the position to the sound system
//     store them for later calculations
void position(float caveUserX, float caveUserY) {
  if (isSystemOn) {
    if (DEBUG)
      println("-> RECEIVED " + caveUserPositionPattern + " ff - " + caveUserX + " " + caveUserY);
          
    // send to sound system (caveuser)
    updateSoundPosition(POSITION, caveUserX, caveUserY);
  }
}

// *** receive CAVE velocity *********************************************************************
//     use the velocity to change the heartbeat sound trigger speed
void velocity(float velocity) {
  if (isSystemOn) {
    if (DEBUG)
      println("-> RECEIVED " + caveUserVelocityPattern + " f - " + velocity);
  
    caveUserVel = velocity;
  }
}

// *** receive CAVE touch positions **************************************************************
//     map the touch positions to vest positions and activate/deactivate the motors accordingly
void touching(float touchX, float touchY, float touchZ) {
  if (isSystemOn && isTouchOn) {
    if (DEBUG)
      println("-> RECEIVED " + caveUserTouchingPattern + " fff - " + touchX + " " + touchY + " " + touchZ);
          
    //       L           BACK          R
    //       <---------- 52cm --------->
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
  
    //        R         FRONT         L
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
    
      
    // send touch coordinates to vest -> map to motors
    sendResetToHapticVest();
    sendToHapticVest(getBumpHitMotorId(touchX, touchY, touchZ), touchStrength); 

    // send touch position (x,y) to sound system
    updateSoundPosition(TOUCH, touchX, touchY);
  }
}

// send motor control messages
void sendToHapticVest(int motor, int strength) {
  if (motor < maxMotor && strength < maxStrength) {
    char motorFlag = char(65 + motor);
    char strengthFlag = char(48 + strength); 
    String command = "p" + motorFlag + strengthFlag + "\n";    // TODO: add explicit LR or CF if necessary - first test with haptic vest
    if (DEBUG)
      println("Sending command " + command);
    bluetooth.write(command);
  }
}

// send reset motor control message
void sendResetToHapticVest() {
  String command = "r"; 
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
      print("<- SENDING " + message.addrPattern());
      print(" " + message.typetag() + " - " + soundEvents[interaction].getVolume() + " ");
      println(soundEvents[interaction].getDistance() +  " " + soundEvents[interaction].getAngle());
    }
    soundOSC.send(message, soundNetAddress);
}

// send sound event off to sound system
void sendSoundEventOff(int interaction) {
    OscMessage message = new OscMessage(soundPattern + "/" + soundEvents[interaction].getNumber());
    message.add(0.0);
    message.add(0.0);
    message.add(0.0);
    if (DEBUG) {
      print("<- SENDING " + message.addrPattern());
      print(" " + message.typetag() + " - 0.0 0.0 0.0");
    }
    soundOSC.send(message, soundNetAddress);
}
                                
void updateSoundPosition(int interaction, float cux, float cuy) {
  float x = map(cux, caveLeft, caveRight, -1.0, 1.0);
  float y = map(cuy, caveLeft, caveRight, -1.0, 1.0);
  caveUserSoundDistance = dist(centerX, centerY, x, y);
  caveUserSoundAngle = getAngle(centerX, centerY, x, y); 
  sendSoundChangeEvent(interaction, caveUserSoundDistance, caveUserSoundAngle);
}

int getBumpHitMotorId(float vx, float vy, float vz) {
  
  float vestWidth = vestRight * 2.0;
  float x = map(vx, avatarLeft, avatarRight, 0.0, vestWidth);
  float y = map(vy, 0.0, avatarTop, 0.0, vestTop);
  
  if (y > vestTop / 3.0 * 2.0) {        // touch at the upper region -> use horizontal motors 0-5 and 12
    int numOfMotors = 7;
    if (x < vestWidth / float(numOfMotors))
      return 0;         // very left
    else if (x < vestWidth / float(numOfMotors) * 2.0)
      return 1;  
    else if (x < vestWidth / float(numOfMotors) * 3.0)
      return 2;       
    else if (x < vestWidth / float(numOfMotors) * 4.0)
      return 12;
    else if (x < vestWidth / float(numOfMotors) * 5.0)
      return 3;  
    else if (x < vestWidth / 7.0 * 6.0)
      return 4;
    else
      return 5;
  } else {
    int numOfMotors = 4;
    if (y < vestTop / float(numOfMotors))
      return 12;
    else if (y < vestTop / float(numOfMotors) * 2.0)
      return 13;  
    else if (y < vestTop / float(numOfMotors) * 3.0)
      return 14;       
    else
      return 15;
  }
}

// start a new bump/hit if it is not on
boolean newBumpHitEvent() {
  if (!bumpHitOn) {
    bumpHitBegin = millis();
    bumpHitOn = true;
    return true;
  }
  return false;
}

// continue bump/hit vibrations until  bumpHitLength ms
void continueBumpHitEvent() {
    if (millis() - bumpHitBegin > bumpHitLength) {    
      sendResetToHapticVest();
      bumpHitOn = false;
      bumpHitBegin = 0;    
    }
}

void triggerHeartbeat() {
  int now = millis();
  int heartbeat = int(map(abs(caveUserVel), 0.0, maxVelocity, minHearbeat, maxHeartbeat));
  if (float(now - lastHearbeat) > 1.0 / float(heartbeat) * 60000) {
    updateSoundPosition(VELOCITY, caveUserSoundDistance, caveUserSoundAngle);
    lastHearbeat = now;
  } 
}

float getAngle(float x1, float y1, float x2, float y2) {
  return 180.0 + atan2((y1 - y2), (x1 - x2)) * 180.0 / PI;
} 



