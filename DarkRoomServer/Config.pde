// generate debug output: write it to a file or to the console
final boolean DEBUG = true;
final boolean WRITE_TO_FILE = false;

// turn heartbeat off for testing other sounds better
final boolean HEARTBEAT_OFF = false;

// receive orientation from vest or via OSC (smartphone)
final boolean ORIENTATION_FROM_VEST = false;  
// test without the vest turns all bluetooth communication off (no InvocationTargetException for OSC TCP)
final boolean RUN_WITHOUT_VEST = false;  

// prevent from initiating a TCP connection
final boolean PREVENT_INITITATE_TCP_CONN = false;
// only use the tcp for cave communication
final boolean CAVE_TCP_ONLY = false;
// send position and orientation in two separate messages (true) or in a single one (false)
final boolean SEND_ORIENT_POS_SEPARATELY = true;
// send position and orientation immediately to the CAVE instead of each n ms
final boolean SEND_IMMEDIATELY = true;

// use false here if the activity on/off event is sent by the CAVE
boolean isSystemOn = false; 

// set IP for the CAVE
String caveIP = /*"127.0.0.1";*/ "10.0.0.200"; /*"10.156.309.151"*/
String localIP = "127.0.0.1";

// in- and out ports for the cave communication
final int CAVE_TCP_OUT_PORT = 2377;
final int CAVE_TCP_IN_PORT = 2378;
final int CAVE_UDP_OUT_PORT = 2379;
final int CAVE_UDP_IN_PORT = 2380;

// in- and outbound ports for all local UDP communication
final int SOUND_UDP_OUT_PORT = 12345;                 // local
final int TRACKING_UDP_IN_PORT = 12347;               // local
final int ORIENTATION_TRACKING_UDP_IN_PORT = 12350;   // local

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
final int BLUETOOTH_PORT = 2;               // 0: COM1 (Windows) // 1: COM3 (Windows)
int baudRate = 57600;

// timer for sending to CAVE every 100 ms (10x per second)
int timestamp = 0, timeout = 100;

// heartbeat range for slow and fast movement
int minHearbeat = 50, maxHeartbeat = 100;   // in beats per minute

// COORDINATE SYSTEMS:
//   CAVE:   3D right-handed cartesian coordinate system
//           X: left to right axis; Y: bottom to top; 
//           Z: towards the screen
//           origin is on the floor in the center 
//           units are given in centimeters 
//   ROOM:   2D cartesian coordinate system
//           origin is front center
//           units given in cm 
//   SOUND:  2D polar coordinate system
//           origin is in the center
//           radius is 1.0 [0.0, 1.0] in 360 degrees
//   AVATAR: 3D cartesian coordinate system -> not used so far 
//           origin is the hip center (bottom of vest)
//   VEST:   3D cartesian coordinate system 
//           origin is the bottom center
float caveLeft = -10000.0, caveRight = 10000.0,                                   // for mapping the sound system 
      caveFront = -10000.0, caveBack = 10000.0,                                   // cm
      
      roomLeft = 1500.0, roomRight = -1500.0,                                     // for mapping the kinect tracking  
      roomFront = 3000.0, roomBack = 0.0, roomFrontOffset = -1500.0,              // cm
      
      vestLeft = -26.0, vestRight = 26.0, vestBottom = 0.0, vestTop = 62.5,       // for mapping the hit/bump/touch coords
      vestBack = -10.0, vestFront = 10.0;                                         // cm
