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

#include <openssl/pem.h>
#include <openssl/rsa.h>
#include "header.h"

/* IMPORTANT!
 * Change public_key_file to your public.pem file
 * (public RSA key, as generated by create_rsa_files.sh)
 */
char *public_key_file = "/home/user/Desktop/koddosa_git/koddosa/PAM_directory/ver_A/data/public.pem";

const unsigned char* public_decrypt(const unsigned char* ciphertext){
  int rsa_inLen = KEY_LEN_BYTE; //strlen((char*) ciphertext);
	FILE *fp0 = fopen(public_key_file, "r");

	/* init RSA struct and read public key */
	RSA *rsa;
	rsa = PEM_read_RSAPublicKey(fp0, NULL, NULL, NULL);
	fclose(fp0);

	int rsaSize = RSA_size(rsa);
	unsigned char * cleartext = malloc(rsaSize+1);
	
  RSA_public_decrypt(
		rsa_inLen, ciphertext, cleartext,
		rsa, RSA_NO_PADDING
	);

	cleartext[rsa_inLen] = '\0';

	/*
	// ------- DEBUG -------
	//Print error
	unsigned long errorCode = (unsigned long) ERR_peek_last_error();
	char error[500];
	ERR_error_string_n((unsigned long) errorCode
										 ,(char *) error, (size_t) 500);
	printf("\n%s", error);
 	openssl errstr errorCode
	// ------- DEBUG -------
	*/

	//clear key from memory
	RSA_free(rsa);
	return cleartext;
}


/*
 * using global variables:
 *  static const int cleartextLen
 *  unsigned char randData_orig[(CLEARTEXT_LEN/2+1)];
 */
int verify_rsa(const unsigned char* cleartext_user) {

	// take only the last (3) chars of user input
	// , as 3 Bytes = 6 hex = CLEARTEXT_LEN
	unsigned char* cleartextStripped = malloc(cleartextLen/2+1);
	int i;
	for (i = 0; i < cleartextLen/2; i++) {
	  cleartextStripped[i] = cleartext_user[i+6];
	}
	cleartextStripped[cleartextLen/2] = '\0';
		
	/*
	// ------- DEBUG -------
  int j;
	char byte;
	char* tmpHexStr = malloc(cleartextLen+1);
	for (j = 0; j < cleartextLen/2; j++) {
    byte = cleartextStripped[j];
    tmpHexStr[j*2] = (byte & 0xF0) >> 4;

    if ( (j*2+1) == cleartextLen ) {break;}
    tmpHexStr[j*2+1] = (byte & 0x0F);
  }	
  tmpHexStr[cleartextLen] = '\0';
	char* tmpHexStrReadable = hexToAscii(tmpHexStr);
	printf("\n\nFinal hex as str: %s\n\n", tmpHexStrReadable);
	free(tmpHexStr);
	free(tmpHexStrReadable);
	// ------- DEBUG -------
	*/


	//success! Authenticate user
	if (strcmp((char*) cleartextStripped,(char*) randData_orig) == 0) {
		free(cleartextStripped);
		return 0; 
	} else {
	  //access denied
		free(cleartextStripped);
		return 1;
	}
}


