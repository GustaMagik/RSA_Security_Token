cd ..
gcc -Wall -I/usr/include/openssl/ -L/gmp_install_lib -lgmp  -lm -lcrypto -g -shared -o pam_cthAuth.so -fPIC crypto.c   pam_helper.c  pam_module.c
cd script
