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
#include <unistd.h> //used for sleep()

unsigned char* userInput_to_data(char* userInput){
	char* userInput_clean  = strSanitizer(userInput);
  char* userInput_binary = asciiToBin(userInput_clean);
  unsigned char* userInput_data = binToChar(userInput_binary);
	/*
	// ------- DEBUG -------
	printf("\n\nentered ciphertext: %s\n",userInput);
	printf("sanitized ciphertext: %s\n",userInput_clean);
	printf("ciphertext interpreted as binary: %s\n",userInput_binary);
	// ------- DEBUG -------
	*/
	free(userInput);
	free(userInput_clean);
	free(userInput_binary);	
	return userInput_data;
}


int check_userInput(char* ciphertext_user){
	unsigned char* ciphertext_data = userInput_to_data(ciphertext_user);
	/*
	// ------- DEBUG -------
	// to run without decrypt (testing):
	   const unsigned char* cleartext = ciphertext_user;
	// ------- DEBUG -------
	*/
	const unsigned char* cleartext = public_decrypt(ciphertext_data);
	free(ciphertext_data);
	/*
	// ------- DEBUG -------
	printf("\nequals cleartext: %s\n", cleartext);
	// ------- DEBUG -------
	*/
	int result = verify_rsa(cleartext);

	// const char*
	free((char*) cleartext);
	return(result);
}


/*
 * using global variables:
 *  static const int cleartextLen
 *  unsigned char randData_orig[(CLEARTEXT_LEN/2+1)];		
 */
unsigned char* genNumber_raw(void) {
	//half size cleartextLen since different data per printable char
	//data (8bit) , hex (4bit) per visable char for user
	unsigned char* randData  =  malloc(cleartextLen/2+1);
	
	//randData fills with random data
	while(RAND_bytes(randData, (cleartextLen/2)) != 1 ){
		//RAND_bytes failed (UNLIKELY!)
		fprintf(stderr,"\nRandom data generation fail!\n");
		sleep(1); //second
		fprintf(stderr,"Retrying..\n");
		sleep(1);
	}

	//null terminate
	randData[cleartextLen/2] = '\0';
	memcpy(randData_orig, randData, (cleartextLen/2+1));
	/*
	// ------- DEBUG -------
		 printf("randData_orig: %s %s\n", randData_orig, randData);	
	// ------- DEBUG -------
	*/
	return randData;
}


/*
 * using global variables:
 *  static const int cleartextLen
 */
char* genNumber_hexStr(void){
	//generate random data cleartextLen/2 long
	unsigned char* randData = genNumber_raw();	
	/*
	// ------- DEBUG -------
		 printf("randData: %s\n", randData);
	// ------- DEBUG -------
	*/

	/* Reverse the bytestring bc FPGA mem handling */
	reverseStr(randData);
	randData[cleartextLen/2] = '\0';
	/*
	// ------- DEBUG -------
		 printf("randData reversed: %s\n", randData);
	// ------- DEBUG -------
	//
	*/

	/*
	  Splits each byte in randData into 2 hex-numbers
	*/
	int i;
	char byte;
	unsigned char* randData_hex = malloc(cleartextLen+1);
	for (i = 0; i < cleartextLen/2; i++) {
	  byte = randData[i];
	  randData_hex[i*2] = (byte & 0xF0) >> 4;
		
		if ( (i*2+1) == cleartextLen ) {
			break; //unnecessary?
		}
	  randData_hex[i*2+1] = (byte & 0x0F);
	}

	randData_hex[cleartextLen] = '\0';
	free(randData);
	/*
	// ------- DEBUG -------
	// hardcoded random string: ABC123
	// Reversed: 23C1AB (each byte reversed)
	//	tmpHexStr[0] = 2;
	//	tmpHexStr[1] = 3;
	//	tmpHexStr[2] = 12;
	//	tmpHexStr[3] = 1;
	//	tmpHexStr[4] = 10;
	//	tmpHexStr[5] = 11;
	// ------- DEBUG -------
	*/
	char* randDataHexStr = hexToAscii(randData_hex);
	randDataHexStr[cleartextLen] = '\0';
	
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

