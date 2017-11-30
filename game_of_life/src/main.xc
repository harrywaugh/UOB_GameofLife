
// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdlib.h>
#include "pgmIO.h"
#include "i2c.h"
#include <math.h>

#define IMHT 1024                  // Image height in bits
#define IMWD 1024                  // Image width in bits
#define BYTEWIDTH 128              // Image width in bytes (IMWD/8)
#define WORKERS 2                  // Number of workers
#define GENIMG 1                   // Whether or not random image will be generated

typedef unsigned char uchar;       // Using uchar as shorthand

on tile[0] : port p_scl = XS1_PORT_1E;         // Interface ports to orientation
on tile[0] : port p_sda = XS1_PORT_1F;
on tile[0] : port buttons = XS1_PORT_4E;       // Buttons port
on tile[0] : port LEDs = XS1_PORT_4F;          // Leds port

#define FXOS8700EQ_I2C_ADDR 0x1E  // Register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

// DISPLAYS an LED pattern
void showLEDs(out port p, chanend fromDistributer) {
  int pattern; // 1st bit...separate green LED
               // 2nd bit...blue LED
               // 3rd bit...green LED
               // 4th bit...red LED

  while (1) { //loop till shutdown
    fromDistributer :> pattern;   // receive new pattern from visualiser
    p <: pattern;                // send pattern to LED port
  }
}

// READ BUTTONS and send button pattern to userAnt
void buttonListener( in port b, chanend toDistributer) {
  int r; // value that button press is read into
  int start = 0; // whether or not the processing has started
  while (1) {
    b when pinseq(15) :> r; // Check that no button is pressed
    b when pinsneq(15) :> r; // Check if some buttons are pressed
    if (r == 13 && start == 1) { // If SW2 is pressed, and the game has started
      toDistributer <: r; // send 13 to the distributer
      r = 0; // set r back to 0 so that we do not read a button press twice
    } else if (r == 14 && start == 0) { // If sw1 is pressed, then r = 14 (sw2 is r = 13)
      toDistributer <: r; // send 14 to the distributer
      r = 0; // set r back to 0 so that we do not read a button press twice
      start = 1; // set start to 1 so this else if statement is never entered again
    }
  }
}

// Takes in an x and y coordinate of a pixel, a 2d array of uchars that the pixel is
// positioned in, and an array of uchars that represents the previous line
int countNeighbours(int x, int y, uchar matrix[IMHT/WORKERS + 2][BYTEWIDTH], uchar prevLine[BYTEWIDTH]) {
  int count = 0; // the number of neighbours
  uchar mask; // a value we will use to mask a byte and check the value of a single bit

  for (int j = x + IMWD - 1; j < x + IMWD + 2; j++) { // this iterates through all of the horizontal bits of the previous line
    mask = 1 << (j % 8); // this mask is used to find if a bit at the (j%8) position of the byte is a 1 or a 0
    if ((prevLine[(j % IMWD) / 8] & mask) == mask) { // this line checks if the cell is alive
      // our mask is a value of 8 bits with only one of them being a 1 e.g 00010000
      // when you AND a byte with this mask, if the bit in the byte at the correct position is a 1,
      // then the result will be the mask. e.g: 11010001 & 00010000 = 00010000
      // so if the byte ANDed with the mask is equal to the mask, then the cell is alive
      count++; // if the cell is alive, increment the number of neighbours
    }
  }

  for (int i = y; i < y + 2; i++) { // iterate through the line that the pixel is in, and the next line
    for (int j = x + IMWD - 1; j < x + IMWD + 2; j++) { // iterate through all of the horizontal bits of a line
      mask = 1 << (j % 8); // the comments in the loop above explain the masking process
      if ((matrix[i][(j % IMWD) / 8] & mask) == mask) { // this line checks if the cell is alive
        count++; // if the cell is alive, increment the number of neighbours
      }
    }
  }

  mask = 1 << (x % 8); // this time the mask uses x instead of j. This is because before j represented the x coordinate we were checking
  // but this time the cell we want to check is the actual cell itself
  if ((matrix[y][x / 8] & mask) == mask) { // check if the cell itself is alive
    count --; // if it is alive, then the loop above would have incremented the count when checking this cell,
    // so we decrement the count to account for this
  }

  return count; // return the number of neighbours
}

// gameOfLife takes a strip of the image and performs one iteration of
// the Game-of-Life on the given strip
void gameOfLife(uchar matrix[IMHT/WORKERS + 2][BYTEWIDTH]) {
  uchar mask; // a value we will use to mask a byte and check the value of a single bit
  uchar previousLine[BYTEWIDTH], currentLine[BYTEWIDTH]; // array of uchars that contain the previous line and current line to be processed

  for (int i = 0; i < BYTEWIDTH; i++) { // iterate through every byte in a row
    previousLine[i] = matrix[0][i]; // copy the first line of the matrix into previousLine
    currentLine[i] = matrix[1][i]; // copy the second line of the matrix into currentLine
  }

  for (int y = 1; y < IMHT/WORKERS + 1; y++) { // iterate through every row in the strip provided apart from the first and last, as these are not updated with this strip
    for (int x = 0; x < IMWD; x++) { // iterate through every pixel in a row
      int neighbourCount = countNeighbours(x, y, matrix, previousLine); // calculate the number of neighbours that the pixel at the current x and y has
      mask = 1 << (x % 8); // masking is explained in the count neighbours function
      if ((matrix[y][x/8] & mask) == mask) { // if the cell at the x and y position is alive
        if (neighbourCount != 2 && neighbourCount != 3) currentLine[x/8] = currentLine[x/8] ^ mask; // and if the neighbour count is not 2 or 3, then
        // XOR the byte that the cell is contained in, with the mask. This will kill the cell
        // e.g. 11111111 ^ 01000000 = 10111111
      } else { // if the cell is dead
        if (neighbourCount == 3) currentLine[x/8] = currentLine[x/8] | mask; // and if the neighbour count is exactly 3 then
        // OR the byte that the cell is contained in, with the mask. This will resurrect the cell
        // e.g. 00001111 | 01000000 = 01001111
      }
    }
    for (int i = 0; i < BYTEWIDTH; i++) { // iterate through every byte in a row
      previousLine[i] = matrix[y][i]; // copy the untouched line of the matrix to the previousLine to be used on in the next countNeighbours call
      matrix[y][i] = currentLine[i]; // copy the currentLine that was worked on to the updated matrix
      currentLine[i] = matrix[y+1][i]; // copy the next line to be worked on to currentLine
    }
  }

}

// This is a worker thread. Given a strip of the image, it will run gameOfLife on this strip, and will send back the
// updated bytes to the distributer.
void worker(chanend toDistributer, int i) {
  printf("WORKER %d STARTED\n", i);
  while (2 == 2) { // loop till shutdown
    uchar list[IMHT/WORKERS + 2][BYTEWIDTH]; // the strip of the image
    for (int x = 0; x < BYTEWIDTH; x++) { // iterate through every byte in a row
      for (int y = 0; y < IMHT/WORKERS + 2; y++) { // iterate through every row in the strip. Including the extra rows of bytes above and below
        toDistributer :> list[y][x]; // receive every byte in the strip from the distributer, and store it in the 2d list array
      }
    }
    gameOfLife(list); // run gameOfLife on the 2d array received from the distributer
    toDistributer <: 1; // when processing has finished, send the distributer a 1 to show that the worker is now ready to send the finished cells
    for (int x = 0; x < BYTEWIDTH; x++) { // iterate through every byte in a row
      for (int y = 1; y < IMHT/WORKERS + 1; y++) { // iterate through every row in the strip, apart from the extra rows of bytes at the top and bottom
        toDistributer <: list[y][x]; // send the finished bytes that contain the finished cells back
      }
    }
  }
}

// Recieve the bytes from the input channel, and store them in the 2d uchar of bytes provided
void inputImage(chanend input, uchar bytes[IMHT][BYTEWIDTH]) {
  for (int y = 0; y < IMHT; y++) { // iterate through every row of the image
    for (int x = 0; x < BYTEWIDTH; x++) { // iterate through every byte in a row
      input :> bytes[y][x]; // receive the bytes from the channel and place them into the correct position of the bytes array
    }
  }
}

// Initialise an array of bytes and set all the values to 0
void initialiseArray(uchar bits[IMHT][BYTEWIDTH]) {
  for (int y = 0; y < IMHT; y++) { // iterate through every row of the image
    for (int x = 0; x < BYTEWIDTH; x++) { // iterate through every byte in a row
      bits[y][x] = 0; // set the value to zero
    }
  }
}

// Send the bytes over the given output channel to DataOutStream
void outputImage(chanend output, uchar bits[IMHT][BYTEWIDTH]) {
  output <: 1; // send a 1 over the output channel to tell the DataOutStream that we are about to send byte values
  for (int y = 0; y < IMHT; y++) { // iterate through every row of the image
    for (int x = 0; x < BYTEWIDTH; x++) { // iterate through every byte in a row
      output <: bits[y][x]; // send the 'packed' bytes over the channel
    }
  }
}

// This sends bytes over the given channel to a worker
void sendBytes(chanend worker, int strip, uchar bits[IMHT][BYTEWIDTH]) {
  for (int x = 0; x < BYTEWIDTH; x++) { // iterate through every byte in a row
    for (int y = strip - 1; y < (strip + IMHT/WORKERS) + 1; y++) { // iterate through every row in a strip and the two extra rows above and below
      worker <: bits[(y + IMHT) % IMHT][x]; // send the values to the worker
    }
  }
}

// Calculate the number of live cells in an image
int calculateLiveCells(uchar bits[IMHT][BYTEWIDTH]) {
  int live = 0; // Count of live cells
  for (int y = 0; y < IMHT; y++) { // iterate through every row
    for (int x = 0; x < IMWD; x++) { // iterate through every byte in a row
      mask = 1 << (x % 8);
      if ((bits[y][x/8] & mask) == mask) { // if the cell is alive
        live++; // increment the counter of live cells
      }
    }
  }
  return live; // return the number of live cells
}

// Read Image from PGM file from the file name specified in pgmIO.c to channel c_out
void DataInStream(chanend c_out) {
  int res; // an error code recieved from _openinpgm
  uchar line[IMWD]; // an array of bytes with each byte representing one cell
  printf("DataInStream: Start...\n");

  if (GENIMG) { // if we would like to generate an image on the board rather than reading one in
    for (int i = 0; i < BYTEWIDTH; i++)  { // iterate through each byte in a 'packed' line
      for (int j = 0; j < IMHT; j++)  { // iterate through every row
        c_out <: ((uchar)(rand() % 256)); // generate a random byte and send it to the distributer
      }
    }
  } else {
    //Open PGM file
    res = _openinpgm(IMWD, IMHT);
    if (res) { // if error occurs
      printf("DataInStream: Error opening file\n");
      return;
    }

    uchar compressedBits; // value that each byte will be stored in temporarily

    //Read image line-by-line and send byte by byte to channel c_out
    for (int y = 0; y < IMHT; y++) { // iterate through each row in an image
      _readinline(line, IMWD); // read each row and store it in line
      for (int x = 0; x < BYTEWIDTH; x++) { // iterate through each byte in a row
        compressedBits = 0; // reset compressedBits back to 0
        for(int i = 0; i < 8; i++)  { // iterate through each bit in a byte
          if (line[x*8 + i] == 255) { // if the cell is alive
            compressedBits = compressedBits | (1 << (i % 8)); // then, using by using the OR bitwise operator we can append a bit into the new bit matrix
          }
        }
        c_out <: compressedBits; // send the read in 'packed' bytes to the distributer

      }
    }
    //Close PGM image file
    _closeinpgm();
  }

  printf("DataInStream: Done...\n");
  return;
}

// simple function that compares two values
int lessThan(int val1, int val2) {
  if (val1 < val2) { // if val1 is less than val2
    return 1; // return 1
  }
  return 0; // otherwise return 0
}

// Takes in orginal matrix of pixels. Handles which workers get bytes.
// Recompiles them into next iteration of matrix. Handles exporting of matrix.
void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend fromButton, chanend toLEDs, chanend toWorkers[WORKERS]) {
  //Starting up and wait for tilting of the xCore-200 Explorer
  printf("ProcessImage: Start, size = %dx%d\n", IMHT, IMWD);
  printf("Waiting for SW1 Button Press...\n");

  fromButton :> int value;

  printf("Processing...\n");
  uchar initialBits[IMHT][BYTEWIDTH];

  initialiseArray(initialBits);

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
      if(lessThan(currentTime, previousTime))  {
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
              printf("Rounds processed so far: %d\n", iteration);
              printf("Current live cells: %d\n", calculateLiveCells(initialBits));

              previousTime = currentTime;
              currentTime = timePaused - time;
              if(lessThan(currentTime, previousTime)) {
                timeOverflows++;
                previousTime = currentTime;
              }
              double seconds = round(timeOverflows*(4294967295/100000) + currentTime/100000 - totalPausedTime/100000)/1000 ;
              printf("Time elapsed so far: %.2f\n", seconds);
              fromAcc :> tilted;
              tmr :> timeElapsed;
              totalPausedTime += timeElapsed - timePaused; // cant we say currentTime -= (timeElapsed - timePaused) and then we
              // dont have to print currentTime - totalPaused time, we just print current time

              printf("Resuming...\n");
              toLEDs <: pattern;
            }
            w--;
            break;
          case toWorkers[w] :> int received:
            for (short x = 0; x < BYTEWIDTH; x++) {
              for (short y = w*(IMHT/WORKERS); y < (w+1)*(IMHT/WORKERS); y++) {
                toWorkers[w] :> initialBits[y][x];
              }
            }
            stripsComplete++;
            break;
          default:
            tmr :> timeElapsed;
            previousTime = currentTime;
            currentTime = timeElapsed - time;
            if(lessThan(currentTime, previousTime))  timeOverflows++;
            break;
        }
      }
    }
    if(iteration == 99 )  {
      printf("Paused...\n");
                    tmr :> timeElapsed;
                    uint32_t timePaused = timeElapsed;
                    toLEDs <: 8;
                    printf("Rounds processed so far: %d\n", iteration);
                    printf("Current live cells: %d\n", calculateLiveCells(initialBits));

                    previousTime = currentTime;
                    currentTime = timePaused - time;
                    if(lessThan(currentTime, previousTime)) {
                      timeOverflows++;
                      previousTime = currentTime;
                    }
                    double seconds = round(timeOverflows*(4294967295/100000) + currentTime/100000 - totalPausedTime/100000)/1000 ;
                    printf("Time elapsed so far: %.2f\n", seconds);
                    fromAcc :> int tilted;
                    tmr :> timeElapsed;
                    totalPausedTime += timeElapsed - timePaused;

                    printf("Resuming...\n");
                    toLEDs <: pattern;
      printf("The time for 100 iterations is %d\n", seconds);
    }

    if (exportCurrent) {
      tmr :> timeElapsed;
      uint32_t timePaused = timeElapsed;
      previousTime = currentTime;
      currentTime = timePaused - time;
      if(lessThan(currentTime, previousTime)) {
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
    //printf("Processing round completed...%d\n", iteration);
    iteration++;
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(chanend c_in) {
  int i = 0;
  while (1) {
    c_in :> int value;
    i++;
    int res;
    uchar line[IMWD];

    //Open PGM file
    printf("DataOutStream: Start...\n");
    char *fname = "testout0.pgm";
    fname[7] = i++;
    res = _openoutpgm(IMWD, IMHT, fname);
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

// Initialise and  read orientation, send first tilt event to channel
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

// Orchestrate concurrent system and start up all threads
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
