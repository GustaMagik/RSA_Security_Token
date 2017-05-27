#!/bin/bash
#echo "000000: ffff ffff ffff ffff" | xxd -r > input

cd ../data

#rsa key without padding
openssl genrsa -out private512.pem 512 -nopad
#echo "private OK"
openssl rsa -in private512.pem -out public512.pem -outform PEM -pubout
#echo "public OK"

# convert public key from PKCS#8 -> PKCS#1 (RSA key)
openssl rsa -pubin -in public512.pem -RSAPublicKey_out -out public512.pem

#openssl rsautl -sign -inkey private.pem -in input -out message.signed -raw
#echo "encrypt OK"
#openssl rsautl -verify -inkey public.pem -in message.signed -out message.verified -raw -pubin

echo;echo
# PEM to text for FPGA
openssl rsa -text -in private512.pem > private_key.txt
cat private_key.txt

cd ../script
echo;echo; echo "Enter private exp and modulus on FPGA as seen above (private_key.txt)"
echo; echo; echo "Your keys are in '../data'";
