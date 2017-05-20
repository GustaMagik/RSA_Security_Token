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
#include "header.h"


unsigned char* userInput_to_data(char* userInput){
	char* userInput_clean  = strSanitizer(userInput);
  char* userInput_binary = ascii_parser(userInput_clean);
  unsigned char* userInput_data = binToChar(userInput_binary);

	//DEBUG
	printf("\n\nentered ciphertext: %s\n",userInput);
	printf("sanitized ciphertext: %s\n",userInput_clean);
	printf("ciphertext interpreted as binary: %s\n",userInput_binary);
	//DEBUG

	free(userInput);
	free(userInput_clean);
	free(userInput_binary);	
	return userInput_data;
}


int check_userInput(char* ciphertext_user){
	unsigned char* ciphertext_data = userInput_to_data(ciphertext_user);

	//DEBUG
	// without decrypt test:
	// 	const unsigned char* cleartext = ciphertext_user;
	//DEBUG
	
	const unsigned char* cleartext = public_decrypt(ciphertext_data);
	
	free(ciphertext_data);
	
	//DEBUG
	printf("equals cleartext: %s\n", cleartext);
	printf("\n\n\n");
	//DEBUG

	int result = verify_rsa(cleartext);

	// constant requires cast 
	free((char*) cleartext);

	return(result);
}


/*
 using global variables:
 		static const cleartextLen
		static char  randData_hexStr_orig [cleartextLen+1]
*/
unsigned char* genNumber_raw(void) {
	// Random data generated
	unsigned char* randData  =  malloc(cleartextLen/2+1);
	
	//Generate random data
	if(!RAND_bytes(randData, (cleartextLen/2) )){ // (Len/2) bytes then \0
		//RAND_bytes failed
		//return 1; //TODO throw error? return fail?
	}

	// TODO TEMPORARY DEBUG 
	// DEBUG
	// hardcoded ABC123
	randData[0] = 171;
	randData[1] = 193;
	randData[2] = 35;
	// DEBUG

	//null terminate
	randData[cleartextLen/2] = '\0';
	
	memcpy(randData_orig, randData, (cleartextLen/2+1));
	//printf("randData_orig: %s\n", randData_orig);

  return randData;
}


/*
 using global variables:
 		static const cleartextLen
 		static char  randData_hexStr_orig [cleartextLen+1]
*/
char* genNumber_hexStr(void){

	//generate random data cleartextLen/2 long
	unsigned char* randData = genNumber_raw();

	/* Reverse the bytestring bc FPGA mem handling */
	reverseStr(randData);
	randData[cleartextLen/2] = '\0';

	/*
	  Splits each byte in randData into 2 hex-numbers
	  for some reason the prints does not print what is really in the arrays
	*/
	int i;
	char byte;
	char* tmpHexStr = malloc(cleartextLen+1);
	for (i = 0; i < cleartextLen/2; i++) {
	  byte = randData[i];
	  tmpHexStr[i*2] = (byte & 0xF0) >> 4;
		
		if ( (i*2+1) == cleartextLen ) {break;}
	  tmpHexStr[i*2+1] = (byte & 0x0F);
	}	

	tmpHexStr[cleartextLen] = '\0';
	free(randData);

	char* randDataHexStr = hexToAscii(tmpHexStr);
	randDataHexStr[cleartextLen] = '\0';
	free(tmpHexStr);
	
	return randDataHexStr;
}


unsigned char* reverseStr(unsigned char* input) {
  int len = strlen((char*) input);
  unsigned char temp;
  int i;
  for (i = 0; i < len/2; i++) {
    temp = input[i];
    input[i] = input[len-1-i];
    input[len-1-i] = temp;
  }
  return input;
}
