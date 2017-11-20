// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"
#include <math.h>

//BRANCH 3

#define  IMHT 64                  //image height in bits
#define  IMWD 64                  //image width in bits
#define  BYTEWIDTH 8              //image width in bytes
#define  WORKERS 3                //image width in bytes

typedef unsigned char uchar;      //using uchar as shorthand

port p_scl = XS1_PORT_1E;         //interface ports to orientation
port p_sda = XS1_PORT_1F;
port buttons = XS1_PORT_4E;
port LEDs = XS1_PORT_4F;

#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
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
//int showLEDs(out port p, chanend fromVisualiser) {
//  int pattern; //1st bit...separate green LED
//               //2nd bit...blue LED
//               //3rd bit...green LED
//               //4th bit...red LED
//  while (1) {
//    fromVisualiser :> pattern;   //receive new pattern from visualiser
//    p <: pattern;                //send pattern to LED port
//  }
//  return 0;
//}


//READ BUTTONS and send button pattern to userAnt
void buttonListener(in port b, chanend toDistributer) {
  int r;
  int exportNextIteration = 0;
  int start  = 0;
  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed

    if(r == 13 && start == 1)
    {
        printf("r = 13\n");
        toDistributer <: r;
        r = 0;
    }
    else if (r==14 && start == 0)                     // if sw1 is pressed, then r = 14               (sw2 is r = 13)
    {
        toDistributer <: r;
        r = 0;             // send button pattern to distributer
        start = 1;
    }
//    if(r == 13)    exportNextIteration = 1;
//    int iterationFinished = 0;
//    //Be notified when an iteration of game of life has finished. Notify DISTRIBUTER if the export button is pressed.
//    select
//          {
//              case toDistributer :> iterationFinished:
//                  printf("Recieved 1\n");
//                  printf("%d\n", r);
//                  if(exportNextIteration == 1)
//                  {
//                      printf("Exporting Iteration Button Pressed\n");
//                      toDistributer <: r;
//                      exportNextIteration == 0;
//                  }
//                  break;
//          }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend c_out)
{
  int res;
  uchar line[ IMWD ];
  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error openening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel c_out
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ ) {
      c_out <: line[ x ];
      //printf( "-%4.1d ", line[ x ] ); //show image values
    }
    //printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Takes a 3 by 3 array of bytes, and x and y coordinate of the desired bit.
// Returns the amount of 1's that surround the desired bit.
//
/////////////////////////////////////////////////////////////////////////////////////////
int countNeighbours(int x, int y, uchar matrix[3][3])
{
    int BYTEHEIGHT = 3;
    int BITWIDTH = 24;
    int count = 0;
    uchar mask;
    //Creates a for loop, from 2 -> 4, in order to select the desired row.
    for (int i = BYTEHEIGHT - 1; i < BYTEHEIGHT + 2; i++)
    {
        //Creates a for loop, from 23 -> 25, in order to select the desired column.
        for (int j = BITWIDTH - 1; j < BITWIDTH + 2; j++)
        {
            //Creates a bit mask, (E.G 2^3, is 0000 0100), of the relevant bit position.
            mask = (uchar)pow(2, (x+j)%8);
            //Match byte that desired bit is in, against the mask, this checks if nth bit is a 1 or not.
            if((matrix[(y + i) % BYTEHEIGHT][((x+j) % BITWIDTH)/8] & mask) == mask)
            {
                count++;
            }
        }
    }
    //If desired bit is a 1, it removes this. Previous for loop checks all neighbours and itself.
    mask = (uchar)pow(2, x%8);
    if((matrix[y][x/8]& mask) == mask ){
        count--;
    }
    return count;
}



//void gameOfLife(uchar matrix[IMHT][BYTEWIDTH])
//{
//    uchar mask;
//    uchar oldMatrix[IMHT][BYTEWIDTH];
//    for( int y = 0; y < IMHT; y++ ) {   //go through all lines
//          for( int x = 0; x < BYTEWIDTH; x++ )   oldMatrix[y][x] = matrix[y][x];
//    }
//
//    for(int y = 0; y < IMHT; y++ ) {   //go through all lines
//              for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
//                  int neighbourCount;
//                  neighbourCount = countNeighbours(x, y, oldMatrix);
//                  mask = (uchar) pow(2, x%8);
//                  if((oldMatrix[y][x/8] & mask) == mask){ // if alive
//                      if(neighbourCount != 2 && neighbourCount != 3) matrix[y][x/8] = matrix[y][x/8] ^ mask;
//                  }else{ // if dead
//                      if(neighbourCount == 3) matrix[y][x/8] = matrix[y][x/8] | mask;
//                  }
//              }
//        }
//}


/////////////////////////////////////////////////////////////////////////////////////////
//
// Print matrix bytes of height of image in bits, and width of image in bytes.
//
/////////////////////////////////////////////////////////////////////////////////////////
void printMatrix(uchar matrix[IMHT][BYTEWIDTH])
{
    for(int i = 0; i < IMHT; i++)
    {
        for(int j = 0; j < BYTEWIDTH; j++)    printf("%d ", matrix[i][j]);
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
void gameOfLifeV2(uchar matrix[3][3])
{
    //Copies previous matrix
    uchar mask;
    uchar oldMatrix[3][3];
    for( int y = 0; y < 3; y++ ) {
        for( int x = 0; x < 3; x++ )   oldMatrix[y][x] = matrix[y][x];
    }

    //Y is always equal to one as we are dealing with the middle byte.
    int y = 1;
    for( int x = 8; x < 16; x++ ) { //go through each pixel(8->16) in middle byte
          int neighbourCount;
          //Count neighhbours around the current bit.
          neighbourCount = countNeighbours(x, y, oldMatrix);
          //MASK SPECIFIES CORRECT BIT, IE 2^3 SPECIFIES 3rd bit 0000 0100
          mask = (uchar) pow(2, x-8);
          if((oldMatrix[y][1] & mask) == mask){ // if alive
              if(neighbourCount != 2 && neighbourCount != 3)    matrix[y][1] = matrix[y][1] ^ mask;
          }else{ // if dead
              if(neighbourCount == 3)    matrix[y][1] = matrix[y][1] | mask;
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
    //Initialise new array.
    for (int y = 0; y < IMHT; y++) {
            for (int x = 0; x < BYTEWIDTH; x++) {
                bits[y][x] = 0;
            }
        }
    //Go through each uchar in the old matrix
    for (int y = 0; y < IMHT; y++) {
        for (int x = 0; x < IMWD; x++) {
            //If uchar represents an alive pixel
            if (bytes[y][x] == 255) {
                //Then, using by using the OR bitwise operator we can append a bit into the new bit matrix.
                bits[y][x/8] = bits[y][x/8] | (uchar) pow(2, (x % 8));
            }
        }
    }

}


/////////////////////////////////////////////////////////////////////////////////////////
//
// Worker runs on a seperate channel, listens for 3 by 3 byte matrixes.
// Performs the game of life function on them.
// Sends the changed byte(1, 1) back to distributer.
//
/////////////////////////////////////////////////////////////////////////////////////////
 void worker(chanend toDistributer, int i)
{
    printf("WORKER %d STARTED\n", i);
    while (2==2) {
        uchar list[3][3];
        for( int x = 0; x < 3; x++ ) {
            for( int y = 0; y < 3; y++ ) {
                toDistributer :> list[y][x];
            }
        }

        gameOfLifeV2(list);
        toDistributer <: list[1][1];
   }

}


 /////////////////////////////////////////////////////////////////////////////////////////
 //
 // Takes in orginal matrix of pixels. Handles which workers get bytes.
 // Recompiles them into next iteration of matrix. Handles exporting of matrix.
 //
 /////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out, chanend fromAcc, chanend fromButton, chanend toWorkers[WORKERS]) {
  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for SW1 Button Press...\n" );


  fromButton :> int value;
  //fromAcc :> int value;

  printf( "Processing...\n" );
  uchar matrix[IMHT][IMWD];
  uchar list[IMHT][BYTEWIDTH];
  uchar list2[IMHT][BYTEWIDTH];

  /////////////////INPUT
  for( int y = 0; y < IMHT; y++ ) {
    for( int x = 0; x < IMWD; x++ ) {
      list2[y][x%BYTEWIDTH] = 0;
      c_in :> matrix[y][x];
    }
  }

  //Convert matrix to new matrix where bits represent pixels, instead of bytes.
  bytesToBits(matrix, list);


  //Loop indefinitely, next loop uncommented, as will change over next week.
  while(2 == 2)
  {
        int count = 0;
        int exportCurrent = 0;
        int exportMatrix = 0;
        int counts[WORKERS];
        int x, y;
        for(int workerN = 0; workerN < WORKERS; workerN++)
        {
            x = count % BYTEWIDTH;
            y = count / BYTEWIDTH;

            for(int k = BYTEWIDTH - 1; k < BYTEWIDTH + 2; k++)
            {

                  toWorkers[workerN] <: list[(y + IMHT - 1) % IMHT][(x+k) % BYTEWIDTH];
                  toWorkers[workerN] <: list[y][(x+k) % BYTEWIDTH];
                  toWorkers[workerN] <: list[(y + 1) % IMHT][(x+k) % BYTEWIDTH];
            }
            counts[workerN] = count++;
        }
      while (count < IMHT * BYTEWIDTH)
       {
           x = count % BYTEWIDTH;
           y = count / BYTEWIDTH;

           for (int workerN = 0; workerN < WORKERS && count < IMHT*BYTEWIDTH; workerN++)
           {
               select {
                         case fromButton :> exportMatrix:
                                  printf("Received from button\n");
                                  exportCurrent = 1;
                                  workerN--;
                                  break;
                         case toWorkers[workerN] :> list2[counts[workerN]/BYTEWIDTH][counts[workerN]%BYTEWIDTH]:
                               for(int k = BYTEWIDTH - 1; k < BYTEWIDTH + 2; k++)
                               {
                                   toWorkers[workerN] <: list[(IMHT + y - 1) % IMHT][(x+k) % BYTEWIDTH];
                                   toWorkers[workerN] <: list[y % IMHT][(x+k) % BYTEWIDTH];
                                   toWorkers[workerN] <: list[(y + 1) % IMHT][(x+k) % BYTEWIDTH];
                               }
                               counts[workerN] = count;
                               count++;
                               break;

               }
               x = count % BYTEWIDTH;
               y = count / BYTEWIDTH;
           }
       }

       for(int workerN = 0; workerN < WORKERS; workerN++)
       {
           select {
               case toWorkers[workerN] :> list2[counts[workerN]/BYTEWIDTH][counts[workerN]%BYTEWIDTH]:
                   break;
           }
       }
       printf("Iteration Complete\n");
       if(exportCurrent == 1)
       {
               /////////////////OUTPUT
               uchar mask;
               c_out <: 1;
               for( int y = 0; y < IMHT; y++ ) {
                    for( int x = 0; x < IMWD; x++ ) {
                        mask = (uchar)pow(2, x%8);
                        if((list2[y][x/8] & mask) == mask) c_out <: (uchar)0xff;
                        else c_out <: (uchar)0x00;
                    }
                }
       }
       for(int i = 0; i < IMHT; i++)
       {
           for(int j = 0; j < BYTEWIDTH; j++)
           {
               list[i][j] = list2[i][j];
           }
       }
       printf( "\nOne processing round completed...\n" );


  }

}




/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in)
{
  while(1)
  {
        c_in :> int value;
        int res;
        uchar line[ IMWD ];

        //Open PGM file
        printf( "DataOutStream: Start...\n" );
        res = _openoutpgm( outfname , IMWD, IMHT );
        if( res ) {
          printf( "DataOutStream: Error opening %s\n.", outfname );
          return;
        }

        //Compile each line of the image and write the image line-by-line
        for( int y = 0; y < IMHT; y++ ) {
          for( int x = 0; x < IMWD; x++ ) {
            c_in :> line[ x ];
          }
          _writeoutline( line, IMWD );
          printf( "DataOutStream: Line written...\n" );
        }

        //Close the PGM image
        _closeoutpgm();
        printf( "DataOutStream: Done...\n" );
  }

  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void orientation( client interface i2c_master_if i2c, chanend toDist) {
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

    //send signal to distributor after first tilt
    if (!tilted) {
      if (x>30) {
        tilted = 1 - tilted;
        //toDist <: 1;
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

i2c_master_if i2c[1];               //interface to orientation

char infname[] = "64x64.pgm";     //put your input image path here
char outfname[] = "testout.pgm"; //put your output image path here
chan c_inIO, c_outIO, c_control, buttonToDist;    //extend your channel definitions here
chan workers[WORKERS];

par {
    i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
    orientation(i2c[0],c_control);        //client thread reading orientation data
    DataInStream(infname, c_inIO);          //thread to read in a PGM image
    DataOutStream(outfname, c_outIO);       //thread to write out a PGM image
    distributor(c_inIO, c_outIO, c_control, buttonToDist, workers);//thread to coordinate work on image
    buttonListener(buttons, buttonToDist);
    worker(workers[0], 0);
    worker(workers[1], 1);
    worker(workers[2], 2);
  }

  return 0;
}
