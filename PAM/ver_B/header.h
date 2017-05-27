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
#define CLEARTEXT_LEN 63  //Hexchars (should be less than KEY_LEN_BYTE)
#define KEY_LEN_BYTE  64	 //Blocks of 8-bit
/* ---- GLOBAL VARS ---- */


// ----  DO NOT CHANGE ----------------------------------
// Length of RSA key (and thus ciphertext) data bytes
// Ciphertext sent to PC
static const int keyLen = KEY_LEN_BYTE;
static const int ciphertextLen = KEY_LEN_BYTE;

// Amount of data bytes (chars) to generate
// Cleartext sent to FPGA
static const int cleartextLen = CLEARTEXT_LEN;
 
// Random data generated
// Checked by verify_rsa to ensure signed message is correct
// Note: these are NOT printable characters
unsigned char randData_orig[(CLEARTEXT_LEN+2)];
// ----  DO NOT CHANGE ----------------------------------



/* ---- FUNCTIONS ---- */

// ___________________________
// crypto.c 

/* public_decrypt
 *
 * raw data -> raw data 
 * decrypts with local PUBLIC key
 */
const unsigned char* public_decrypt(const unsigned char*);


// ___________________________
//Used in file pam_helper.c

/* genNumber_raw
 *
 * Generates random sequence for two-factor device
 * In bytes, cleartextLen long (+ 1 Byte, null termination)
 *
 * void -> Random raw data 
 * utilizes <openssl/rand.h>
 */
unsigned char* genNumber_raw(void);

/* reverseStr
 *
 * reverse raw data 
 * (used because FPGA memory handling)
 */
unsigned char* reverseStr(unsigned char*);


// ___________________________
// pam_module.c

/* The PAM module code (it uses existing PAM functions) */
/* Does ONLY verify token response, */
/* please use pam_unix to check user credentials in unix. */
/* See provided pam config files (!) for examples.  */


#endif
