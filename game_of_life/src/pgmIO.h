#ifndef PGMIO_H_
#define PGMIO_H_

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

int _writepgm(unsigned char x[], int height, int width, char fname[]);
int _readpgm(unsigned char x[], int height, int width, char fname[]);

int _openinpgm(int width, int height);
int _readinline(unsigned char line[], int width);
int _closeinpgm();

int _openoutpgm(int width, int height, char outfname[12]);
int _writeoutline(unsigned char line[], int width);
int _closeoutpgm();

#endif /*PGMIO_H_*/
