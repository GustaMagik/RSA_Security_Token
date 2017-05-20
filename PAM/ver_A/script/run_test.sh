#!/bin/bash


#compile and move if successful
#gcc -I/usr/include/openssl/ -L/gmp_install_lib -lgmp  -lm -lcrypto -g -shared -o pamiot.so -fPIC crypto.c  data_parser.c  pam_helper.c  eliot_test.c
cd ..
gcc -Wall -I/usr/include/openssl/ -L/gmp_install_lib -lgmp  -lm -lcrypto -g crypto.c  data_parser.c  pam_helper.c test_main.c
valgrind --leak-check=full ./a.out testtest
cd -

