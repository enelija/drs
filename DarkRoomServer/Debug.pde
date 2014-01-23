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

