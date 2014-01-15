PrintWriter output;

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

void setupWriter() {
 if (WRITE_TO_FILE) 
    output = createWriter("VrOSCmessages.txt");
}

void keyPressed() {
  if (key == ESC && WRITE_TO_FILE) {
    output.flush();
    output.close();
  }
}
