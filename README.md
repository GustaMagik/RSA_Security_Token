# RSA_Security_Token
A Security token system for Linux PAM using an FPGA. Either utilizing 72-bit or 512-bit RSA cryptography when using Version A and B respectivly. Version B is utilizing USB UART communication, while version A is air-gapped. These implementations provide two-factor authentication for any PAM-aware application. Fully working prototypes. BSD-3 licenced.

HOW TO USE:

PAM Setup:

Dependencies:

	The dependencies can be found in install.sh.

On RedHat/CentOS:

	The compiled module (pam_cthAuth.so) should be placed in /lib64/security. The compiled file should be included in the PAM configuration file (in /etc/pam.d/), for each application that should use the token.

	Example configuration files are included in this repository, e.g. system-auth.


VHDL Setup:

Needed hardware:

	Hexadecimal keyboard with 4+4 interconnected row-column pins. 

	LCD display with the HD44780 controller or equivalent.

	Sufficient FPGA for chosen design.
    
    UART-chip to interface the FPGA with (Usually on most dev-boards)


Minimum FPGA:

	Version A: Xilinx Spartan-6 XC6SLX16 or equivalent.

	Version B: Xilinx Spartan-6 XC6SLX25 or equivalent.


Needed software: 

	Xilinx ISE or Xilinx Vivado.

	GNU multiprecission library (if using constant_gen.c).


Setup:

1. Open the Xilinx project file of the version that is going to be used

	1b. In the case of Version B, all BRAMs and FIFOs needed has to be either generated with Xilinx Core Generator or manually created. Instructions can be found in the report Appendix C.

2. Use the script create_rsa_files.sh to generate your keys. If you have already done this in the setup of the software side, skip this step.

3. Use the values in file private_key.txt and replace the respective value in the generics at the top of the file of the version specific Security_Token_Top vhdl file. Note that all characters ':' has to be removed in the value.

	3b. In the case of Version B, the R_C value has to be calculated. From the original RSA_512 documentation: 

	Given a modulus m with 32 16-bit length words (this is 512 bit). 

	We can calculate the Montgomery constant r as 2^(16*(32+1))

	r_c is r^2 mod m which will result in a 512 bit number maximum. 

	This value can be calculated manually (use http://www.mobilefish.com/services/big_number_equation/big_number_equation.php) or the C program constant_gen.c located at RSA_Security_Token\VHDL_code\Version_B\RSA_Security_Token_USB_Version\rsa_512\trunk\src can be used. 

	3c. In the case of Version B, it is recommended that the RSA keys and R_C values are tested with the included test bench RSA_512_tb. Note that you will have to manually calculate what the result of signing the message with your chosen keyes should be (use http://www.mobilefish.com/services/big_number_equation/big_number_equation.php) for the self-test functionallity to work correctly in stage 2

4. Set up other misc. generics to your specific needs

5. Create your specific UCF file for the clock and I/O

6. Create a programming file 

7. Program your FPGA with the program


Please note that if you intend on using this product in an actual use case that the locking functionallity after max tries of PIN is NOT saved after reloading the program (hard reset if programming file is put as a program-on-startup file in FLASH).

