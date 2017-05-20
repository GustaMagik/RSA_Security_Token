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


// Include only once
#ifndef __HEADER__
#define __HEADER__

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---- GLOBAL VARS ---- */
// These can be changed (if you know what you're doing)
#define CLEARTEXT_LEN 6 //Hexchars
#define KEY_LEN_BYTE  9	//Blocks of 8-bit
#define KEY_LEN_6BIT  KEY_LEN_BYTE*(8/6) //Blocks of 6-bit
/* ---- GLOBAL VARS ---- */



// ----  DO NOT CHANGE ----------------------------------
// Length of RSA key (and thus ciphertext) in hex
// Ciphertext entered on PC
static const int keyLen = KEY_LEN_6BIT;
static const int ciphertextLen = KEY_LEN_6BIT;

// Amount of hex chars to generate (entered on 2-fa device)
static const int cleartextLen = CLEARTEXT_LEN; // chars = bytes
 
// Random hex generated
// Checked by verify_rsa to ensure signed message is correct
unsigned char randData_orig[(CLEARTEXT_LEN/2+1)];
// ----  DO NOT CHANGE ----------------------------------



/* ---- FUNCTIONS ---- */

// ___________________________
// data_parser.c

/* */
char* ascii_parser(char* input);


/*
 * Takes a string with 'binary' e.g. "1010011"
 * THE INPUT DATA MUST BE BYTE (bits divisable by 8)
 * 	("1" != "\1")
 *
 * Returns pointer to decoded (plain) data by byte
 * Meaning each 8 char input gets decoded to 1 char output data
 * "10000000" -> "\128"
 */
unsigned char* binToChar(char* dataBinary);


/* convert from hex to ascii */
char* hexToAscii(char* input);

/* string sanitizer before ascii_parser */
char* strSanitizer(char* inputStr);



// ___________________________
// crypto.c 

/*
 * 
 * takes a string with 'binary' e.g. "1010011"
 * 
 * (Note: "1" != "\1")
 */
const unsigned char* public_decrypt(const unsigned char*);

// Decrypt string and compare with randData_hexStr_orig
// using private.pam local file
// returns 0 if success
int   verify_rsa(const unsigned char*);


// ___________________________
//Used in file pam_helper.c

/* Token output format -> raw data */
unsigned char* userInput_to_data(char*);

/* Sanitize, convert and verify (decrypt) - user input (from token)
 * ciphertext -> int
 * 0 = sign successful */
int check_userInput(char*);

/* Generates random hex sequence for two-factor device
 * void -> Random raw data 
 * In bytes, cleartextLen/2 long (+null termination) */
unsigned char* genNumber_raw(void);

/* calls genNumber and converts each byte to 2 hex chars
 * void -> Random hex chars
 * cleartextLen hex chars (+null termination) */
char*					 genNumber_hexStr(void);


/* reverse unsigned string
 * (used on hexStr because FPGA memory handling) */
unsigned char* reverseStr(unsigned char*);



// ___________________________
// pam_module.c

/* The PAM module code (it uses existing PAM functions) */
/* Does ONLY verify token response, */
/* please use pam_unix to check user credentials in unix. */
/* See provided pam config files! */


#endif
