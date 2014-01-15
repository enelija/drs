class Motor {
  
  int id;
  PVector coordinates;
    
  Motor(int id, float x, float y, float z) {
    this.id = id;
    this.coordinates = new PVector(x, y, z);
  }
  
}
