class SpatialSoundEvent {
  
  int number;          // start at 1, up to 10 
  float volume;        // range [0.0-1.0]
  float distance;      // range [0.0-10.0]
  float angle;         // range [0.0-360.0]
  boolean isOn;        // turn sound on or off
  boolean isLooped;    // looped or single played sound
  
  SpatialSoundEvent(int number) {
    this.number = number;
    this.volume = 1.0;
    this.distance = 1.0;
    this.angle = 0.0;
    this.isOn = true;
    this.isLooped = false;
  }
  
  boolean isDifferent(float volume, float distance, float angle, boolean isOn) {
    if (this.volume != volume || this.distance != distance || 
        this.angle != angle || this.isOn != isOn) {
      return true;
    }
    
    return false;
  }
}
