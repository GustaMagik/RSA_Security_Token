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

  int ret = 0;
 	
 	//msgPrompt is malloc:ed - cleartextLen+1 chars	
  char *msgPrompt = genNumber_hexStr();
  
	//terminal output in msgPromptInstr
	char* strOutput0 = "Enter on device: ";
	char* strOutput1 = "\nDevice response: ";
	int tmpLen = strlen(strOutput0)+strlen(strOutput1)+strlen(msgPrompt)+1;
	char msgPromptInstr[tmpLen];
	sprintf (msgPromptInstr, "%s%s%s",strOutput0,msgPrompt, strOutput1);

	free(msgPrompt);

  struct pam_conv *conv;
  struct pam_message msg;
  const struct pam_message *msgp;
  struct pam_response *resp;

  ret = pam_get_item(pamh, PAM_CONV, (const void **)&conv);
  if (ret != PAM_SUCCESS) {
    return PAM_SYSTEM_ERR;
  }
	
	//login fail if not changed
	int strCompared = 1;
  
	msg.msg_style = PAM_PROMPT_ECHO_ON;
  msg.msg = msgPromptInstr;
  msgp = &msg;

  resp = NULL;
  ret = (*conv->conv)(1, &msgp, &resp, conv->appdata_ptr);
  if (resp != NULL) {
    if (ret == PAM_SUCCESS) {
			// Verify token response (user input) against original cleartext
  		strCompared = check_userInput(resp->resp);
		}
		else {free(resp->resp);}
    
		free(resp);
  }
	
  if (strCompared == 0) {
    return PAM_SUCCESS;
  }
  else {
    return PAM_AUTH_ERR;
  }
  
}

PAM_EXTERN int pam_sm_close_session(pam_handle_t *pamh, int flags, int argc, const char *argv[]) {
  return (PAM_SUCCESS);
}

PAM_EXTERN int pam_sm_chauthtok(pam_handle_t *pamh, int flags, int argc, const char *argv[]) {
  return (PAM_SERVICE_ERR);
}

