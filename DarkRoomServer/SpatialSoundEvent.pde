class SpatialSoundEvent {
  
  int number;          // start at 1, up to 10 
  float volume;        // range [0.0-1.0]
  float distance;      // range [0.0-10.0]
  float angle;         // range [0.0-360.0]
  boolean isOn;        // turn sound on or off
  
  SpatialSoundEvent(int number) {
    this.number = number;
    this.volume = 0.0;
    this.distance = 1.0;
    this.angle = 0.0;
    this.isOn = false;
  }
  
  void setVolume(float volume) {
    this.volume = volume;
  }
  
  void setDistance(float distance) {
    this.distance = distance;
  }
  
  void setAngle(float angle) {
    this.angle = angle;
  }
  
  void setIsOn(boolean isOn) {
    this.isOn = isOn;
  }
  
  void resetDistance() {
    this.distance = 1.0;
  }
  
  int getNumber() {
    return number;
  }
  
  float getVolume() {
    return volume;
  }
  
  float getDistance() {
    return distance;
  }
  
  float getAngle() {
    return angle;
  }
  
  boolean isOn() {
    return isOn;
  }
}
