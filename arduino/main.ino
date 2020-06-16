#include "HX711.h"
#include "DHT.h"
#include "measure.h"

#include <avr/wdt.h>

#define STATUS_LED 13

#define MEMSIZE 80

const unsigned long interval = 1000;
#define SAVEEVERY_START 5
unsigned long saveevery = SAVEEVERY_START;

int memadr = 0;
unsigned long nmeas = 0;
unsigned int navg = 0;
bool logmeas = true;
bool logavg  = false;

compressed meas_mem[MEMSIZE];
measurement meas_avg = {0,0,0,0,0,0};

void setup() {
  Serial.begin(115200);
  pinMode(STATUS_LED, OUTPUT);
  setup_measurement();
  Serial.println("booted");

}
void reset() {
  wdt_enable(WDTO_15MS);
}

void loop() {
  char lastchar = 255;
  while (Serial.available()) {
    lastchar = Serial.read();
  }
  switch (lastchar) {
    //case 0x00:
      //reset();
    case 1:
      request();
    //case 2:
    //  logmeas = false;
    //case 3:
    //  logmeas = true;
    //case 4:
    //  logavg = true;
    //case 5:
      //logavg = false;
  }

  unsigned long time = millis();

  if (time > interval * nmeas) {
    // measure and add to average
    measurement meas = measure();
    meas_avg = add(meas_avg, meas);
    nmeas++;
    navg++;

    if (logmeas) {
      print(meas);
    }

    // write to memory
    if (nmeas % saveevery == 0) {

      meas_avg = div(meas_avg, navg);
      navg = 0;

      if (logavg) { 
        Serial.print(saveevery);
        Serial.print(" average: ");
        print(meas_avg);
      }      

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

      digitalWrite(STATUS_LED, HIGH); delay(10); 
      digitalWrite(STATUS_LED, LOW);  delay(90);
    }
  }
}

void request() {
  Serial.print("time=");
  Serial.println(millis()/1000);
  Serial.println("-");
  printmem();
}

void printmem() {
    for (int i = 0; i<min(MEMSIZE, (nmeas / SAVEEVERY_START)); i++) {
      print(uncompress(meas_mem[i]));
    }
}