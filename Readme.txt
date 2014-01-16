Installation:
=========================================================================================
- Download and install Processing (32-bit version on Windows since the Serial 
  communication does only work with the 32-bit version).

- Go to 'Sketch' menu -> 'Import Library' -> 'Add library' and install the oscP5 library


Configuration:
=========================================================================================
- Config.pde: these options are all documented in the code and meant for configuring the 
  system


DOCUMENTATION:
=========================================================================================
- The Processing patch receives position coordinates from the CAVE (cave user) and the 
  tracking system (room user) via OSC (UDP and TCP). Also the velocity of the cave user 
  and some interaction events (bump/hit/touch) are received. 
  All these messages are transformed (mapped to target coordinate systems) and sent to the
 -- sound system which sonifies the cave user position and actions
 -- vest which gives haptic feedback for all actions (bump/hit/touch) 
 
- The specification of the messages sent over OSC can be found here: 
  http://www.interface.ufg.ac.at/vrprojectwiki/index.php/Communication_Protocol

- In the beginning/end an activation event is sent to turn this system on/off (TCP)
 -- if the system is off no sounds should be played (so looped sounds are turned off)
 -- if the system is on, the position and mood (velocity mapped to a heartbeat sound) of 
    the cave user is played
 -- all other sounds and the haptic vest actuators are triggered when actions 
   (bump/hit/touch) occur and are not explicitly turned on/off by the system on/off event

- For the touch interaction on/off events are sent (TCP)
 -- between these, the touch positions are sent (UDP) 

- Coordinate systems: see comments in the code


TODO: 
=========================================================================================
- Test with the complete system and fix remaining issues.
