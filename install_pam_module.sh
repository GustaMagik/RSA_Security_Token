#!/bin/bash
# * [BSD-3 Clause] 
# * Copyright 2017 Eliot Roxbergh
# *
# * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# *
# * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# *
# * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# *
# * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
# *
# * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

cd PAM


# ---- PRE-REQ. ----

echo "(you probably need to be root)"

echo;echo
read -p "Install dependencies? (Y/N) " -n 1 -r; echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	./install.sh
else
  echo "Not installing dependencies"
fi

echo;echo
read -p "Overwrite your PAM configs? (you might get locked out if not working) (Y/N) " -n 1 -r; echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	# PAM config (login, lockscreen ..)
	cp example_config/etc/pam.d /etc/ -Rv
else
  echo "Not changing PAM configs"
fi


# ---- COMPILE & MOVE PAM MODULE ----

echo;echo
read -p "Do you want version A (keyboard, air-gapped?) (Y/N) " -n 1 -r; echo
if [[ $REPLY =~ ^[Yy]$ ]]; then

	cd ver_A/script
	./create_rsa_files.sh

	# compile and copy PAM module if successful
	./get_ready.sh
	
	cd ../../../ #git root
	exit 0
else
  echo "Not choosing version A"
fi

echo;echo
read -p "Do you want version B (USB) (Y/N) " -n 1 -r; echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	cd ver_B/script
	./create_rsa_files.sh

	# compile and copy PAM module if successful
	./get_ready.sh
	
	cd ../../../ #git root
	exit 0
else
  echo "Not choosing version B";
fi

echo; echo "Did nothing!"
exit 1;

