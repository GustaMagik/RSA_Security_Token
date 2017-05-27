/*
 * BSD 3-clause "New" or "Revised" License
 * Inspired by pam_unix.c (v. 1.6 as found in NetBSD)
 * 
 * Copyright (c) 2002-2003 Networks Associates Technology, Inc.
 * Copyright (c) 2004-2011 Dag-Erling Smørgrav
 * Copyright (c) 2017 Eliot Roxbergh, Adam Fredriksson
 * All rights reserved.
 *
 * This software was developed for the FreeBSD Project by ThinkSec AS and
 * Network Associates Laboratories, the Security Research Division of
 * Network Associates, Inc.  under DARPA/SPAWAR contract N66001-01-C-8035
 * ("CBOSS"), as part of the DARPA CHATS research program.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */



//#define PAM_SM_AUTH

#include <security/pam_appl.h>
#include <security/pam_modules.h>
#include "header.h"

#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>



// Does NOT check user please use pam_unix too
PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
  return (PAM_SUCCESS);
}

// Does NOT check user please use pam_unix too
PAM_EXTERN int pam_sm_acct_mgmt(pam_handle_t *pamh, int flags, int argc, const char **argv) {
  return (PAM_SUCCESS);
}

// Does NOT check user please use pam_unix too
// Authenticate using two-factor device
PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {

  // Send and recieve USB-data
  // open port
  int usb = open("/dev/ttyACM0", O_RDWR | O_NOCTTY | O_NDELAY);
  if (usb == -1) {
		fprintf(stderr,"Unable to open port\n");
    return PAM_AUTH_ERR;
  } else {
    fcntl(usb, F_SETFL, 0);
  }

  // Set parameters
  struct termios tty;
  struct termios tty_old;
  memset (&tty, 0, sizeof(tty));
  if (tcgetattr (usb, &tty) != 0) {
    fprintf(stderr,"error from tcgetattr\n");
    return PAM_AUTH_ERR;
  }

  // save old params for after close
  tty_old = tty;

  // set baud rate (in / out)
  cfsetospeed (&tty, (speed_t)B115200);
  cfsetispeed (&tty, (speed_t)B115200);

  /* ---- other port configs ---- */
	// set lflag constants to 0 => non-canonical etc
  tty.c_lflag = 0;
	// set oflag constants to 0 => no remapping, no delays
	tty.c_oflag = 0;
  tty.c_cc[VMIN] = 0;   // no read block
  tty.c_cc[VTIME] = 5;  // 0.5s timeout
	//block size
  tty.c_cflag &= ~CSIZE;
  tty.c_cflag |= CS8;
  tty.c_cflag |= (CLOCAL | CREAD);

	// set specified configs	
  if (tcsetattr(usb, TCSANOW, &tty) != 0) {
    fprintf(stderr, "error from tcsetattr\n");
    return PAM_AUTH_ERR;
  }

	// init data to 0 ('\0')
  int bytes_written;
  unsigned char usbOpCode[3];
	
	// 2B header + 1B not used (null) + 63B cleartext_len
  unsigned char usbMessageBuf[cleartextLen+3];

	// 2B header + 64B message (ciphertext)
  unsigned char usbReceiveBuf[ciphertextLen+2];

  memset(usbOpCode, 0, sizeof(usbOpCode));
	memset(usbMessageBuf, 0, sizeof(usbMessageBuf));
  memset(usbReceiveBuf, 0, sizeof(usbReceiveBuf));
  
	unsigned char *usbMessage = genNumber_raw();

	// *W = Write operation
  usbMessageBuf[0] = '*';
  usbMessageBuf[1] = 'W';
  
	//copy message after 2 char header
  int i;
  for (i = 2; i < cleartextLen+2; i++) {
    usbMessageBuf[i] = usbMessage[i-2];
  }
   
  // Write random generated message to USB
  bytes_written = write(usb, usbMessageBuf, cleartextLen+3);
  if (bytes_written < cleartextLen+3) {
    fprintf(stderr,"Write failed\n");
  }

  // Wait for *D response (msg received)
  int chars_read;
  while (!(usbOpCode[0] == '*' && usbOpCode[1] == 'D')) {
    chars_read = read (usb, usbOpCode, 2);
   
	 	// if *T (time out), write again 
    if (usbOpCode[0] == '*' && usbOpCode[1] == 'T') {
      bytes_written = write(usb, usbMessageBuf, cleartextLen+3);
			if (bytes_written < cleartextLen+3) {
				fprintf(stderr,"ReWrite failed\n");
      }
    }
  } //End while

	usbOpCode[0] = 0;
  usbOpCode[1] = 0;
  // Request signed message *R
  while (!(usbOpCode[0] == '*' && usbOpCode[1] == 'M')) {
    bytes_written = write(usb, "*R", 2);
    usleep ((100 + 25) * 100); //delay
    
		if (bytes_written != 2) {
      fprintf(stderr,"Write *R failed\n");
    }
    chars_read = read (usb, usbOpCode, 2);
    if (chars_read == -1) {
      fprintf(stderr,"Read *M or *B failed\n");
    }
  }
  
  // *M received, request again and save in usbReceiveBuf
  // FPGA communication uses 64B messages
	for (i = 0; i < 64; i++) {
    usbReceiveBuf[i] = 0;
  }
  
	chars_read = read(usb, usbReceiveBuf, 64);
  if (chars_read == -1) { 
    fprintf(stderr,"Failed to read message\n");
  }
  usbReceiveBuf[64] = '\0';

	//reverse because FPGA mem handling
  reverseStr(usbReceiveBuf);
	
	// decrypt ciphertext received
  const unsigned char *verifiedMessage = malloc(cleartextLen+2);
  verifiedMessage = public_decrypt(usbReceiveBuf);
 
  // close port 
  tcsetattr(usb, TCSANOW, &tty_old);
  close(usb);

	//compare cleartexts, fail if not equal
  for (i = 0; i < ciphertextLen; i++) {
    if (verifiedMessage[i] != randData_orig[i]) {
      return PAM_AUTH_ERR;
    }
  }

  return PAM_SUCCESS;
}


PAM_EXTERN int pam_sm_close_session(pam_handle_t *pamh, int flags, int argc, const char *argv[]) {
  return (PAM_SUCCESS);
}

PAM_EXTERN int pam_sm_chauthtok(pam_handle_t *pamh, int flags, int argc, const char *argv[]) {
  return (PAM_SERVICE_ERR);
}

