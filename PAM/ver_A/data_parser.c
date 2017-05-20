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

#include <math.h>
#include <gmp.h>
#include "header.h"
#include <stdbool.h>

/*  ascii_parser recieves input (chars from device) and encodes to binary 6-bit blocks
 *  returns string with 1s and 0s */
char* ascii_parser(char* input) {
  char c = input[0];
  char* parsedInput = malloc(ciphertextLen+1);
  char* parsedBinInput = malloc(ciphertextLen*6+1);
  int i = 0;
  
  while (c != '\0') {
    //printf("%c\n", c);
    if (c >= '0' && c <= '9') {
      c = c - 48;
    } else if (c >= 'A' && c <= 'Z') {
      c = c - 55;
    } else if (c >= 'a' && c <= 'z') {
      c = c - 60;
    } else if (c == '!') {
      c = 36;
    } else {
      c = 63;
    } 
    parsedInput[i] = c;
    int k;
    int l = 0;

    /*
      "Convert" to binary repr of the string, temp is ANDed
      with 1 leftshifted by k steps and set to '1' or '0'.
    */
    for (k = 5; k >= 0; k--) {
      parsedBinInput[i*6 + l] = ( (c & (1 << k)) ? '1' : '0');
      l++;
    }

    i++;
    c = input[i];
  }
  free(parsedInput);
  parsedBinInput[ciphertextLen*6] = '\0';
	return parsedBinInput;
}


unsigned char* binToChar(char* dataBinary){
	int dataSize = strlen(dataBinary);
	unsigned char *dataChar = malloc(dataSize/8);
	
	//outer loop, for each block (8 bit)
	int block, bit;	
	for(block=0; block<(dataSize/8); block++){
		int tmp = 0;

		//inner loop every bit in block (0 to 7)
		for(bit=0; bit<8; bit++){
		  
			if( dataBinary[bit+8*block] == '\0'){
				break;
			}
			// binary '1' to int (2^n)
			if(dataBinary[bit+8*block] == '1' ){
				tmp = tmp + (int) pow(2, 7-bit);
			}
		} //end of inner loop

		//save completed block total
		dataChar[block] =(char) tmp; 
	} //end of outer loop

	return(dataChar);
}

char* hexToAscii(char* input) {
  int i;
  char c;
  char* randDataAscii = malloc(cleartextLen+1);
  for (i = 0; i < cleartextLen; i++) {
    c = input[i];
    if (c >= 0 && c <= 9) {
      randDataAscii[i] = c + 48;
    } else if (c >= 10 && c <= 15) {
      randDataAscii[i] = c + 55;
    } else {
			// ERROR, should never be here
    	//TODO cast error? return PAM fail?
		}
  }

  randDataAscii[cleartextLen] = '\0';
  return randDataAscii;
}

char* strSanitizer_unsafe(char* userInput) {
  char* strSanitized = malloc(cleartextLen+1);
  int len = strlen(userInput);

  if (len < cleartextLen) {
    int i;
    for (i = 0; i < cleartextLen-len; i++) {
      strSanitized[i] = '0';
    }
    for (i = cleartextLen-len; i < cleartextLen; i++) {
      strSanitized[i] = userInput[i-cleartextLen-len];
    }
    strSanitized[cleartextLen] = '\0';
    return strSanitized;
  } else if (len > cleartextLen) {
    userInput[cleartextLen] = '\0';
  }
  return userInput;
}

/* Sanitize and length check string 
 * safer, without assuming null terminated '\0'
 * adds zeroes (from left) or null terminates to make sure correct length */
char* strSanitizer(char* inputStr){
	
	char* inputStr_clean = malloc(ciphertextLen+1);
	char* tmpStr = malloc(ciphertextLen+1);

	int  actualData =0;
	bool reachedData = false; //gone through first zeroes
	
	//remove zeroes in beginning
	int i;
	for(i=0; i<(ciphertextLen); i++){
			if(inputStr[i] == '\0'){
				tmpStr[actualData] = '\0';
				break;
			}		
			//Looking for first data, i.e. not 0, (note 0 != \0)
			else if((inputStr[i] != '0') || reachedData){
				reachedData = true;
				tmpStr[actualData] = inputStr[i];
				actualData += 1;
			}
	}
	
	//add correct amount of zeroes in beginning
	int k;
	for(k=0; k<(ciphertextLen-actualData);k++){
		inputStr_clean[k]='0';
	}

	//add actual data 
	int j;
	for (j=0; j<actualData; j++){
		if ((k+j) >= ciphertextLen){
			break;
		}
		inputStr_clean[k+j] = tmpStr[j];
	}

	inputStr_clean[ciphertextLen] = '\0';
	free(tmpStr);
	return inputStr_clean;
}
