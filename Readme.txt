Installation:
=========================================================================================
- Download and install Processing (32-bit version on Windows since the Serial 
  communication does only work with the 32-bit version).

- Go to 'Sketch' menu -> 'Import Library' -> 'Add library' and install the oscP5 library



Configuration:
=========================================================================================
- Change the caveIP if necessary

- Change the ports if necessary:
 -- SOUND_SENDER_PORT is set in the sound system PD patch
 -- TRACKING ports are set in the OpenFrameworks project which does the tracking
 -- CAVE ports are set in the Cave software

- Change the BLUETOOTH_PORT to the used serial port

- minHearbeat (60) and maxHearbeat (180) can be changed if desired

- turn DEBUG off if desired

- change the bumpHit length (300 ms) if a longer/shorter vibration motor activation is 
  desired



DOCUMENTATION:
=========================================================================================
- The Processing patch receives position coordinates from the CAVE (cave user) and the 
  tracking system (room user) via OSC (UDP and TCP). Also the velocity of the cave user 
  and some interaction events (bump/hit/touch) are sent. 
  All these messages are transformed (mapped to target coordinate system) and sent to 
 -- sound system which sonifies the cave user position and interactions and the
 -- haptic vest which gives haptic feedback for all interactions (bump/hit/touch) and also 
    has some LEDs which are tracked by a camera to track the room user position

- The specification of the messages sent over OSC can be found here: 
  http://www.interface.ufg.ac.at/vrprojectwiki/index.php/Communication_Protocol

- In the beginning/end an activation event is sent to turn this system on/off (TCP)
 -- if the system is off no shounds should be played (so looped sounds are turned off)
 -- if the system is on, the position and mood (velocity mapped to a heartbeat sound) of 
    the cave user is played
 -- all other sounds and the haptic vest actuators are triggered when interactions 
   (bump/hit/touch) occur and are not explicitly turned on/off by the system on/off event

- For the touch interaction on/off events are sent (TCP)
 -- between these, the touch positions are sent (UDP) 

- Coordinate systems: 
 -- CAVE: 3D right handed cartesian coordinate system [w, h] cm
 -- ROOM: 2D cartesian coordinate system, [640, 480] px -> [250, 170] cm
  --- VEST: part of the room system, [52, 62.5] cm
 -- SOUND: 2D polar coordinate system with radius 1.0


- The vibration motors (numbers 0-15) layout and size of the haptic vest:
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
  
- Suggestion which motors to activate on which interaction: 
 -- BUMP: 
  --- left:    5,  6,  9, 10
  --- center: 12, 13, 14, 15
  --- right:   0,  7,  8, 11
 -- HIT and TOUCH:
  --- calculate the best fitting motor for two regions:
   ---- upper part -> horizontal line of motors on the front: 0, 1, 2, 3, 4, 5
   ---- lower part -> vertical line of motors on the back: 12, 13, 14, 15
  -- for the HIT: activate three motors in a row, the center one stronger than the outer
                  ones for a certain time (~300 ms)
  -- for TOUCH: keep the motor on as long as an other motor is on, until the off event is
                sent



TODO: 
=========================================================================================
- map CAVE coordinates to vest coordinates: this method needs to respect the current
  room user position and orientation (roomUserX, roomUserY, roomUserO)

- map the tracking coordinates to coordinates required by the CAVE

- map the tracking coordinates to sound space coordinates

- map the CAVE coordinates to sound system coordinates

- for all interactions (bump/hit/touch) replace code "if (true)" by a meaningful decision
  when to activate the suggested motors (depending on the given CAVE user coordinates and
  the current position and orientation of the room user)

- add more debug output (for testing) and test and fix bugs

- test with haptic vest and if necessary add an explicit LR or CF to the sent command 
  (bluetooth communication)

