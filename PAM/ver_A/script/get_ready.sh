#!/bin/bash

cd ../

#compile and move if successful
gcc -I/usr/include/openssl/ -L/gmp_install_lib -lgmp  -lm -lcrypto -g -shared -o pam_cthAuth.so -fPIC crypto.c  data_parser.c  pam_helper.c  pam_module.c && cp pam_cthAuth.so /lib64/security/

cd script
