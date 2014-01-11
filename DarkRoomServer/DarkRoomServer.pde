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

// CONFIGURATION
// ==================================================================================
// generate debug output: write it to a file or to the console
final boolean DEBUG = false;
final boolean WRITE_TO_FILE = false;
// turn heartbeat off for testing other sounds better
final boolean HEARTBEAT_OFF = false;
// receive orientation from vest or via OSC (smartphone)
final boolean ORIENTATION_FROM_VEST = false;  
// test without the vest turns all bluetooth communication off (no InvocationTargetException for OSC TCP)
final boolean TEST_WITHOUT_VEST = true;  

// run the test for the vest motors - turn off by default
final boolean TEST_VEST = true;

// use false here if the activity on/off event is sent by the CAVE
boolean isSystemOn = false; 

// set IP for the CAVE
String caveIP = "0.0.0.0"; /*"127.0.0.1"; "10.156.309.151";*/
String localIP = "127.0.0.1";

// in- and outbound ports for all TCP and UDP messages
final int SOUND_LISTENER_PORT = 12344;                  // local
final int SOUND_SENDER_PORT = 12345;                    // local
final int TRACKING_LISTENER_PORT = 12347;               // local
final int ORIENTATION_TRACKING_LISTENER_PORT = 12350;   // local

final int CAVE_LISTENER_TCP_PORT = 23781;                // TCP listener

// OSC message patterns
final String soundPattern = "/SonicCave";                                  // UDP
final String trackingPattern = "/tracking";                                // UDP
final String orientationTrackingPattern = "/ori";                          // UDP
final String caveUserActivityPattern = "/cave_person/activity";            // TCP
final String caveUserPositionPattern = "/cave_person/position";            // UDP
final String caveUserVelocityPattern = "/cave_person/velocity";            // UDP
final String caveUserTouchPattern = "/cave_person/touch";                  // TCP
final String caveUserTouchingPattern = "/cave_person/touching";            // UDP
final String caveUserHitPattern = "/cave_person/hit";                      // TCP
final String caveUserBumpPattern = "/cave_person/bump";                    // TCP
final String roomPersonPositionPattern = "/room_person/position";          // UDP
final String roomPersonOrientationPattern = "/room_person/orientation";    // UDP
final String roomPersonPattern = "/room_person";                           // TCP  combines position and orientation

// bluetooth port
final int BLUETOOTH_PORT = 1;               // 0: COM1 (Windows) // 1: COM3 (Windows)
int baudRate = 57600;
// asciiOffsetO is the offset for the orientation flag, acsiiOffsetA is the offset for the motor flag
int maxMotor = 16, maxStrength = 64, asciiOffset0 = 48, asciiOffsetA = 65;
char orientPatt = 'h';

// COORDINATE SYSTEMS:
//   CAVE:   3D right-handed cartesian coordinate system
//           X: left to right axis; Y: bottom to top; 
//           Z: towards the screen
//           origin is on the floor in the center 
//           units are given in centimeters with 2000 cm in each dimension 
//           w/l: [-1000, 1000] h: [0, 2000]
//   ROOM:   2D cartesian coordinate system
//           origin is front center
//           units given in cm with 300 cm in each dimension 
//           w: [1500, -1500] d: [0, 3000]
//   SOUND:  2D polar coordinate system
//           origin is in the center
//           radius is 1.0 [0.0, 1.0] in 360 degrees
//   AVATAR: 3D cartesian coordinate system -> not used so far 
//           origin is the hip center (bottom of vest)
//           width/height/depth are 60.0/170.0/20.0 centimeters: 
//           [left, right] / [bottom, top] / [back, front]
//           [-30.0, 30.0] / [-90.0, 80.0] / [-10.0, 10.0]
//   VEST:   3D cartesian coordinate system 
//           origin is the bottom center
//           [left, right] / [bottom, top] / [back, front] 
//           width/height/depth are 52.0/62.5/20.0 centimeters: 
//           [-26.0, 26.0] / [0.0, 62.5]   / [-10.0, 10.0]

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

float caveLeft = -1000.0, caveRight = 1000.0, caveFront = -1000.0, 
      caveBack = 1000.0, caveBottom = 0.0, caveTop = 2000.0,                      // cm
      roomLeft = 1500.0, roomRight = -1500.0,                                     // looking from back to front, right is negative
      roomFront = 0.0, roomBack = 3000.0,                                         // cm
      vestLeft = -26.0, vestRight = 26.0, vestBottom = 0.0, vestTop = 62.5,           
      vestBack = -10.0, vestFront = 10.0;                                         // cm
      
float[] roomUser = new float[3];
final int X = 0;
final int Y = 1;
final int O = 2;

// timer for sending to CAVE every 100 ms (10x per second)
int timestamp = 0, timeout = 100;

int testTimestamp = 0, testTimeout = 3000;
int testTimestampOff = 0, testTimeoutOff = 1000;

// vest motor coordinates relative to the bottom center point of the vest (origin of the vest and the avatar)
PVector[] motorCoordinates = {
  // FRONT   (     X,      Y,      Z)
  new PVector( 18.0f,  10.0f,  62.5f),        // 1:  shoulder outer right
  new PVector( 14.5f,  10.0f,  62.5f),        // 2:  shoulder center right
  new PVector( 11.0f,  10.0f,  62.5f),        // 3:  shoulder inner right
  new PVector(-11.0f,  10.0f,  62.5f),        // 4:  shoulder inner left
  new PVector(-14.5f,  10.0f,  62.5f),        // 5:  shoulder center left
  new PVector(-18.0f,  10.0f,  62.5f),        // 6:  shoulder outer left
  new PVector(-19.0f,  10.0f,  28.0f),        // 7:  arm left
  new PVector( 19.0f,  10.0f,  28.0f),        // 8:  arm right
  new PVector( 16.0f,  10.0f,  16.0f),        // 9:  hip right
  new PVector(-16.0f,  10.0f,  16.0f),        // 10: hip left
  // BACK   (     X,       Y,      Z)
  new PVector(-15.0f, -10.0f,  52.5f),        // 11:  shoulder left
  new PVector( 15.0f, -10.0f,  52.5f),        // 12:  shoulder right
  new PVector(  0.0f, -10.0f,  45.5f),        // 13:  spine top
  new PVector(  0.0f, -10.0f,  38.5f),        // 14:  spine almost top
  new PVector(  0.0f, -10.0f,  31.5f),        // 15:  spine almost bottom
  new PVector(  0.0f, -10.0f,  24.5f)         // 16:  spine bottom
};

// motor strength for touch/hit/bump
int touchStrength = 30;

// on bump: motors with first two id are activated with strength 55 for 120 ms, 
//          then the next two motors are activated with strength 22 for 90 ms,
//          then the next two motors are activated with strength 8 for 50 ms,
int[] bumpStrengths = {55, 22, 8};
int[] bumpDurations = {120, 90, 50};    // in ms
int[][] bumpPatterns = {
  {8, 9, 1, 12, 2, 3},       // bump left
  {7, 10, 6, 11, 4, 5},      // bump right
  {13, 14, 14, 15, 15, 16},  // bump back
  {3, 4, 2, 5, 1, 6}};       // bump front

// on hit: motor with id is activated with strength 63 for 100 ms, 
//         then three surrounding motors with strength 15 each are activated for 60 ms
int[] hitStrengths = {63, 15};
int[] hitDurations = {100, 60};          // in ms
int[][] hitPatterns = {
  {2, 3, 12},                // motor id 1
  {1, 2, 12},                // motor id 2
  {1, 2, 12},                // motor id 3
  {5, 6, 11},                // motor id 4
  {4, 5, 11},                // motor id 5
  {10, 14, 15},              // motor id 6
  {9, 14, 15},               // motor id 7
  {8, 14, 15},               // motor id 8
  {7, 14, 15},               // motor id 9
  {4, 5, 6},                 // motor id 10
  {1, 2, 3},                 // motor id 11
  {11, 12, 14},              // motor id 12
  {13, 15, 16},              // motor id 13
  {14, 15, 16},              // motor id 14
  {13, 14, 15}};             // motor id 15

// heartbeat range for slow and fast movement
int minHearbeat = 50, maxHeartbeat = 100;   // in beats per minute
// ==================================================================================

// GLOBAL VARIABLES - DO NOT CHANGE!
// ==================================================================================
// sound
final int POSITION = 0;
final int VELOCITY = 1;
final int BUMP = 2;
final int TOUCH = 3;
final int HIT = 4;
final int NUMBER_INTERACTIONS = 5;
float [] volumes = {1.0, 1.0, 0.4, 1.0, 0.4};
SpatialSoundEvent soundEvents[] = new SpatialSoundEvent[NUMBER_INTERACTIONS];
boolean isTouchOn = false;

// OSC communication
OscP5 soundOSC, trackingOSC, orientationTrackingOSC, caveOSCtcp; 
NetAddress soundNetAddress;
PrintWriter output;

float centerX = 0.0, centerY = 0.0, 
      roomUserX = 0.0, roomUserY = 0.0, roomUserO = 0.0,
      caveUserX = 0.0, caveUserY = 0.0, caveUserVel = 0.0, 
      caveUserXdefault = 0.0, caveUserYdefault = 0.0,
      maxVelocity = 100.0,
      caveUserSoundDistance = 0.0, caveUserSoundAngle = 0.0;
int lastHearbeat = 0;

int bumpBegin = 0, hitBegin = 0, bumpArea = 0, hitIdx = 0;
boolean bumpOn = false, hitOn = false;

// bluetooth connection
Serial bluetooth;
// ==================================================================================

void setup() {
  setupWriter();  
  setupOscListeners();
  setupOscSenders();
  setupSerial();
  setupSounds();
  
  testHitBumpTouch();
    
  timestamp = millis();
}

// main loop
void draw() {
  // receive bluetooth orientation messages from the haptic vest 
  //if (ORIENTATION_FROM_VEST && !TEST_WITHOUT_VEST)
  //  receiveFromHapticVest();  
  // using serialEvent callback instead
  
  // send room user data to the cave
  sendRoomUserDataToCave();
    
  // re-trigger heartbeat sound
  if (!HEARTBEAT_OFF)
    triggerHeartbeat();
  
  // update active bump or hit motor animation patterns
  if (bumpOn)
    updateBump();
  if (hitOn)
    updateHit();
  
  // debug to file
  if (WRITE_TO_FILE)
    output.flush();
}

void keyPressed() {
  if (key == ESC && WRITE_TO_FILE) {
    output.flush();
    output.close();
  }
}

void setupWriter() {
 if (WRITE_TO_FILE) 
    output = createWriter("VrOSCmessages.txt");
}

void setupOscListeners() {
  soundOSC = new OscP5(this, SOUND_LISTENER_PORT);
  trackingOSC = new OscP5(this, TRACKING_LISTENER_PORT);             
  caveOSCtcp = new OscP5(this, CAVE_LISTENER_TCP_PORT, OscP5.TCP);
    
  if (!ORIENTATION_FROM_VEST) {  // vest sends via bluetooth, phone via OSC
    orientationTrackingOSC = new OscP5(this, ORIENTATION_TRACKING_LISTENER_PORT);
    orientationTrackingOSC.plug(this, "trackingOrientation", orientationTrackingPattern);
  }
  
  // need to plug TCP methods since oscEvent can not mix UDP with TCP
  // trackingOSC.plug(this, "tracking", trackingPattern); // old tracking including position and orientation
  trackingOSC.plug(this, "trackingPosition", trackingPattern);
  
  caveOSCtcp.plug(this, "touch", caveUserTouchPattern);  
  caveOSCtcp.plug(this, "hit", caveUserHitPattern);
  caveOSCtcp.plug(this, "bump", caveUserBumpPattern);
  caveOSCtcp.plug(this, "activity", caveUserActivityPattern);
  caveOSCtcp.plug(this, "position", caveUserPositionPattern);
  caveOSCtcp.plug(this, "velocity", caveUserVelocityPattern);
  caveOSCtcp.plug(this, "touching", caveUserTouchingPattern);
}

void setupOscSenders() {
  soundNetAddress = new NetAddress(localIP, SOUND_SENDER_PORT);
}

void setupSerial() {
  if (!TEST_WITHOUT_VEST) {
    for (int i = 0; i < Serial.list().length; ++i) 
      printStr(Serial.list()[i]);
      
    String portName = Serial.list()[BLUETOOTH_PORT];  
    bluetooth = new Serial(this, portName, baudRate);
  }
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
  debugStr("-> RECEIVED " + caveUserActivityPattern + " i - " + onState);
  
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

// *** receive room person tracking position and orientation **************************************
//     forward them to the CAVE in appropriate dimensions
//     store them for later calculations
void tracking(float roomUserX, float roomUserY, float roomUserO) {
  if (isSystemOn) {
    if (DEBUG)
      debugStr("-> RECEIVED " + trackingPattern + " fff - " + roomUserX + " " + roomUserY + " " + roomUserO);

    // send position to CAVE
    OscMessage message = new OscMessage(roomPersonPositionPattern);
    message.add(map(roomUserX, roomLeft, roomRight, caveLeft, caveRight));
    message.add(map(roomUserY, roomFront, roomBack, caveFront, caveBack));
    caveOSCtcp.send(message, message.tcpConnection());
    debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + " " +
             map(roomUserX, roomLeft, roomRight, caveLeft, caveRight) + " " +
             map(roomUserY, roomFront, roomBack, caveFront, caveBack));
    
    // send orientation to CAVE
    message = new OscMessage(roomPersonOrientationPattern);
    message.add(roomUserO);
    caveOSCtcp.send(message, message.tcpConnection()); 
    debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + roomUserO);
  }
}

// *** receive tracking orientation ************************************************************
//     forward it to the CAVE 
//     store them for later calculations
void trackingOrientation(int roomUserYaw, int roomUserRoll, int roomUserPitch) {
  if (isSystemOn) {
    debugStr("-> RECEIVED " + orientationTrackingPattern + " iii - " + roomUserYaw + 
             " " + roomUserRoll + " " + roomUserPitch);
    
    // no longer sending immediately, but storing for later sending
    roomUser[O] = float(roomUserYaw); 
  }
}

// *** receive tracking position ****************************************************************
//     forward them to the CAVE in appropriate dimensions
//     store them for later calculations
void trackingPosition(float roomUserX, float roomUserY) {
  if (isSystemOn) {
    debugStr("-> RECEIVED " + trackingPattern + " ff - " + roomUserX + " " + roomUserY);

    // no longer sending immediately, but storing for later sending
    roomUser[X] = roomUserX; 
    roomUser[Y] = roomUserY; 
  }
}

// *** send position and orientation to the CAVE *************************************************
//     send each n(timeout) ms 
void sendRoomUserDataToCave() {
  if (isSystemOn) {
    if ((millis() - timestamp) >= timeout) {
      OscMessage message = new OscMessage(roomPersonPattern);
      message.add(map(roomUser[X], roomLeft, roomRight, caveLeft, caveRight));
      message.add(map(roomUser[Y], roomFront, roomBack, caveFront, caveBack));
      message.add(roomUser[O]);
      caveOSCtcp.send(message, message.tcpConnection());
      
      debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + " " +
               map(roomUser[X], roomLeft, roomRight, caveLeft, caveRight) + " " +
               map(roomUser[Y], roomFront, roomBack, caveFront, caveBack) + " " + roomUser[O]);
               
      timestamp = millis();
    } 
  }
}

// *** receive CAVE position  ********************************************************************
//     forward the position to the sound system
//     store them for later calculations
void position(float caveUserX, float caveUserY) {
  if (isSystemOn) {
    debugStr("-> RECEIVED " + caveUserPositionPattern + " ff - " + caveUserX + " " + caveUserY);
          
    // send to sound system (caveuser)
    updateSoundPosition(POSITION, caveUserX, caveUserY);
  }
}

// *** receive CAVE velocity *********************************************************************
//     use the velocity to change the heartbeat sound trigger speed
void velocity(float velocity) {
  if (isSystemOn) {
    debugStr("-> RECEIVED " + caveUserVelocityPattern + " f - " + velocity);
  
    caveUserVel = velocity;
  }
}

// *** receive CAVE touch event ******************************************************************
//     this is a on/off message to start the touch and end it
//     enable/disable the touch sound 
void touch(int touchOn) {  
  if (isSystemOn) {
    debugStr("-> RECEIVED " + caveUserTouchPattern + " i - " + touchOn);
      
    // send to sound system -> turn sound (touch) on / off    
    if (touchOn == 1) {
      isTouchOn = true;
      soundEvents[TOUCH].setIsOn(true);
      sendSoundChangeEvent(TOUCH, 0.0f, 0.0f);    // play sound from center - loudest 
    } else if (touchOn == 0) {
      isTouchOn = false;
      soundEvents[TOUCH].setIsOn(false);
      sendSoundEventOff(TOUCH);
      sendResetToHapticVest();
    }
  }
}

// *** receive CAVE touch positions **************************************************************
//     map the touch positions to vest positions and activate/deactivate the motors accordingly
void touching(float touchX, float touchY, float touchZ) {
  if (isSystemOn && isTouchOn) {
    debugStr("-> RECEIVED " + caveUserTouchingPattern + " fff - " + touchX + " " + touchY + " " + touchZ);
                
    // send touch coordinates to vest -> map to motors
    sendResetToHapticVest();
    sendToHapticVest(getNearestMotorID(touchX, touchY, touchZ), touchStrength); 
  }
}

// *** receive CAVE hit positions **************************************************************
//     activate the motors next to the hit positions
//     trigger the hit sound
void hit(float hitX, float hitY, float hitZ) { 
  // new hit event received
  if (isSystemOn && !hitOn) {
    debugStr("-> RECEIVED " + caveUserHitPattern + " fff - " + hitX + " " + hitY + " " + hitZ);
        
    // start a new hit event
    hitBegin = millis(); 
    hitOn = true;
    
    // calculate area of bump (left / right / back / front)  
    hitIdx = getNearestMotorID(hitX, hitY, hitZ) - 1;
    
    // activate motors
    triggerHit(0);
       
    // send hit event to the sound system
    sendSoundChangeEvent(HIT, 0.0f, 0.0f);    // play sound from center - loudest     
  }
}

void testHitBumpTouch() {
  println("testHitBumpTouch");
  
  println(" 1) test if the motor coordinate position is correctly found for the actual distance");
  for (int i = 0; i < motorCoordinates.length; ++i)
    println(getNearestMotorID(motorCoordinates[i].x, motorCoordinates[i].y, motorCoordinates[i].z));
    
}

// trigger new hit
void triggerHit(int n) {
  sendResetToHapticVest();  
  sendToHapticVest(hitPatterns[hitIdx][n + 0], hitStrengths[n]);
  sendToHapticVest(hitPatterns[hitIdx][n + 1], hitStrengths[n]);
  sendToHapticVest(hitPatterns[hitIdx][n + 2], hitStrengths[n]);
}

// update hit animation
void updateHit() {
  int now = millis();
  if (now - hitBegin > hitDurations[0] + hitDurations[1]) {    
    sendResetToHapticVest();  
    hitOn = false;
  } else if (now - hitBegin > hitDurations[0]) {
    triggerHit(1);
  }  
}

// *** receive CAVE bump positions **************************************************************
//     activate some motors for a certain period of time to make the bump a haptic experience
//     trigger the bump sound
void bump(float bumpX, float bumpY) {  
  // new bump event received
  if (isSystemOn && !bumpOn) {
    debugStr("-> RECEIVED " + caveUserBumpPattern + " ff - " + bumpX + " " + bumpY);    
  
    // start a new bump event
    bumpBegin = millis(); 
    bumpOn = true;
    
    // calculate area of bump (left / right / back / front)    
    if (bumpX < vestLeft / 3.0 * 2.0)      // left bump
      bumpArea = 0;
    else if (bumpX > vestRight / 3.0 )     // right bump
      bumpArea = 1;
    else if (bumpY < 0.0)                  // back bump
      bumpArea = 2;
    else if (bumpY <= 0.0)                 // front bump
      bumpArea = 3;
    
    // activate motors
    triggerBump(0);
    
    // send bump event to the sound system
    sendSoundChangeEvent(BUMP, 0.0f, 0.0f);    // play sound from center - loudest       
  }
}

// trigger new bump
void triggerBump(int n) {    
  sendResetToHapticVest();  
  sendToHapticVest(bumpPatterns[bumpArea][2 * n + 0], bumpStrengths[n]);
  sendToHapticVest(bumpPatterns[bumpArea][2 * n + 1], bumpStrengths[n]);
}

// animate bump animation
void updateBump() {
  int now = millis();
  if (now - bumpBegin > bumpDurations[0] + bumpDurations[1] + bumpDurations[2]) {  
    sendResetToHapticVest();  
    bumpOn = false;
  } else if (now - bumpBegin > bumpDurations[0] + bumpDurations[1]) {    
    triggerBump(2);
  } else if (now - bumpBegin > bumpDurations[0]) {
    triggerBump(1);
  }  
}

// *** returns the motor id of the motor nearest to x/y/z  ***************************************
int getNearestMotorID(float x, float y, float z) {
  float curDist = 0.0f;
  float minDist = dist(x, y, z, motorCoordinates[0].x, motorCoordinates[0].y, motorCoordinates[0].z);
  int id = 0;
  for (int i = 1; i < motorCoordinates.length; ++i) {
    curDist = dist(x, y, z, motorCoordinates[i].x, motorCoordinates[i].y, motorCoordinates[i].z);
    if (curDist < minDist) {
      minDist = curDist;
      id = i;  
    }
  } 
  return id;
}

// receive orientation values from the compass on the haptic vest
// "hXXX" with XXX is the degree in 10th degrees
void serialEvent(Serial p) {
  String[] cmd = p.readString().split("\n");
  if (cmd.length > 0 && cmd[0].length() > 1 && cmd[0].charAt(cmd[0].length() - 1) == '\r') {
    String command = cmd[0].trim(); 
    debugStr("-> RECEIVED FROM SERIAL: " + cmd);
    if (command.charAt(0) == orientPatt) {
      float o = float(Integer.parseInt(command.substring(1))) / 10.0f;
      debugStr("  - received orientation " + o);
      roomUser[O] = o;
    }
  }
}

// send motor control messages
void sendToHapticVest(int motor, int strength) {
  if (!TEST_WITHOUT_VEST) {
    if (motor < maxMotor && strength < maxStrength) {
      char motorFlag = char(asciiOffsetA + motor);
      char strengthFlag = char(asciiOffset0 + strength); 
      String command = "p" + motorFlag + strengthFlag + "\n";
      debugStr("Sending command " + command);
      bluetooth.write(command);
    }
  }
}

// send reset motor control message
void sendResetToHapticVest() {
  if (!TEST_WITHOUT_VEST) {
    String command = "r" + "\n"; 
    debugStr("Sending command " + command);
    bluetooth.write(command);
  }
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
    soundOSC.send(message, soundNetAddress);
    debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + 
          " - " + soundEvents[interaction].getVolume() + " " + 
          soundEvents[interaction].getDistance() +  " " + soundEvents[interaction].getAngle());
}

// send sound event off to sound system
void sendSoundEventOff(int interaction) {
    OscMessage message = new OscMessage(soundPattern + "/" + soundEvents[interaction].getNumber());
    message.add(0.0);
    message.add(0.0);
    message.add(0.0);
    soundOSC.send(message, soundNetAddress);
    debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + " - 0.0 0.0 0.0");
}
                                
void updateSoundPosition(int interaction, float cux, float cuy) {
  float x = map(cux, caveLeft, caveRight, -1.0, 1.0);
  float y = map(cuy, caveFront, caveBack, -1.0, 1.0);
  caveUserSoundDistance = dist(centerX, centerY, x, y);
  caveUserSoundAngle = getAngle(centerX, centerY, x, y); 
  sendSoundChangeEvent(interaction, caveUserSoundDistance, caveUserSoundAngle);
}

void triggerHeartbeat() {
  int now = millis();
  int heartbeat = int(map(abs(caveUserVel), 0.0, maxVelocity, minHearbeat, maxHeartbeat));
  if (float(now - lastHearbeat) > 1.0 / float(heartbeat) * 60000) {
    sendSoundChangeEvent(VELOCITY, caveUserSoundDistance, caveUserSoundAngle);
    lastHearbeat = now;
  } 
}

float getAngle(float x1, float y1, float x2, float y2) {
  return 180.0 + atan2((y1 - y2), (x1 - x2)) * 180.0 / PI;
} 

void debugStr(String dStr) {
  if (DEBUG) 
    printStr(dStr);
}

void printStr(String pStr) {
    if (WRITE_TO_FILE)
      output.println(pStr);
    else
      println(pStr);
}


