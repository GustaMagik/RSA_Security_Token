#!/bin/bash
#echo "000000: ffff ffff ffff ffff" | xxd -r > input

cd ../data

#rsa key without padding
openssl genrsa -out private.pem 72 -nopad
#echo "private OK"
openssl rsa -in private.pem -out public.pem -outform PEM -pubout
#echo "public OK"

# convert public key from PKCS#8 -> PKCS#1 (RSA key)
openssl rsa -pubin -in public.pem -RSAPublicKey_out -out public.pem

openssl rsautl -sign -inkey private.pem -in input -out message.signed -raw
#echo "encrypt OK"
openssl rsautl -verify -inkey public.pem -in message.signed -out message.verified -raw -pubin
#echo "decrypt OK"

cd script
