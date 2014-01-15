import processing.serial.*;

class Vest {  
  
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

  Motor[] motors = {
      // FRONT (id,     X,      Y,      Z)
      new Motor( 0, 18.0f,  10.0f,  62.5f),        // 0:  shoulder outer right
      new Motor( 1, 14.5f,  10.0f,  62.5f),        // 1:  shoulder center right
      new Motor( 2, 11.0f,  10.0f,  62.5f),        // 2:  shoulder inner right
      new Motor( 3,-11.0f,  10.0f,  62.5f),        // 3:  shoulder inner left
      new Motor( 4,-14.5f,  10.0f,  62.5f),        // 4:  shoulder center left
      new Motor( 5,-18.0f,  10.0f,  62.5f),        // 5:  shoulder outer left
      new Motor( 6,-19.0f,  10.0f,  28.0f),        // 6:  arm left
      new Motor( 7, 19.0f,  10.0f,  28.0f),        // 7:  arm right
      new Motor( 8, 16.0f,  10.0f,  16.0f),        // 8:  hip right
      new Motor( 9,-16.0f,  10.0f,  16.0f),        // 9:  hip left
      // BACK  (id     X,       Y,      Z)
      new Motor(10,-15.0f, -10.0f,  52.5f),        // 10:  shoulder left
      new Motor(11, 15.0f, -10.0f,  52.5f),        // 11:  shoulder right
      new Motor(12,  0.0f, -10.0f,  45.5f),        // 12:  spine top
      new Motor(13,  0.0f, -10.0f,  38.5f),        // 13:  spine almost top
      new Motor(14,  0.0f, -10.0f,  31.5f),        // 14:  spine almost bottom
      new Motor(15,  0.0f, -10.0f,  24.5f)         // 15:  spine bottom
    };
    
  // motor strength for touch/hit/bump
  int touchStrength = 30;
    
  // on bump: motors with first four id are activated with strength 55 for 120 ms, 
  //          then the next four motors are activated with strength 22 for 90 ms,
  int numOfActiveBumpMotors = 4;             // number of bump motors activated at the same time
  int bumpStep = 0;                           // current bump animation step
  int[] bumpStrengths = {55, 22};
  int[] bumpDurations = {120, 90};           // in ms
  int[][] bumpPatterns = {
    { 5,  6,  9, 10, 12, 13, 14, 15},        // bump left
    { 0,  7,  8, 11, 12, 13, 14, 15},        // bump right
    {12, 13, 14, 15,  8,  9, 10, 11},        // bump back
    { 1,  2,  3,  4,  0,  5,  6,  7}};       // bump front
  
  // on hit: motor with id is activated with strength 63 for 100 ms, 
  //         then three surrounding motors with strength 15 each are activated for 60 ms
  int numOfActiveHitMotors = 3;              // number of hit motors activated at the same time
  int[] hitStrengths = {63, 15};
  int[] hitDurations = {100, 60};            // in ms
  int hitStep = 0;                           // current bump animation step
  int[][] hitPatterns = {
          {0, 1, 2, 0, 1, 2},                // motor id 0
          {1, 2, 0, 1, 2, 0},                // motor id 1
          {2, 1, 0, 2, 1, 0},                // motor id 2
          {3, 4, 5, 3, 4, 5},                // motor id 3
          {4, 5, 3, 4, 5, 3},                // motor id 4
          {5, 3, 4, 5, 3, 4},                // motor id 5
          {6, 9, 15, 6, 9, 15},              // motor id 6
          {7, 8, 15, 7, 8, 15},              // motor id 7
          {8, 15, 7, 8, 15, 7},              // motor id 8
          {9, 6, 15, 9, 6, 15},              // motor id 9
          {10, 4, 5, 10, 4, 5},              // motor id 10
          {11, 0, 1, 11, 0, 1},              // motor id 11
          {12, 13, 14, 12, 13, 14},          // motor id 12
          {13, 14, 12, 13, 14, 12},          // motor id 13
          {14, 15, 13, 14, 15, 13},          // motor id 14
          {15, 14, 13, 15, 14, 13}};         // motor id 15
    
  Serial bluetooth;
  int maxMotorId = 15, maxStrength = 63, asciiOffsetO = 48, asciiOffsetA = 65;
  char orientPatt = 'h';
  char motorPatt = 'p';
  char resetPatt = 'r';
  char lineFeed = '\n';
   
  int bumpArea = 0, bumpBegin = 0, hitBegin = 0, hitIdx = 0;
  boolean bumpOn = false, hitOn = false, isTouchOn = false;
    
  Vest(PApplet app, int port, int baudrate) {
    for (int i = 0; i < Serial.list().length; ++i) 
      printStr(Serial.list()[i]); 
    bluetooth = new Serial(app, Serial.list()[port], baudrate);
  }
  
  String activateMotor(int motor, int strength) {
    if (motor <= maxMotorId && strength <= maxStrength) {
      char motorFlag = char(asciiOffsetA + motor);
      char strengthFlag = char(asciiOffsetO + strength); 
      String command = str(motorPatt) + str(motorFlag) + str(strengthFlag) + str(lineFeed);
      bluetooth.write(command);
      return command;
    }
    return "";
  }
  
  String resetMotors() {
    String command = str(resetPatt) + str(lineFeed); 
    bluetooth.write(command);
    debugStr(" -> sending RESET to motors"); 
    return command;
  }
  
  void update() {
    if (bumpOn)
      updateBump();
    if (hitOn)
      updateHit();
  }

      
  void startTouch() {
    isTouchOn = true;
    debugStr(" -> starting TOUCH");
  }
  
  void endTouch() {
    isTouchOn = false;
    resetMotors();
    debugStr(" -> ending TOUCH");
  }
  
  void touch(float touchX, float touchY, float touchZ) {
    if (isTouchOn) {
      resetMotors();
      int mid = getNearestMotorID(touchX, touchY, touchZ);
      activateMotor(mid, touchStrength);
      debugStr("    -> running TOUCH with strength " + touchStrength + " on motor " + mid); 
    }
  }
  
  void setBumpArea(float bumpX, float bumpY) {
    // calculate area of bump (left / right / back / front)   
    if (bumpX < vestLeft / 2.0)            // left bump
      bumpArea = 0;
    else if (bumpX > vestRight / 2.0)      // right bump
      bumpArea = 1;
    else if (bumpY < 0.0)                  // back bump
      bumpArea = 2;
    else if (bumpY >= 0.0)                 // front bump
      bumpArea = 3;   
  }
  
  void bump(float bumpX, float bumpY) {
    bumpBegin = millis(); 
    bumpOn = true;
    setBumpArea(bumpX, bumpY);      
    updateBump();
  }
      
  void updateBump() {
    int now = millis();
    if (bumpStep == 2 && now - bumpBegin > bumpDurations[0] + bumpDurations[1]) {  
      resetMotors();  
      bumpOn = false;
      bumpStep = 0;
    } else if (bumpStep == 0) {
      triggerBump(0);
      bumpStep = 1;
    } else if (bumpStep == 1 && now - bumpBegin > bumpDurations[0]) {
      triggerBump(1);
      bumpStep = 2;
    }  
  }
  
  void triggerBump(int n) { 
    resetMotors();  
    for (int i = 0; i < numOfActiveBumpMotors; ++i) {
      activateMotor(bumpPatterns[bumpArea][numOfActiveBumpMotors * n + i], bumpStrengths[n]);
      debugStr(" -> sending BUMP for area " + bumpArea + " with strength " + bumpStrengths[n] + 
               " to motor " + bumpPatterns[bumpArea][numOfActiveBumpMotors * n + i]);
    }
  }
  
  void hit(float hitX, float hitY, float hitZ) {
    hitBegin = millis(); 
    hitOn = true;
    hitIdx = getNearestMotorID(hitX, hitY, hitZ);
    updateHit();
  }
   
  void triggerHit(int n) {
    resetMotors();  
    for (int i = 0; i < numOfActiveHitMotors; ++i) {
      activateMotor(hitPatterns[hitIdx][numOfActiveHitMotors * n + i], hitStrengths[n]);
      debugStr(" -> sending HIT with strength " + hitStrengths[n] + 
               " to motor " + hitPatterns[hitIdx][n + i]);
    }
  }
    
  void updateHit() {
    int now = millis();
    if (hitStep == 2 && now - hitBegin > hitDurations[0] + hitDurations[1]) {    
      resetMotors();  
      hitOn = false;
      hitStep = 0;
    } else if (hitStep == 0) {
      triggerHit(0);
      hitStep = 1;
    } else if (hitStep == 1 && now - hitBegin > hitDurations[0]) {
      triggerHit(1);
      hitStep = 2;
    }  
  }
  
  int getNearestMotorID(float x, float y, float z) {
    float curDist = 0.0f;
    float minDist = dist(x, y, z, motors[0].coordinates.x, motors[0].coordinates.y, motors[0].coordinates.z);
    int id = 0;
    for (int i = 1; i < motors.length; ++i) {
      curDist = dist(x, y, z, motors[i].coordinates.x, motors[i].coordinates.y, motors[i].coordinates.z);
      if (curDist < minDist) {
        minDist = curDist;
        id = i;  
      }
    } 
    return id;
  }
  
  void serialEvent(Serial p) {
    if (!TEST_WITHOUT_VEST && ORIENTATION_FROM_VEST) {
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
  }

  void testHitBumpTouch() {    
    printStr("1) test if the motor coordinate position is correctly found for the actual distance");
    for (int i = 0; i < motors.length; ++i)
      printStr(str(getNearestMotorID(motors[i].coordinates.x,motors[i].coordinates.y, motors[i].coordinates.z)));    
  }
}
