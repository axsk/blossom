
#include "HX711.h"
#include "DHT.h"

const int STATUS_LED = 13;

const int LOADCELL_DOUT_PIN = 4;
const int LOADCELL_SCK_PIN = 12;
#define MOISTURE_PIN A0
#define DHTTYPE DHT22
#define DHTPIN 5
#define PHOTO_PIN A2

HX711 weight;
DHT dht(DHTPIN, DHTTYPE);

const unsigned long interval = (long) 1000 * 60 * 30;
#define NMEAS 80

typedef struct mstruct {
  unsigned int time;
  byte weight;
  byte moisture;
  byte temp;
  byte humidity;
  byte light;
} Measurement;

Measurement measure() {
  long w = weight.read();
  int m = analogRead(MOISTURE_PIN);
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  int l = analogRead(PHOTO_PIN);
  unsigned long time = millis() / interval;
  Serial.print("weight=");
  Serial.println(w);
  Serial.print("moisture=");
  Serial.println(m);
  Serial.print("temp=");
  Serial.println(t);
  Serial.print("hum=");
  Serial.println(h);
  Serial.print("light=");
  Serial.println(l);
  Serial.print("time=");
  Serial.println(time);
  Serial.println("-");
  return Measurement {time,w / 8,m/4,t*8,h*100,l/4};
}

long nmeas = 0;

Measurement meas_mem[NMEAS];

void setup() {
  Serial.begin(115200);
  weight.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  pinMode(STATUS_LED, OUTPUT);
  dht.begin();
  Serial.println("booted");
}

void printmem() {
    for (int i = 0; i<min(NMEAS, nmeas); i++) {
      Serial.print("t=");
      Serial.print(meas_mem[i].time);
      Serial.print(" weight=");
      Serial.print(meas_mem[i].weight);
      Serial.print(" moist=");
      Serial.print(meas_mem[i].moisture);
      Serial.print(" temp=");
      Serial.print(meas_mem[i].temp);
      Serial.print(" hum=");
      Serial.print(meas_mem[i].humidity);
      Serial.print(" light=");
      Serial.print(meas_mem[i].light);
      Serial.println("-");
    }
}


void loop() {

  

  if (Serial.available()) {
    Serial.print("data requested ");
    delay(100); //wait for data to arrive
    do {
      Serial.read();
      Serial.print(".");
    } while ( Serial.available() );
    Serial.println();

    Serial.print("interval (s)=");
    Serial.println(interval / 1000);
    printmem();
    Serial.println("-");
    
  }  

  unsigned long time = millis();

  if (time > interval * nmeas) {
    Serial.print("measurement "); Serial.println(nmeas);
    meas_mem[nmeas % NMEAS] = measure();
    nmeas++;
    digitalWrite(STATUS_LED, HIGH);
    delay(100);
    digitalWrite(STATUS_LED, LOW);
  }
}