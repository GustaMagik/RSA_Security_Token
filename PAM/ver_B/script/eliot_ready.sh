#!/bin/bash

cd ..
#compile and move if successful
gcc -I/usr/include/openssl/ -L/gmp_install_lib -lgmp  -lm -lcrypto -g crypto.c  pam_helper.c  test_main.c

valgrind --leak-check=full ./a.out testtest

cd script
