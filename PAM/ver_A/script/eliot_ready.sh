#!/bin/bash


#compile and move if successful
#gcc -I/usr/include/openssl/ -L/gmp_install_lib -lgmp  -lm -lcrypto -g -shared -o pamiot.so -fPIC crypto.c  data_parser.c  pam_helper.c  eliot_test.c
gcc -I/usr/include/openssl/ -L/gmp_install_lib -lgmp  -lm -lcrypto -g crypto.c  data_parser.c  pam_helper.c  eliot_test.c
