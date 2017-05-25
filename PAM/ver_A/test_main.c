/*
 * License BSD, see pam_module.c
*/

/*
 * Just an ugly debug for running Valgrind
 * for more info see ./script/run_test.sh
*/ 


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

	char* userInputt = malloc(14);
	strcpy(userInputt, "QB5jjpsmzKFB\0");

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


