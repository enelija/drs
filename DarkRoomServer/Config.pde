// generate debug output: write it to a file or to the console
final boolean DEBUG = false;
final boolean WRITE_TO_FILE = false;
// turn heartbeat off for testing other sounds better
final boolean HEARTBEAT_OFF = false;
// receive orientation from vest or via OSC (smartphone)
final boolean ORIENTATION_FROM_VEST = true;  
// test without the vest turns all bluetooth communication off (no InvocationTargetException for OSC TCP)
final boolean TEST_WITHOUT_VEST = false;  
// only use the cave tcp listener, no senders
final boolean CAVE_TCP_LISTENER_ONLY = true;

// use false here if the activity on/off event is sent by the CAVE
boolean isSystemOn = false; 

// set IP for the CAVE
String caveIP = "127.0.0.1"; //"10.156.309.151"                    // needed if CAVE_TCP_LISTENER_ONLY = false
String localIP = "127.0.0.1";

// in- and outbound ports for all TCP and UDP messages
final int SOUND_LISTENER_PORT = 12344;                  // local
final int SOUND_SENDER_PORT = 12345;                    // local
final int TRACKING_LISTENER_PORT = 12347;               // local
final int ORIENTATION_TRACKING_LISTENER_PORT = 12350;   // local

// in case this server runs a TCP listener only
final int CAVE_LISTENER_TCP_PORT = 23781;                // TCP listener
// in case this server sends TCP and UDP
final int CAVE_SENDER_PORT = 2379;
final int CAVE_LISTENER_PORT = 2380;

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

// timer for sending to CAVE every 100 ms (10x per second)
int timestamp = 0, timeout = 100;

// heartbeat range for slow and fast movement
int minHearbeat = 50, maxHeartbeat = 100;   // in beats per minute

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
float caveLeft = -1000.0, caveRight = 1000.0, caveFront = -1000.0, 
      caveBack = 1000.0, caveBottom = 0.0, caveTop = 2000.0,                      // cm
      roomLeft = 1500.0, roomRight = -1500.0,                                     // looking from back to front, right is negative
      roomFront = 0.0, roomBack = 3000.0,                                         // cm
      vestLeft = -26.0, vestRight = 26.0, vestBottom = 0.0, vestTop = 62.5,           
      vestBack = -10.0, vestFront = 10.0;                                         // cm
      