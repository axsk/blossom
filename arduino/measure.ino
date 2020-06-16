#include "measure.h"

#include "Arduino.h"

#include "HX711.h"
//#include "DHT.h"
#include <BME280I2C.h>
#include <Wire.h>


HX711 weight;
//DHT dht(DHTPIN, DHTTYPE);
BME280I2C bme;

long weight_last = 0;

void setup_measurement() {
  Wire.begin();
  bool s = bme.begin();
  Serial.println(s);
  weight.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN, 128);
  //dht.begin();
  
  weight_last = weight.read_average(10);
}



compressed compress(measurement m) {
  return compressed {
    m.time, // 45 days with 1 minute resolution
    (m.weight - 500000) / 10,
    (m.moisture - 250), // min'max observed: 277 425
    (m.temp - 18) * 20,
    m.humidity / 100 * 255,
    (m.pressure - 100000) / 10,
    (m.light < 128) ? m.light : 128 + m.light / 8 };
}

measurement uncompress(compressed m) {
  return measurement {
    m.time,
    (float) m.weight * 10 + 500000,
    (float) m.moisture + 250,
    (float) m.temp / 20 + 18,
    (float) m.humidity / 255 * 100,
    (float) m.pressure * 10 + 100000,
    (m.light < 128) ? m.light : ((float) m.light - 128) * 8 };
}

void print(measurement m) {
  Serial.print("time=");
  Serial.print(m.time);
  Serial.print(" weight=");
  Serial.print(m.weight / 100);
  Serial.print(" moisture=");
  Serial.print(m.moisture);
  Serial.print(" temp=");
  Serial.print(m.temp);
  Serial.print(" hum=");
  Serial.print(m.humidity);
  Serial.print(" pressure=");
  Serial.print(m.pressure);
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
    m1.pressure + m2.pressure,
    m1.light + m2.light};
}

measurement div(measurement m, unsigned int by) {
  return measurement {
    m.time / by,
    m.weight / by,
    m.moisture / by,
    m.temp / by,
    m.humidity / by,
    m.pressure / by,
    m.light / by};
}

measurement measure() {
  long w = safe_weight();
  int  m = analogRead(MOISTURE_PIN);
  //float  t = dht.readTemperature();
  //float  h = dht.readHumidity();
  int  l = analogRead(PHOTO_PIN);
  float t,h,pres;
  bme.read(pres, t, h);
  Serial.println(pres);
  unsigned long time = millis() / 1000;
  return measurement {time,w,m,t,h,pres,l};
}


#define MAXTRIES 3
#define MAXDELTAW 50

long safe_weight() {
  long w;
  for (int tries=0; tries < MAXTRIES; tries++) {
    w = weight.read_average(2);
    if (abs(weight_last - w) < MAXDELTAW) {
        break;
    } else {
      delay(100);
    }
  }
  weight_last = (w + 9 * weight_last) / 10;
  return w;
}