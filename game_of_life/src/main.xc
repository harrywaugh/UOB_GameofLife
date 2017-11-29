// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include "pgmIO.h"
#include "i2c.h"
#include <math.h>


#define IMHT 1024                  //Image height in bits
#define IMWD 1024                   //Image width in bits
#define BYTEWIDTH 128              //Image width in bytes
#define WORKERS 4                 //Number of workers(MUST BE 11 OR LESS)
#define WORKERS2 3                //(MUST BE LESS THAN 4)
#define GENIMG 0


typedef unsigned char uchar;      //Using uchar as shorthand

on tile[0] : port p_scl = XS1_PORT_1E;         //Interface ports to orientation
on tile[0] : port p_sda = XS1_PORT_1F;
on tile[0] : port buttons = XS1_PORT_4E;       //Buttons port
on tile[0] : port LEDs = XS1_PORT_4F;          //Leds port

#define FXOS8700EQ_I2C_ADDR 0x1E  //Register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

//DISPLAYS an LED pattern
int showLEDs(out port p, chanend fromDistributer) {
  int pattern; //1st bit...separate green LED
               //2nd bit...blue LED
               //3rd bit...green LED
               //4th bit...red LED

  // 1 = just sep green LED
  // 2 = just blue LED
  // 3 = sep green and blue LED
  // 4 = just green LED
  // 5 = green and sep green LED
  // 6 = green and blue LED
  // 7 = green and blue and sep green LED
  // 8 = red LED

  while (1) {
    fromDistributer :> pattern;   //receive new pattern from visualiser
    p <: pattern;                //send pattern to LED port
  }
  return 0;
}

//READ BUTTONS and send button pattern to userAnt
void buttonListener( in port b, chanend toDistributer) {
  int r;
  int start = 0;
  while (1) {
    b when pinseq(15) :> r; //Check that no button is pressed
    b when pinsneq(15) :> r; //Check if some buttons are pressed
    if (r == 13 && start == 1) { //If SW2 is pressed, and the game has started
      toDistributer <: r;
      r = 0;
    } else if (r == 14 && start == 0) { //If sw1 is pressed, then r = 14 (sw2 is r = 13)
      toDistributer <: r;
      r = 0; //Send button pattern to distributer
      start = 1;
    }
  }
}

void generateStartImage(uchar bits[IMHT][BYTEWIDTH])  {
  for (int i = 0; i < BYTEWIDTH; i++)  {
    for (int j = 0; j < IMHT; j++)  {
      bits[j][i] = (rand() % 256);
    }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Takes a 3 by 3 array of bytes, and x and y coordinate of the desired bit.
// Returns the amount of 1's that surround the desired bit.
//
/////////////////////////////////////////////////////////////////////////////////////////


int countNeighbours(int x, int y, uchar matrix[IMHT/WORKERS + 2][BYTEWIDTH]) {
  //int BYTEHEIGHT = IMHT/WORKERS + 2;
  int BITWIDTH = IMWD;
  int count = 0;
  uchar mask;

  for (int i = y - 1; i < y + 2; i++) {
    for (int j = x + BITWIDTH - 1; j < x + BITWIDTH + 2; j++) {
      mask = 1 << (j % 8);
      //if ((matrix[y + i][((x + j) % BITWIDTH) / 8] >> ((x+j)%8))) {}
      if ((matrix[i][(j % BITWIDTH) / 8] & mask) == mask) {
        count++;
      }
    }
  }

  mask = 1 << (x % 8);
  if ((matrix[y][x / 8] & mask) == mask) {
    count --;
  }

  return count;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Print matrix bytes of height of image in bits, and width of image in bytes.
//
/////////////////////////////////////////////////////////////////////////////////////////
void printMatrix(uchar matrix[IMHT][BYTEWIDTH]) {
  for (int i = 0; i < IMHT; i++) {
    for (int j = 0; j < BYTEWIDTH; j++) printf("%d ", matrix[i][j]);
    printf("\n");
  }
  printf("\n");
}

/////////////////////////////////////////////////////////////////////////////////////////
//
//GameOfLife, takes a 3 by 3 matrix of bytes.
//Performs one iteration of Game of life on the middle byte of the matrix.
//
/////////////////////////////////////////////////////////////////////////////////////////



void gameOfLife(uchar matrix[IMHT/WORKERS + 2][BYTEWIDTH]) {
  uchar mask;
  uchar oldMatrix[IMHT/WORKERS + 2][BYTEWIDTH];
  for (int y = 0; y < IMHT/WORKERS + 2; y++)  {
    for (int x = 0; x < BYTEWIDTH; x++)  {
      oldMatrix[y][x] = matrix[y][x];
    }
  }

  for (int y = 1; y < IMHT/WORKERS + 1; y++) {
    for (int x = 0; x < IMWD; x++) {
      int neighbourCount = countNeighbours(x, y, oldMatrix);
      mask = (uchar) pow(2, x % 8);
      //mask = 1 << (x % 8);
      if ((oldMatrix[y][x/8] & mask) == mask) { // if alive
        if (neighbourCount != 2 && neighbourCount != 3) matrix[y][x/8] = matrix[y][x/8] ^ mask;
      } else { // if dead
        if (neighbourCount == 3) matrix[y][x/8] = matrix[y][x/8] | mask;
      }
    }
  }

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Converts the given matrix of uchars, where each uchar is either 255 or 0
// to a matrix of uchars, where each byte stores 8 of the previous matrixes uchars.
// Now each pxixel in the image is represented by a single bit.
//
/////////////////////////////////////////////////////////////////////////////////////////
void bytesToBits(uchar bytes[IMHT][IMWD], uchar bits[IMHT][BYTEWIDTH]) {

  //Go through each uchar in the old matrix
  for (int y = 0; y < IMHT; y++) {
    for (int x = 0; x < IMWD; x++) {
      //If uchar represents an alive pixel
      if (bytes[y][x] == 255) {
        //Then, using by using the OR bitwise operator we can append a bit into the new bit matrix.
        bits[y][x / 8] = bits[y][x / 8] | (uchar) pow(2, (x % 8));
      }
    }
  }
}



void worker(chanend toDistributer, int i) {
  printf("WORKER %d STARTED\n", i);
  while (2 == 2) {
    uchar list[IMHT/WORKERS + 2][BYTEWIDTH];
    for (int x = 0; x < BYTEWIDTH; x++) {
      for (int y = 0; y < IMHT/WORKERS + 2; y++) {
        toDistributer :> list[y][x];
        //printf("%d ", list[y][x]);
      }
    }
    gameOfLife(list);
    toDistributer <: 1;
    for (int x = 0; x < BYTEWIDTH; x++) {
      for (int y = 1; y < IMHT/WORKERS + 1; y++) {
        toDistributer <: list[y][x];
      }
    }
  }
}

void inputImage(chanend input, uchar bytes[IMHT][BYTEWIDTH]) {
  for (int y = 0; y < IMHT; y++) {
    for (int x = 0; x < BYTEWIDTH; x++) {
      input :> bytes[y][x];
    }
  }
}

void initialiseBitsArray(uchar bits[IMHT][BYTEWIDTH]) {
  for (int y = 0; y < IMHT; y++) {
    for (int x = 0; x < BYTEWIDTH; x++) {
      bits[y][x] = 0;
    }
  }
}

void outputImage(chanend output, uchar bits[IMHT][BYTEWIDTH]) {
  output <: 1;
  for (int y = 0; y < IMHT; y++) {
    for (int x = 0; x < BYTEWIDTH; x++) {
      output <: bits[y][x];
    }
  }
}


void sendBytes(chanend worker, int strip, uchar bits[IMHT][BYTEWIDTH]) {
  for (int x = 0; x < BYTEWIDTH; x++) {
    for (int y = strip - 1; y < (strip + IMHT/WORKERS) + 1; y++) {
      worker <: bits[(y + IMHT) % IMHT][x];
    }
  }
}

int getXfromCount(int count) { return count % BYTEWIDTH; }

int getYfromCount(int count) { return count / BYTEWIDTH; }

int calculateLiveCells(uchar bits[IMHT][BYTEWIDTH]) {
  int live = 0;
  for (int y = 0; y < IMHT; y++) {
    for (int x = 0; x < IMWD; x++) {
      if ((bits[y][x/8] >> (x%8)) & 1) { // if alive
        live++;
      }
    }
  }
  return live;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Takes in orginal matrix of pixels. Handles which workers get bytes.
// Recompiles them into next iteration of matrix. Handles exporting of matrix.
//
/////////////////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(chanend c_out) {
  int res;
  uchar line[IMWD];
  printf("DataInStream: Start...\n");

  uchar bits[IMHT][BYTEWIDTH];
  //Initialise arrays.
  initialiseBitsArray(bits);

  if (GENIMG) {
    generateStartImage(bits);
  } else {
    //Open PGM file
    res = _openinpgm(IMWD, IMHT);
    if (res) {
      printf("DataInStream: Error opening file\n");
      return;
    }

    //Read image line-by-line and send byte by byte to channel c_out
    for (int y = 0; y < IMHT; y++) {
      _readinline(line, IMWD);
      for (int x = 0; x < IMWD; x++) {
        //matrix[y][x] = line[x];
        if (line[x] == 255) {
          //Then, using by using the OR bitwise operator we can append a bit into the new bit matrix.
          bits[y][x / 8] = bits[y][x / 8] | (1 << (x % 8));
        }
      }
    }
    //Close PGM image file
    _closeinpgm();
  }


  for (int i = 0; i < IMHT; i++)  {
    for (int j = 0; j < BYTEWIDTH; j++)  {
      c_out <: bits[i][j];
    }
  }

  printf("DataInStream: Done...\n");
  return;
}

int checkOverflow(int time1, int time2)  {
  if(time1 < time2)  {
    return 1;
  }
  return 0;
}

void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend fromButton, chanend toLEDs, chanend toWorkers[WORKERS]) {
  //Starting up and wait for tilting of the xCore-200 Explorer
  printf("ProcessImage: Start, size = %dx%d\n", IMHT, IMWD);
  printf("Waiting for SW1 Button Press...\n");

  fromButton :> int value;

  printf("Processing...\n");
  uchar initialBits[IMHT][BYTEWIDTH];

  initialiseBitsArray(initialBits);

  toLEDs <: 4;
  inputImage(c_in, initialBits);
  toLEDs <: 0;


  int iteration = 0;
  int exportCurrent = 0;
  int stripsComplete = 0;

  int pattern = 1;
  int timeOverflows = 0;
  timer tmr;
  uint32_t timeElapsed;
  uint32_t time;
  tmr :> time;
  int currentTime = 0;
  int previousTime = -1;
  uint32_t totalPausedTime = 0;


  while (2 == 2)  {
    stripsComplete = 0;
    exportCurrent = 0;

    for (int w = 0;  w < WORKERS; w++)  {
      sendBytes(toWorkers[w], w*(IMHT/WORKERS), initialBits);
      tmr :> timeElapsed;
      previousTime = currentTime;
      currentTime = timeElapsed - time;
      if(checkOverflow(currentTime, previousTime))  {
        timeOverflows++;
        previousTime = currentTime;
      }
    }
    while (stripsComplete < WORKERS)  {
      for(int w = 0; w < WORKERS; w++)  {
        select {
          case fromButton :> exportCurrent:
            printf("Export button pressed.\n");
            w--;
            break;
          case fromAcc :> int tilted:
            //printf("recieved tilt value %d\n", tilted);
            if (tilted == 1) {
              printf("Paused...\n");
              tmr :> timeElapsed;
              uint32_t timePaused = timeElapsed;
              toLEDs <: 8;
              printf("Rounds processed so far: %d\n", iteration-1);
              printf("Current live cells: %d\n", calculateLiveCells(initialBits));

              previousTime = currentTime;
              currentTime = timePaused - time;
              if(checkOverflow(currentTime, previousTime)) {
                timeOverflows++;
                previousTime = currentTime;
              }
              double seconds = round(timeOverflows*(4294967295/100000) + currentTime/100000 - totalPausedTime/100000)/1000 ;
              printf("Time elapsed so far: %.2f\n", seconds);
              fromAcc :> tilted;
              tmr :> timeElapsed;
              totalPausedTime += timeElapsed - timePaused;

              printf("Resuming...\n");
              toLEDs <: pattern;
            }
            w--;
            break;
          case toWorkers[w] :> int received:
            for (int x = 0; x < BYTEWIDTH; x++) {
              for (int y = w*(IMHT/WORKERS); y < (w+1)*(IMHT/WORKERS); y++) {
                toWorkers[w] :> initialBits[y][x];
              }
            }
            stripsComplete++;
            break;
          default:
            tmr :> timeElapsed;
            previousTime = currentTime;
            currentTime = timeElapsed - time;
            if(checkOverflow(currentTime, previousTime))  timeOverflows++;
            break;
        }
      }
    }
    if (exportCurrent == 13 || iteration == 0) {
      tmr :> timeElapsed;
      uint32_t timePaused = timeElapsed;
      previousTime = currentTime;
      currentTime = timePaused - time;
      if(checkOverflow(currentTime, previousTime)) {
        timeOverflows++;
        previousTime = currentTime;
      }
      toLEDs <: 2;
      outputImage(c_out, initialBits);
      toLEDs <: pattern;
      tmr :> timeElapsed;
      totalPausedTime += timeElapsed - timePaused;
    }


    if (iteration % 2 == 0) pattern = 1;
    else pattern = 0;

    toLEDs <: pattern;
    iteration++;
    //printf("Processing round completed...%d\n", iteration);
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(chanend c_in) {
  while (1) {
    c_in :> int value;
    int res;
    uchar line[IMWD];

    //Open PGM file
    printf("DataOutStream: Start...\n");
    res = _openoutpgm(IMWD, IMHT);
    if (res) {
      printf("DataOutStream: Error opening file\n");
      return;
    }
    uchar compressedByte = 0;
    //Compile each line of the image and write the image line-by-line
    for (int y = 0; y < IMHT; y++) {
      for (int x = 0; x < BYTEWIDTH; x++) {

        c_in :> compressedByte;
        for(int i = 0; i < 8; i++)  {
          if((compressedByte >> i) & 1)  {
            line[x*8 + i] = 255;
          } else {
            line[x*8 + i] = 0;
          }
        }
      }
      _writeoutline(line, IMWD);
      if (!(y % 5))
          printf("DataOutStream: Line %d written\n ", y);
    }

    //Close the PGM image
    _closeoutpgm();
    printf("\nDataOutStream: Done...\n");
  }

  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void orientation(client interface i2c_master_if i2c, chanend toDist) {
  i2c_regop_res_t result;
  char status_data = 0;
  int tilted = 0;

  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  //Probe the orientation x-axis forever
  while (1) {
    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    if (!tilted) {
      if (x > 30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
    } else {
      if (x <= 30) {
        tilted = 1 - tilted;
        toDist <: 0;
      }
    }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {
  i2c_master_if i2c[1]; //interface to orientation
  chan c_inIO, c_outIO, c_control, buttonToDist, distToLED; //extend your channel definitions here
  chan workers[WORKERS];
  par {
    on tile[0] : i2c_master(i2c, 1, p_scl, p_sda, 10); //server thread providing orientation data
    on tile[0] : orientation(i2c[0], c_control); //client thread reading orientation data
    on tile[0] : DataInStream(c_inIO); //thread to read in a PGM image
    on tile[0] : DataOutStream(c_outIO); //thread to write out a PGM image
    on tile[0] : distributor(c_inIO, c_outIO, c_control, buttonToDist, distToLED, workers); //thread to coordinate work on image
    on tile[0] : buttonListener(buttons, buttonToDist);
    on tile[0] : showLEDs(LEDs, distToLED);
    par (int i = 0; i < WORKERS; i++)  {
      on tile[1] : worker(workers[i], i);
    }
//    par (int j = WORKERS-WORKERS2; j < WORKERS; j++)  {
//      on tile[0] : worker(workers[j], j);
//    }
  }
  return 0;
}
