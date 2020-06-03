
#include "HX711.h"
#include "DHT.h"
#include "measure.h"

#define STATUS_LED 13

#define MEMSIZE 128

const unsigned long interval = 7500;
#define SAVEEVERY_START 1
unsigned long saveevery = SAVEEVERY_START;

int memadr = 0;
unsigned long nmeas = 0;

compressed meas_mem[MEMSIZE];
measurement meas_avg = {0,0,0,0,0,0};

void setup() {
  Serial.begin(115200);
  pinMode(STATUS_LED, OUTPUT);
  setup_measurement();
  Serial.println("booted");
}

void loop() {
  if (Serial.available()) {
    requestdata();
  }  

  unsigned long time = millis();

  if (time > interval * nmeas) {
    // measure and add to average
    measurement meas = measure();
    meas_avg = add(meas_avg, meas);
    nmeas++;

    print(meas);

    // write to memory
    if (nmeas % saveevery == 0) {

      // compute the average
      meas_avg = div(meas_avg, saveevery);
      // print(meas_avg);

      // write to memory
      meas_mem[memadr] = compress(meas_avg);

      meas_avg = {0,0,0,0,0,0};
      memadr++;

      if (memadr == MEMSIZE) {
        saveevery = saveevery * 2;
        for (int i = 0; i<MEMSIZE/2; i++) {
          meas_mem[i] = compress(div(add(uncompress(meas_mem[i*2]), uncompress(meas_mem[i*2 + 1])),2));
        }
        memadr = MEMSIZE/2;
      }
    }
    digitalWrite(STATUS_LED, HIGH); delay(10); 
    digitalWrite(STATUS_LED, LOW);  delay(90);
  }
}

void requestdata() {
  Serial.print("data requested ");
  delay(10); //wait for data to arrive
  do {
    Serial.read();
    Serial.print(".");
  } while ( Serial.available() );
  Serial.println();

  Serial.print("time=");
  Serial.println(millis());
  Serial.println("-");
  printmem();
}

void printmem() {
    for (int i = 0; i<min(MEMSIZE, (nmeas / SAVEEVERY_START)); i++) {
      print(uncompress(meas_mem[i]));
    }
}