#include "Arduino.h"

#include "HX711.h"
#include "DHT.h"

#define LOADCELL_DOUT_PIN 4
#define LOADCELL_SCK_PIN 12

#define DHTTYPE DHT22
#define DHTPIN 5

#define MOISTURE_PIN A0
#define PHOTO_PIN A2

HX711 weight;
DHT dht(DHTPIN, DHTTYPE);

struct measurement {
  unsigned long time;
  float weight; // 2,147,483,647 / 60,000 =  30000
  float moisture;
  float temp;
  float humidity;
  float light;
};

struct compressed {
  unsigned long time;
  int weight;
  byte moisture;
  byte temp;
  //#byte humidity;
  byte light; 
};

void setup_measurement();
compressed compress(measurement);
measurement uncompress(compressed);
void print(measurement);
measurement add(measurement, measurement);
measurement mult(measurement, float);
measurement measure();