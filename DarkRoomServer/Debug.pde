final int DEBUG_NONE = 0;
final int DEBUG_POS_C = 1 << 0;
final int DEBUG_POS_R = 1 << 1;
final int DEBUG_ORIENT = 1 << 2;
final int DEBUG_VELO = 1 << 3;
final int DEBUG_HIT = 1 << 4;
final int DEBUG_BUMP = 1 << 5;
final int DEBUG_TOUCH = 1 << 6;
final int DEBUG_SOUND = 1 << 7;
final int DEBUG_ALL = DEBUG_POS_C | DEBUG_POS_R | DEBUG_ORIENT | DEBUG_VELO | 
                      DEBUG_HIT | DEBUG_BUMP | DEBUG_TOUCH | DEBUG_SOUND;

int DEBUG = DEBUG_ALL;

PrintWriter output;


void debugStr(String pStr) {
    if (DEBUG_TO_FILE)
      output.println(pStr);
    else
      println(pStr);
}

void setupWriter() {
 if (DEBUG_TO_FILE) 
    output = createWriter("VrOSCmessages.txt");
}

void setDebugLevel(char theKey) {  
  if (theKey == '0')
    DEBUG = DEBUG_NONE;
  else if (theKey == '1')
    DEBUG = DEBUG ^ DEBUG_POS_C;
  else if (theKey == '2')
    DEBUG = DEBUG ^ DEBUG_POS_R;
  else if (theKey == '3')
    DEBUG = DEBUG ^ DEBUG_ORIENT;
  else if (theKey == '4')
    DEBUG = DEBUG ^ DEBUG_VELO;
  else if (theKey == '5')
    DEBUG = DEBUG ^ DEBUG_HIT;
  else if (theKey == '6')
    DEBUG = DEBUG ^ DEBUG_BUMP;
  else if (theKey == '7')
    DEBUG = DEBUG ^ DEBUG_TOUCH;
  else if (key == '8')
    DEBUG = DEBUG ^ DEBUG_SOUND;
  else if (key == '9') 
    DEBUG = DEBUG_ALL;
}

void renderHelp() {
  fill(0);
  int offset = 0, diff = 20;
  text("Set the debug output by pressing the number keys: ", 10, offset += diff);
  setOutputColorEqual(DEBUG_NONE);
  text("0: No debug output", 10, offset += diff * 1.5);
  setOutputColorAnd(DEBUG_POS_C);
  text("1: CAVE user position output", 10, offset += diff);
  setOutputColorAnd(DEBUG_POS_R);
  text("2: Room user position output", 10, offset += diff);
  setOutputColorAnd(DEBUG_ORIENT);
  text("3: Room user orientation output", 10, offset += diff);
  setOutputColorAnd(DEBUG_VELO);
  text("4: Velocity output", 10, offset += diff);
  setOutputColorAnd(DEBUG_HIT);
  text("5: Hit position output", 10, offset += diff);
  setOutputColorAnd(DEBUG_BUMP);
  text("6: Bump position output", 10, offset += diff);
  setOutputColorAnd(DEBUG_TOUCH);
  text("7: Touch position output", 10, offset += diff);
  setOutputColorAnd(DEBUG_SOUND);
  text("8: Sound output", 10, offset += diff);
  setOutputColorEqual(DEBUG_ALL);
  text("9: Debug everything", 10, offset += diff);
  
  fill(0);  
  text("CAVE IP:                 " + caveIP, 10, offset += diff * 2.5);
  
  text("TCP out port:            " + CAVE_TCP_OUT_PORT, 10, offset += diff * 1.5);
  text("TCP in port:             " + CAVE_TCP_IN_PORT, 10, offset += diff);
  text("UDP out port:            " + CAVE_UDP_OUT_PORT, 10, offset += diff);
  text("UDP in port:             " + CAVE_UDP_IN_PORT, 10, offset += diff);
  

  text("Sound UDP out port:      " + SOUND_UDP_OUT_PORT, 10, offset += diff * 1.5);
  text("Tracking UDP in port:    " + TRACKING_UDP_IN_PORT, 10, offset += diff);
  if (!ORIENTATION_FROM_VEST)
    text("Orientation UDP in port: " + ORIENTATION_TRACKING_UDP_IN_PORT, 10, offset += diff);  
}

void setOutputColorAnd(int flag) {
  if (boolean(DEBUG & flag))
    fill(0, 220, 0);
  else 
    fill(0);
}

void setOutputColorEqual(int flag) {
  if (DEBUG == flag)
    fill(0, 220, 0);
  else 
    fill(0);
}

