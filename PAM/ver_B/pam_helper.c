/* [BSD-3 Clause] 
 * Copyright 2017 Eliot Roxbergh, Adam Fredriksson
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 */

#include <time.h>
#include <openssl/rand.h>
#include <unistd.h>
#include "header.h"

/*
 * using global variables:
 *  static const int cleartextLen
 *  unsigned char randData_orig[(CLEARTEXT_LEN+1)];		
 */
unsigned char* genNumber_raw(void) {
	//half size cleartextLen since different data per printable char
	//data (8bit) , hex (4bit) per visable char for user
	unsigned char* randData  =  malloc(cleartextLen+1);
	
	//randData fills with random data
	while(RAND_bytes(randData, (cleartextLen)) != 1 ){
		//RAND_bytes failed (UNLIKELY!)
		fprintf(stderr,"\nRandom data generation fail!\n");
		sleep(1); //second
		fprintf(stderr,"Retrying..\n");
		sleep(1);
	}

	//null terminate
	randData[cleartextLen] = '\0';	
	
	//by default cleartext 63 len out of 64 possible
	// shift right one char, add 0 left-most
	unsigned char *randDataShifted = malloc(cleartextLen+2);
	randDataShifted[0] = 0;	
	int i;
	for (i = 0; i < cleartextLen+1; i++) {
	  randDataShifted[i+1] = randData[i];
	}

	free(randData);
	
	//not reversed, randData_orig used for local verify later
	memcpy(randData_orig, randDataShifted, (cleartextLen+2));

	//FPGA wants reversed
	reverseStr(randDataShifted);
	return randDataShifted;
}

unsigned char* reverseStr(unsigned char* input) {
  int len = cleartextLen+1;
  unsigned char temp;
  int i;
  for (i = 0; i < len/2; i++) {
    temp = input[i];
    input[i] = input[len-1-i];
    input[len-1-i] = temp;
  }
  return input;
}

