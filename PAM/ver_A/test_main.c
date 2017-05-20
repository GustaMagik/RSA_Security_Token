/*
 * beerware eliot roxbergh 
*/



//#define PAM_SM_AUTH

#include "header.h"


int main(int argc, char **argv){
	//if (argc != 2) {printf("Enter ONE input");return 1;}
	
	char *msgPrompt = genNumber_hexStr();

	//terminal output in msgPromptInstr
	char* strOutput0 = "Enter on device: ";
	char* strOutput1 = "\nDevice response: ";
	int tmpLen = strlen(strOutput0)+strlen(strOutput1)+strlen(msgPrompt)+1;
	char msgPromptInstr[tmpLen];
	sprintf (msgPromptInstr, "%s%s%s",strOutput0,msgPrompt, strOutput1);

	free(msgPrompt);

	char* userInputt = malloc(100);
	strcpy(userInputt, "testingonly\0");

  // Decrypt user input see if same
  int strCompared = check_userInput(userInputt);
	
	printf("\nEOF\n");
  if (strCompared == 0) {
    //printf("SUCCESS\n");
    return 0;
  }
  else {
		//printf("FAIL");
    return 1;
  } 
}


