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

#include "header.h"
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <termios.h>



int main(int argc, char **argv){
  // Send and recieve USB-data
  // open port
  int usb = open("/dev/ttyACM0", O_RDWR | O_NOCTTY | O_NDELAY);
  if (usb == -1) {
    printf("Unable to open port\n");
    //return PAM_AUTH_ERR;
  } else {
    fcntl(usb, F_SETFL, 0);
  }

  // Set parameters
  struct termios tty;
  struct termios tty_old;
  memset (&tty, 0, sizeof(tty));
  if (tcgetattr (usb, &tty) != 0) {
    //perror("error from tcgetattr");
    //return PAM_AUTH_ERR;
  }

  // save old params for after close
  tty_old = tty;

  // set baud rate
  cfsetospeed (&tty, (speed_t)B115200);
  cfsetispeed (&tty, (speed_t)B115200);

  // other port configs
  tty.c_lflag = 0;  // noncanonical etc etc
  tty.c_oflag = 0;  // no remapping, no delays

  tty.c_cc[VMIN] = 0;   // no read block
  tty.c_cc[VTIME] = 5;  // 0.5s timeout

  //tty.c_iflag |= (IXON | IXOFF);

  tty.c_cflag &= ~CSIZE;
  tty.c_cflag |= CS8;
  tty.c_cflag |= (CLOCAL | CREAD);

  if (tcsetattr(usb, TCSANOW, &tty) != 0) {
    //perror("error from tcsetattr");
    //return PAM_AUTH_ERR;
  }

  //printf("%s\n", randData_orig);

  int bytes_written;
  unsigned char usbMessageBuf[66];
  memset(usbMessageBuf, 0, sizeof(usbMessageBuf));
  unsigned char usbOpCode[3];
  memset(usbOpCode, 0, sizeof(usbOpCode));
  unsigned char usbReceiveBuf[66];
  memset(usbReceiveBuf, 0, sizeof(usbReceiveBuf));
  unsigned char *usbMessage = genNumber_raw();
  printf("sizeofgenNumber: %i\n", strlen(usbMessage));
  // *W = Write operation
  usbMessageBuf[0] = '*';
  usbMessageBuf[1] = 'W';
  
  int i;
  for (i = 2; i < cleartextLen+2; i++) {
    usbMessageBuf[i] = usbMessage[i-2];
  }

  free(usbMessage);
   
  //usbMessageBuf[cleartextLen+3] = '\0';
  //usbMessageBuf[65] = '\0';
  /*  
  for (i = 2; i < cleartextLen+2; i++) {
    usbMessageBuf[i] = 'a';
    }
  usbMessageBuf[cleartextLen+2] = 1;
  
  for (i = 2; i < cleartextLen+4; i++) {
    printf("usbMesBuf: %i: %x\n", i, usbMessageBuf[i]);
  }
  */
  
  printf("usbMessageBuf: %s\n", usbMessageBuf);

  // Write random generated message to USB
  bytes_written = write(usb, usbMessageBuf, cleartextLen+3);
  if (bytes_written < cleartextLen+3) {
    printf("Write failed\n");
  }

  // Wait for *D response (msg received)
  int chars_read;
  while (!(usbOpCode[0] == '*' && usbOpCode[1] == 'D')) {
    //break;
    chars_read = read (usb, usbOpCode, 2);
    printf("usbOpCode: %s\n", usbOpCode);
    //if (chars_read != 0) {
    //  usbOpCode[2] = '\0';;
    //  printf("Read *D failed\n");
    //  }
    // if *T (time out), write again 
    if (usbOpCode[0] == '*' && usbOpCode[1] == 'T') {
      bytes_written = write(usb, usbMessageBuf, cleartextLen+3);
      if (bytes_written < cleartextLen+3) {
	printf("ReWrite failed\n");
      }
    }
  }

  usbOpCode[0] = 0;
  usbOpCode[1] = 0;
  // Request signed message *R
  while (!(usbOpCode[0] == '*' && usbOpCode[1] == 'M')) {
    //break;
    bytes_written = write(usb, "*R", 2);
    // Delay
    usleep ((100 + 25) * 100);
    if (bytes_written != 2) {
      printf("Write *R failed\n");
    }
    chars_read = read (usb, usbOpCode, 2);
    printf("usbOpCode:%s\n", usbOpCode);
    if (chars_read != 0) {
      //printf("Read *M or *B failed\n");
    }
  }
  
  //printf("usbOpCode:%s\n", usbOpCode);

  // *M received, request again and save in usbReceiveBuf
  
  //bytes_written = write(usb, "*R", 2);
  
  for (i = 0; i < 64; i++) {
    usbReceiveBuf[i] = 0;
  }
  chars_read = read(usb, usbReceiveBuf, 64);//cleartextLen+3);
  //if (chars_read != 0) {
  //  printf("Failed to read message\n");
  //  }

  usbReceiveBuf[64] = '\0';

  printf("usbRecBuf: %s\n", usbReceiveBuf);

  const unsigned char *verifiedMessage = malloc(cleartextLen+2);
  verifiedMessage = public_decrypt(usbReceiveBuf);

  //printf("origMessag: %s\n", randData_orig);
  printf("verMessage: %s\n", verifiedMessage);
  
  for (i = 0; i < 64; i++) {
    //printf("OrigData  : %i:  %i\n", i, randData_orig[i]);
    //printf("VerMessage: %i:  %i\n", i, verifiedMessage[i]);
  }
  
  printf("\n");

  // close port 
  tcsetattr(usb, TCSANOW, &tty_old);
  close(usb);

  for (i = 0; i < ciphertextLen; i++) {
    if (verifiedMessage[i] != randData_orig[i]) {
      return 1;
    }
  }
  
  return 0;
}
