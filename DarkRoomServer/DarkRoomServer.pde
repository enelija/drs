/* *************************************************************************************************
    DarkRoomServer by ivan & enelija
      
      to use with the local audio system
                  the local tracking system
                  the via Bluetooth connected haptic vest
                  the remotely connected CAVE
   ********************************************************************************************** */


// *** import libraries ****************************************************************************
import oscP5.*;
import netP5.*;

// *** global variables - do not change! ***********************************************************
Vest vest;

float[] roomUser = new float[3];
final int X = 0;
final int Y = 1;
final int O = 2;

// sound
final int POSITION = 0;
final int VELOCITY = 1;
final int BUMP = 2;
final int TOUCH = 3;
final int HIT = 4;
final int NUMBER_INTERACTIONS = 5;
float [] volumes = {1.0, 1.0, 0.4, 1.0, 0.4};
SpatialSoundEvent soundEvents[] = new SpatialSoundEvent[NUMBER_INTERACTIONS];

OscP5 soundOSCudp, trackingOSCudp, orientTrackingOSCudp, caveOSCtcpIn, caveOSCtcpOut, caveOSCudpIn, caveOSCudpOut; 
NetAddress soundNetAddress, caveNetAddress;

float centerX = 0.0, centerY = 0.0, 
      roomUserX = 0.0, roomUserY = 0.0, roomUserO = 0.0,
      caveUserX = 0.0, caveUserY = 0.0, caveUserVel = 0.0, 
      caveUserXdefault = 0.0, caveUserYdefault = 0.0,
      maxVelocity = 100.0,
      caveUserSoundDistance = 0.0, caveUserSoundAngle = 0.0;
int lastHearbeat = 0,  testTimeStamp = 0, testInterval = 500, testIdCnt = 0;
boolean isClientConnected = false;
boolean sendPosNow = true;

// *************************************************************************************************
void setup() {
  setupWriter(); 
  
  vest = new Vest(this, BLUETOOTH_PORT, baudRate);
  
  setupOsc();
  setupSounds();
  
  timestamp = millis();
}

// *************************************************************************************************
void draw() {  
  if (PREVENT_INITITATE_TCP_CONN)
    checkClients();
  
  if (isSystemOn) {
    if (!SEND_IMMEDIATELY)
      sendRoomUserDataToCave();
      
    if (!HEARTBEAT_OFF)
      triggerHeartbeat();
    
    vest.update();
    
    if (WRITE_TO_FILE)
      output.flush();
  }
}

// *************************************************************************************************
void setupOsc() {         
  trackingOSCudp = new OscP5(this, TRACKING_UDP_IN_PORT);
  
  if (PREVENT_INITITATE_TCP_CONN) {
    debugStr("Creating TCP in and out connection (no initiation)");
    caveOSCtcpIn = new OscP5(this, CAVE_TCP_IN_PORT, OscP5.TCP);          
    caveOSCtcpOut = new OscP5(this, CAVE_TCP_OUT_PORT, OscP5.TCP);
  } else {
    debugStr("Initiating TCP in and out connections to " + caveIP);
    caveOSCtcpIn = new OscP5(caveIP, CAVE_TCP_IN_PORT, OscP5.TCP);          
    caveOSCtcpOut = new OscP5(caveIP, CAVE_TCP_OUT_PORT, OscP5.TCP);
  }
  if (!CAVE_TCP_ONLY) {
    debugStr("Creating UDP in and out connections");
    caveOSCudpIn = new OscP5(this, CAVE_UDP_IN_PORT);       
    caveOSCudpOut = new OscP5(this, CAVE_UDP_OUT_PORT);
  }
  
  // need to plug TCP methods since oscEvent can not mix UDP with TCP
  if (!ORIENTATION_FROM_VEST) {  // vest sends via bluetooth, phone via OSC
    orientTrackingOSCudp = new OscP5(this, ORIENTATION_TRACKING_UDP_IN_PORT);
    orientTrackingOSCudp.plug(this, "trackingOrientation", orientationTrackingPattern);
  }
  
  trackingOSCudp.plug(this, "trackingPosition", trackingPattern);
  
  caveOSCtcpIn.plug(this, "touch", caveUserTouchPattern);  
  caveOSCtcpIn.plug(this, "hit", caveUserHitPattern);
  caveOSCtcpIn.plug(this, "bump", caveUserBumpPattern);
  caveOSCtcpIn.plug(this, "activity", caveUserActivityPattern);
  
  if (CAVE_TCP_ONLY) {
    caveOSCtcpIn.plug(this, "position", caveUserPositionPattern);
    caveOSCtcpIn.plug(this, "velocity", caveUserVelocityPattern);
    caveOSCtcpIn.plug(this, "touching", caveUserTouchingPattern);
  } else {
    caveOSCudpIn.plug(this, "position", caveUserPositionPattern);
    caveOSCudpIn.plug(this, "velocity", caveUserVelocityPattern);
    caveOSCudpIn.plug(this, "touching", caveUserTouchingPattern);
  }
  
  soundOSCudp = new OscP5(this, SOUND_UDP_OUT_PORT);
  soundNetAddress = new NetAddress(localIP, SOUND_UDP_OUT_PORT);
  if (!CAVE_TCP_ONLY)
    caveNetAddress = new NetAddress(caveIP, CAVE_UDP_OUT_PORT);
}

// *************************************************************************************************
void setupSounds() {
  for (int i = 0; i < NUMBER_INTERACTIONS; ++i) {
    soundEvents[i] = new SpatialSoundEvent(i);
    soundEvents[i].volume = volumes[i];
    // turn looped sounds on later: when activity message is received
    if (i == POSITION) {
      soundEvents[i].isLooped = true;
      if (isSystemOn) {
        soundEvents[i].isOn = true;      
        // send to sound system (caveuser)
        updateSoundPosition(POSITION, caveUserXdefault, caveUserYdefault);
      } else
        soundEvents[i].isOn = false;
    } else if (i == TOUCH) {
      soundEvents[i].isLooped = true;
      soundEvents[i].isOn = false;
    }
  }
}

// *** activate system turn looped sounds off ******************************************************
void activateSystem() {
  isSystemOn = true;
  for (int i = 0; i < NUMBER_INTERACTIONS; ++i) {
    if (soundEvents[i].isLooped) {
      soundEvents[i].isOn = true;
      // send to sound system (caveuser)
      updateSoundPosition(POSITION, caveUserXdefault, caveUserYdefault);
    }
  }
}

// *** deactivate system turn looped sounds off ****************************************************
void deactivateSystem() {
  isSystemOn = false;
  for (int i = 0; i < NUMBER_INTERACTIONS; ++i) { 
    if (soundEvents[i].isLooped)
      sendSoundEventOff(i);
  }
}

// *** check whether the client is connected or not ************************************************
//     de-/activate the system accordingly
void checkClients() {
  int numOfConnectedClients = caveOSCtcpIn.tcpServer().getClients().length;
    
  if (isClientConnected && numOfConnectedClients == 0) {
    debugStr("-> CLIENT DISCONNECTED - turning system off");
    
    isClientConnected = false;
    deactivateSystem();
  } else if (!isClientConnected && numOfConnectedClients > 0) {
    debugStr("-> CLIENT CONNECTED - turning system on");
    
    isClientConnected = true;
    activateSystem();
  }
}

// *** if connection is not initiated, activate system on first OSC message ************************
void oscEvent(OscMessage theOscMessage) {
  if (!PREVENT_INITITATE_TCP_CONN && !isSystemOn) {
    activateSystem();
  }
}
  
// *** receive CAVE person activity ****************************************************************
//     to start / stop the system 
void activity(int onState) { 
  debugStr("-> RECEIVED " + caveUserActivityPattern + " i - " + onState);
  
  if (onState == 1) 
    activateSystem();
  else if (onState == 0)
    deactivateSystem();
}

// *** receive room person tracking position and orientation ***************************************
void tracking(float roomUserX, float roomUserY, float roomUserO) {
  if (isSystemOn) {
    debugStr("-> RECEIVED " + trackingPattern + " fff - " + 
             roomUserX + " " + roomUserY + " " + roomUserO);

    roomUser[X] = map(roomUserX, roomLeft, roomRight, roomRight, roomLeft);
    roomUser[Y] = map(roomUserY, roomBack, roomFront, -roomFrontOffset, roomFrontOffset);
    roomUser[O] = roomUserO; 
    
    if (SEND_IMMEDIATELY) {
      if (SEND_ORIENT_POS_SEPARATELY) {
        sendPositionToCave();
        sendOrientationToCave();
      } else 
        sendPositionAndOrientationToCave();
    }
  }
}

// *** receive tracking orientation ****************************************************************
void trackingOrientation(int roomUserYaw, int roomUserRoll, int roomUserPitch) {
  if (isSystemOn) {
    debugStr("-> RECEIVED " + orientationTrackingPattern + " iii - " + roomUserYaw +  " " + 
               roomUserRoll + " " + roomUserPitch);
    
    roomUser[O] = float(roomUserYaw); 
    
    if (SEND_IMMEDIATELY)
      sendOrientationToCave();
  }
}

// *** receive tracking position *******************************************************************
void trackingPosition(float roomUserX, float roomUserY) {
  if (isSystemOn) {
    debugStr("-> RECEIVED " + trackingPattern + " ff - " + roomUserX + " " + roomUserY);

    roomUser[X] = map(roomUserX, roomLeft, roomRight, roomRight, roomLeft);
    roomUser[Y] = map(roomUserY, roomBack, roomFront, -roomFrontOffset, roomFrontOffset);
    roomUser[Y] = map(roomUserY, 0.0, 3000.0, 1500.0, -1500.0);
    
    if (SEND_IMMEDIATELY)
      sendPositionToCave();
  }
}

// *** receive CAVE position  **********************************************************************
//     send caveuser position to the sound system
void position(float caveUserX, float caveUserY) {
  if (isSystemOn) {
    debugStr("-> RECEIVED " + caveUserPositionPattern + " ff - " + caveUserX + " " + caveUserY);
          
    updateSoundPosition(POSITION, caveUserX, caveUserY);
  }
}

// *** receive CAVE velocity ***********************************************************************
//     use the velocity to change the heartbeat sound trigger speed
void velocity(float velocity) {
  if (isSystemOn) {
    debugStr("-> RECEIVED " + caveUserVelocityPattern + " f - " + velocity);
  
    caveUserVel = velocity;
  }
}

// *** send position and orientation to the CAVE each n(timeout) ms ********************************
//     toggle between sending orientation and position 
void sendRoomUserDataToCave() {
  if ((millis() - timestamp) >= timeout) {
    if (SEND_ORIENT_POS_SEPARATELY) {
      if (sendPosNow) {
        sendPositionToCave();
        sendPosNow = !sendPosNow;
      } else {
        sendOrientationToCave();
        sendPosNow = !sendPosNow;
      }
    } else {
      sendPositionAndOrientationToCave();
    }
    timestamp = millis();
  } 
}

// *** send position data to the CAVE **************************************************************
void sendPositionToCave() {
  // send position data
  OscMessage message = new OscMessage(roomPersonPositionPattern);
  message.add(roomUser[X]);
  message.add(roomUser[Y]);
  if (CAVE_TCP_ONLY)
    caveOSCtcpOut.send(message);
  else
    caveOSCudpOut.send(message, caveNetAddress);
    
  debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + 
           " " + roomUser[X] + " " + roomUser[Y]);
}

// *** send orientation data to the CAVE ***********************************************************
void sendOrientationToCave() {  
  OscMessage message = new OscMessage(roomPersonOrientationPattern);
  message.add(roomUser[O]);
  if (CAVE_TCP_ONLY)
    caveOSCtcpOut.send(message);
  else
    caveOSCudpOut.send(message, caveNetAddress);
  
  debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + 
           " " + roomUser[O]);
}

// *** send position and orientation data combined to the CAVE *************************************
void sendPositionAndOrientationToCave() {
  OscMessage message = new OscMessage(roomPersonPattern);
  message.add(roomUser[X]);
  message.add(roomUser[Y]);
  message.add(roomUser[O]);
  if (CAVE_TCP_ONLY)
    caveOSCtcpOut.send(message);
  else
    caveOSCudpOut.send(message, caveNetAddress);
  
  debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + 
           " " + roomUser[X] + " " + roomUser[Y]);
}

// *** send sound event change to sound system *****************************************************
//     set distance and angle for spatial sound
//     send OSC event
void sendSoundChangeEvent(int interaction, float distance, float angle) {
  if (soundEvents[interaction].isDifferent(soundEvents[interaction].volume, distance, angle, true)) {
    soundEvents[interaction].distance = distance;
    soundEvents[interaction].angle = angle;
    soundEvents[interaction].isOn = true;
    
    OscMessage message = new OscMessage(soundPattern + "/" + soundEvents[interaction].number);
    message.add(soundEvents[interaction].volume);
    message.add(soundEvents[interaction].distance);
    message.add(soundEvents[interaction].angle);
    
    debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + 
             " - " + soundEvents[interaction].volume + " " + 
             soundEvents[interaction].distance +  " " + soundEvents[interaction].angle);
          
    soundOSCudp.send(message, soundNetAddress);
  }
}

// *** send sound event off to sound system ********************************************************
//     reset distance and angle for spatial sound to 0.0
//     send OSC event
void sendSoundEventOff(int interaction) {
  if (soundEvents[interaction].isDifferent(0.0, 0.0, 0.0, false)) {
    soundEvents[interaction].isOn = false;
    
    OscMessage message = new OscMessage(soundPattern + "/" + soundEvents[interaction].number);
    message.add(0.0);
    message.add(0.0);
    message.add(0.0);
    
    debugStr("<- SENDING " + message.addrPattern() + " " + message.typetag() + " - 0.0 0.0 0.0");
      
    soundOSCudp.send(message, soundNetAddress);
  }
}

// *** send sound position change ******************************************************************
//     normalize cave user position to -1.0/1.0
//     send sound change event                  
void updateSoundPosition(int interaction, float cux, float cuy) {
  float x = map(cux, caveLeft, caveRight, -1.0, 1.0);
  float y = map(cuy, caveFront, caveBack, -1.0, 1.0);
  caveUserSoundDistance = dist(centerX, centerY, x, y);
  caveUserSoundAngle = getAngle(centerX, centerY, x, y); 
  
  sendSoundChangeEvent(interaction, caveUserSoundDistance, caveUserSoundAngle);
}

// *** calculate angle between two coordinates *****************************************************
float getAngle(float x1, float y1, float x2, float y2) {
  return 180.0 + atan2((y1 - y2), (x1 - x2)) * 180.0 / PI;
} 

// *** re-trigger heartbeat ************************************************************************
//     time-baed triggering og heartbeat sound events depending on the velocity               
void triggerHeartbeat() {
  int now = millis();
  int heartbeat = int(map(abs(caveUserVel), 0.0, maxVelocity, minHearbeat, maxHeartbeat));
  if (float(now - lastHearbeat) > 1.0 / float(heartbeat) * 60000) {
    lastHearbeat = now;
    sendSoundChangeEvent(VELOCITY, caveUserSoundDistance, caveUserSoundAngle);
  } 
}

// *** receive CAVE touch event ********************************************************************
//     this is a on/off message to start the touch and end it
//     enable/disable the touch sound 
void touch(int touchOn) {  
  if (isSystemOn) {
    debugStr("-> RECEIVED " + caveUserTouchPattern + " i - " + touchOn);
         
    if (touchOn == 1) {
      vest.startTouch();
      sendSoundChangeEvent(TOUCH, 0.0f, 0.0f);    // play sound from center - loudest 
    } else if (touchOn == 0) {
      vest.endTouch();
      sendSoundEventOff(TOUCH);
    }
  }
}

// *** receive CAVE touch positions ****************************************************************
//     map the touch positions to vest positions and activate/deactivate the motors accordingly
void touching(float touchX, float touchY, float touchZ) {
  if (isSystemOn && vest.isTouchOn) {
    debugStr("-> RECEIVED " + caveUserTouchingPattern + " fff - " + 
             touchX + " " + touchY + " " + touchZ);
                
    vest.touch(touchX, touchY, touchZ);
  }
}

// *** receive CAVE hit positions ******************************************************************
//     activate the motors next to the hit positions
//     trigger the hit sound
void hit(float hitX, float hitY, float hitZ) { 
  // new hit event received
  if (isSystemOn && !vest.isHitOn) {
    debugStr("-> RECEIVED " + caveUserHitPattern + " fff - " + hitX + " " + hitY + " " + hitZ);
            
    vest.hit(hitX, hitY, hitZ);
       
    // send hit event to the sound system
    sendSoundChangeEvent(HIT, 0.0f, 0.0f);    // play sound from center - loudest     
  }
}

// *** receive CAVE bump positions *****************************************************************
//     activate some motors for a certain period of time to make the bump a haptic experience
//     trigger the bump sound
void bump(float bumpX, float bumpY) {  
  if (isSystemOn && !vest.isBumpOn) {
    debugStr("-> RECEIVED " + caveUserBumpPattern + " ff - " + bumpX + " " + bumpY);    
  
    vest.bump(bumpX, bumpY);
    
    sendSoundChangeEvent(BUMP, 0.0f, 0.0f);    // play sound from center - loudest       
  }
}
