void setup_measurement() {
  weight.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  dht.begin();
}

compressed compress(measurement m) {
  return compressed {
    m.time, // 45 days with 1 minute resolution
    m.weight - 50000,
    (m.moisture - 330) * 4,
    m.temp - 15,
    //m.humidity * 100,
    (m.light < 128) ? m.light : 128 + m.light / 8 };
}

measurement uncompress(compressed m) {
  return measurement {
    m.time,
    (long) m.weight + 50000,
    (long) m.moisture / 4 + 330 ,
    (long) m.temp + 15,
    1,
    (m.light < 128) ? m.light : ((long) m.light - 128) * 8 };
}

void print(measurement m) {
  Serial.print("time=");
  Serial.print(m.time);
  Serial.print(" weight=");
  Serial.print(m.weight);
  Serial.print(" moisture=");
  Serial.print((int)(m.moisture*10));
  Serial.print(" temp=");
  Serial.print(m.temp);
  Serial.print(" hum=");
  Serial.print(m.humidity);
  Serial.print(" light=");
  Serial.print(m.light);
  Serial.println("-");
};

measurement add(measurement m1, measurement m2) {
  return measurement {
    m1.time + m2.time,
    m1.weight + m2.weight,
    m1.moisture + m2.moisture,
    m1.temp + m2.temp,
    m1.humidity + m2.humidity,
    m1.light + m2.light};
}

measurement div(measurement m, float by) {
  return measurement {
    m.time / by,
    m.weight / by, 
    m.moisture / by, 
    m.temp / by, 
    m.humidity / by,
    m.light / by};
}

measurement measure() {
  weight.wait_ready_timeout(1000); // does this help?
  long w = weight.read() / 10;
  int  m = analogRead(MOISTURE_PIN);
  int  t = dht.readTemperature() * 10;
  int  h = dht.readHumidity() * 100;
  int  l = analogRead(PHOTO_PIN);
  unsigned long time = millis();
  return measurement {time,w,m,t,h,l};
}