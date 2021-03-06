

# RSA\_Security\_Token
A Security token system for Linux PAM using an FPGA. Either utilizing 72-bit or 512-bit RSA cryptography when using Version A and B respectively. Version B is utilizing USB UART communication, while version A is air-gapped. These implementations provide two-factor authentication for any PAM-aware application. Fully working prototypes. BSD-3 licensed.

## HOW TO USE:

### PAM Setup:

##### Quick Setup on RedHat/CentOS:

	./install_pam_module.sh

##### Recommended Setup RedHat/CentOS:

	The dependencies are installed by install.sh.

	The compiled module (pam_cthAuth.so) should be placed in (atleast in our 64-bit OS) /lib64/security.
	The compiled file should be included in the PAM configuration file (in /etc/pam.d/), for each application that should use the token.

	Example configuration files are included in this repository, e.g. system-auth.


### FPGA Setup:

##### Needed hardware:

	Hexadecimal keyboard with 4+4 interconnected row-column pins. 

	LCD display with the HD44780 controller or equivalent.

	Sufficient FPGA for chosen design.
    
	UART-chip to interface the FPGA with (Usually on most dev-boards)


##### Minimum FPGA:

	Version A: Xilinx Spartan-6 XC6SLX16 or equivalent.

	Version B: Xilinx Spartan-6 XC6SLX25 or equivalent.


##### Needed software: 

	Xilinx ISE or Xilinx Vivado. (if not using Xilinx, at minimum Appendic B need to be done differently)

	GNU multiprecision library (if using constant_gen.c).


##### Setup:

1. Open the Xilinx project file of the version that is going to be used

	1b. In the case of Version B, all BRAMs and FIFOs needed has to be either generated with Xilinx Core Generator or manually created. Instructions can be found in the report Appendix B.

2. Use the script create_rsa_files.sh to generate your keys. If you have already done this in the setup of the software side, skip this step.

3. Use the values in file private_key.txt and replace the respective value in the generics at the top of the file of the version specific Security_Token_Top vhdl file. Note that all characters ':' has to be removed in the value.

	3b. In the case of Version B, the R_C value has to be calculated. From the original RSA_512 documentation: 

	Given a modulus m with 32 16-bit length words (this is 512 bit). 

	We can calculate the Montgomery constant r as 2^(16*(32+1))

	r_c is r^2 mod m which will result in a 512 bit number maximum. 

	This value can be calculated manually (use http://www.mobilefish.com/services/big_number_equation/big_number_equation.php) or the C program constant_gen.c located at RSA_Security_Token\VHDL_code\Version_B\RSA_Security_Token_USB_Version\rsa_512\trunk\src can be used. 

	3c. In the case of Version B, it is recommended that the RSA keys and R_C values are tested with the included test bench RSA_512_tb. Note that you will have to manually calculate what the result of signing the message with your chosen keys should be (use http://www.mobilefish.com/services/big_number_equation/big_number_equation.php) for the self-test functionallity to work correctly in stage 2

4. Set up other misc. generics to your specific needs

5. Create your specific UCF file for the clock and I/O

6. Create a programming file 

7. Program your FPGA with the program

### Please note that if you intend on using this product in an actual use case:

* There are attack vectors, limitations and improvements mentioned in project\_report.pdf (discussion)

* The locking functionallity after max tries of PIN is NOT saved after reloading the program (hard reset if programming file is put as a program-on-startup file in FLASH).

* This project trusts (in someway): OpenSSL, PAM, Xilinx as well as the [RSA\_512 module](https://opencores.org/project,rsa_512). Keep this software updated / consider if the you trusts this software as well.

* Remember to limit login attempts on the computer (doable in PAM config)

* Use 2FA for everything when possible, this solution should work for any PAM-aware application (Samba, SSH, ..)

### Additional Improvments
* (See project\_report.pdf discussion)

* Check on compilation flags to enable canaries and other protection mechanisms

* No padding is used which should (?) be fixed when ciphertext length is of no issue (e.g. version B). Would need some VHDL code to parse padding 

* To extend the length of the keys on version B the rsa\_512 module needs to be replaced. Moreover, the USB communication must be changed from 64B (512 bit) message data, accordingly.

* Extending key length on version A is not advisable since user friendlyness. However, we had an idea to perform RSA multiple times with different keys to prevent attacks were only message transations are known.

* Note the cleartext is not secret, but there are two requirements: should be dynamic to create new ciphertexts (TO PREVENT REPLAY-ATTACKS), and must be known to both token and computer for sign/verify. Thus it should be possible to use other data - such as time - to skip one step for the user.

* Instead of USB or writing the ciphertext other methods are possible such as QR-code, (EM-transfer?), sound or light (diodes). Thus, enabling for longer keys (and consequently ciphertexts) compared to ver\_A while being air-gapped.

* Perhaps other ciphers can provide longer keys without the need for longer ciphertext? Nevertheless, quantum-safe ciphers would be cool.

* Other HDLs could be used (instead of VHDL) to enable faster development, one example is [CλaSH](http://www.clash-lang.org) - a language like Haskell, which compiles to Verilog or VHDL.

###### Keywords: Two-factor, Authentication, Security, Token, Open source, FPGA, PAM, RSA, Linux, VHDL, PAM-Module, Unix
