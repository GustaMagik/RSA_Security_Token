
--Copyright 2017 Christoffer Mathiesen, Gustav Örtenberg
--Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
--
--1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
--
--2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the 
--documentation and/or other materials provided with the distribution.
--
--3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this 
--software without specific prior written permission.
--
--THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
--THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
--BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
--GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
--LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


Library IEEE; 
Use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_MISC.ALL;
Use IEEE.STD_LOGIC_UNSIGNED.ALL;
Use IEEE.NUMERIC_STD.all;
Use IEEE.MATH_REAL."log2";
Use IEEE.MATH_REAL."ceil";
Use work.all;
-----------------------------------Top_Module---------------------------------------------
--This module house all submodules that make up the 'koddosa' which is a 
--challenge-response system that takes signs messages of length 512 bits
--with a predefined RSA key. The messages are sent over USB UART and
--uses a simple communication protocol defined in USB_TOP
--
--The flow of the program is:
--PowerOn->Init->PIN->Input from PC->RSA-encryption->Signal data avalible to PC -> 
--On keyboard press soft reset circuit (returns to INIT).
--If a wrong PIN is input MAX_TRIES times in a row the program freezes at a blank screen
------------------------------------------------------------------------------------------
Entity Security_Token_Top_USB is

	Generic( --PIN settings
				PIN_LENGTH 		: Integer := 4;							--Variable length of PIN
				PIN_PSWRD  		: STD_LOGIC_VECTOR := x"ABCD";		--PIN, should have the same amount of numbers as PIN_LENGTH indicates
				MAX_TRIES  		: Integer := 3;							--Number of tries. 3 means one initial and 2 retries
				SHOW_PIN			: boolean := false;						--If true the characters will be printed on screen when in PIN state, if false '*' will appear
				TIMEOUT_SECONDS: INTEGER := 5;							--Amount of seconds the device waits for a message to sign after the PIN is put
				
				--Encryption settings
				KEY_LENGTH 		: Integer := 512; 							--Key length in bits. HAS to be 512 with current modules
				EXPONENT		: STD_LOGIC_VECTOR := x"b15f20094a5fbcd7605b23bb7dbe7d421556df00d266c649d019cfc87eae543f703f6870013851130d3a2ed993ef76a1c377a96b95fe326f7326a319bae5fe01"; --Exponent of the RSA
				MODULO			: STD_LOGIC_VECTOR := x"bb847f2d87e8030926eea2a0a3f89877e6f63c1e2f65f3791e9c85549f48863a1dcc9f8b477c36dfea2573c49fc59259efe83b9996d093b4be09666e904cb17f"; --Modulus of the RSA
				R_C_VAL	  		: STD_LOGIC_VECTOR := x"8F80651391C778113C509FDD5C205AE6648A94DBC225A1ECA53F149BCF135AFCAC7E47DF209AC030325E1904AD7D260E236CE56D6753F488E3E489D50A6C2B0E"; --R_C value
														--R_C is calculated by the formula 2^(16*([Words into RSA_512] + 1) * 2) mod MODULO, in standard case 2^(1056) mod MODULO
																			--If you are going to use this in a real world scenario, please use self-generated keys
				--String pointers
				STRING_PTR_0 : unsigned := to_unsigned(0,6);
				STRING_PTR_1 : unsigned := to_unsigned(10,6);
				STRING_PTR_2 : unsigned := to_unsigned(21,6);
				STRING_PTR_3 : unsigned := to_unsigned(38,6);
				
				--USB settings
				Frequency : integer := 100_000_000;
				BAUD  	 : integer := 115200
				
);

	Port ( 	clk : in STD_LOGIC;
		Hex_in : in STD_LOGIC_VECTOR(3 downto 0);    
		Hex_out : out STD_LOGIC_VECTOR (3 downto 0); 

		LCD_RS : out STD_LOGIC;
		LCD_RW : out STD_LOGIC;
		LCD_E  : out STD_LOGIC;
		LCD_DB : out STD_LOGIC_VECTOR (7 downto 0);
		
		TXD : out STD_LOGIC;
		RXD : in STD_LOGIC;

		RESET : in STD_LOGIC
		);
end Security_Token_Top_USB; 

architecture USB_behav of Security_Token_Top_USB is 
	
constant MemSize : integer := (KEY_LENGTH/8);
constant LCD_CLEAR : STD_LOGIC_VECTOR (1 downto 0) := "00";
constant LCD_PRINT : STD_LOGIC_VECTOR (1 downto 0) := "01";
constant LCD_CHANGE: STD_LOGIC_VECTOR (1 downto 0) := "10";
constant PASSWORD : STD_LOGIC_VECTOR (PIN_LENGTH * 4 - 1 downto 0) := PIN_PSWRD;
constant MEM_BUS_WIDTH : Integer := integer(ceil(log2(real(MemSize))));
constant RAM_MAX_ADDR: unsigned(MEM_BUS_WIDTH-1 downto 0) := (others => '1');
constant ROM_MAX_ADDR: unsigned(5 downto 0) := (others => '1');

constant RSA_E : STD_LOGIC_VECTOR(KEY_LENGTH-1 downto 0) := EXPONENT;
constant RSA_M : STD_LOGIC_VECTOR(KEY_LENGTH-1 downto 0) := MODULO;
constant RSA_R_C : STD_LOGIC_VECTOR(KEY_LENGTH-1 downto 0) := R_C_VAL;



type PRG_STATE is (INIT, PRINT_MSG_1, GET_INPUT, PIN, RSA_2, RSA, PRINT_MSG_2,PRINT_MSG_3);
type LCD_SELECT is (SELECT_ASCII, SELECT_ROM, SELECT_RAM);

Signal STATE : PRG_STATE := INIT;

Signal WRONG_PIN_COUNTER : unsigned(1 downto 0) := (others => '0'); --if max tries more than 3, change this vector
Signal In_data : STD_LOGIC_VECTOR(3 downto 0); --From Keyboard
signal In_data_e, LCD_INPUT, INPUT_ASCII : STD_LOGIC_VECTOR (7 downto 0) := x"00";
Signal RDY, DO_CMD, RDY_CMD, WRITE_BACK, PIN_CORRECT : STD_LOGIC := '0';
Signal flag, WE, Read_RAM, INPUT_LSB, no_print : STD_LOGIC := '0';
Signal ROM_ADDR : UNSIGNED (5 downto 0)  := (others => '0');
Signal RAM_ADDR : UNSIGNED (MEM_BUS_WIDTH-1 downto 0) := (others => '0');
Signal ROM_DATA, RAM_DATA_IN, RAM_DATA_OUT, ASCII_ENCODED : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
Signal Input_counter : UNSIGNED (MEM_BUS_WIDTH-1 downto 0) := (others => '0');
Signal MODE_SELECT : STD_LOGIC_VECTOR (1 downto 0) := LCD_CLEAR;
Signal TMP_INPUT : STD_LOGIC_VECTOR (3 downto 0);

Signal RSA_RESET, RSA_DONE, RSA_WE : STD_LOGIC := '0';
Signal RSA_START_ADDR, RSA_MEM_ADDR : STD_LOGIC_VECTOR (MEM_BUS_WIDTH-1 downto 0) := (others => '0');
Signal RSA_MEM_DATA_IN, RSA_MEM_DATA_OUT : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
signal RSA_WORD : integer range 0 to 32 := 0;
signal RSA_byte : integer range 0 to 64 := 0;

Signal LCD_INPUT_SELECT : LCD_SELECT := SELECT_ROM;

Signal valid_in, start_in, valid_out : STD_LOGIC;
Signal x, y, m, r_c, s : STD_LOGIC_VECTOR(15 downto 0);

signal firstpass : STD_LOGIC := '0';

component Keyboard 
	Port ( 	Row_Input 	: in 	STD_LOGIC_VECTOR (3 downto 0);
		Col_Input_A	: out 	STD_LOGIC_VECTOR (3 downto 0) := (others => '1');
		Output 		: out 	STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
		RDY		: out 	STD_LOGIC := '0';
		CLK		: in 	STD_LOGIC;
		RESET 	: in	STD_LOGIC
		);
end component;

component byte_to_six_bit_splitter
	Port ( DATA_IN 		: in  STD_LOGIC_VECTOR (7 downto 0);
           DATA_OUT 		: out STD_LOGIC_VECTOR (5 downto 0);
			  INC_ADDR		: out STD_LOGIC;
			  ACTIVE			: in 	STD_LOGIC;
           CLK 			: in  STD_LOGIC;
           RESET 			: in  STD_LOGIC
			  );
end component;

component LCD 
	 Generic (Frequency: integer := Frequency);
    Port ( 	INPUT 	: in 	STD_LOGIC_VECTOR (7 downto 0); 	--ASCII IN
		CLK				: in 	STD_LOGIC;								--FPGA Clock (100MHz)
		RESET  			: in 	STD_LOGIC;								--RESET
		DATA_BUS			: out STD_LOGIC_VECTOR (7 downto 0); 	--DB 7 downto DB 0
		RW					: out STD_LOGIC := '0';						--RW signal (unused as of now)
		RS					: out STD_LOGIC;								--RS signal
		E					: out STD_LOGIC;								--E (200Hz)
		MODE_SELECT 	: in 	STD_LOGIC_VECTOR (1 downto 0);	--SELECT WHAT THE SCREEN IS TO DO
		RDY_CMD			: out STD_LOGIC := '0';						--Tell ouside world that the ready for the command
		DO_CMD			: in	STD_LOGIC);						--Outside world tell module to do the current command
end component;


component USB_TOP is
	generic ( data_addr_width : integer := MEM_BUS_WIDTH;
				BAUD_RATE : integer := BAUD; 
				 CLOCK_RATE : integer := Frequency; 
				 OVERSAMPLES : integer := 4);
    Port ( CLK : in  STD_LOGIC;
			  RESET : in STD_LOGIC;
           TXD : out  STD_LOGIC;
           RXD : in  STD_LOGIC;
           RAM_ADDR : out  STD_LOGIC_VECTOR (data_addr_width-1 downto 0);
           RAM_DATA_IN : in  STD_LOGIC_VECTOR (7 downto 0);
           RAM_DATA_OUT : out  STD_LOGIC_VECTOR (7 downto 0);
           RAM_WE : out  STD_LOGIC;
           READY_FOR_DATA : in  STD_LOGIC;
           RSA_DONE : in  STD_LOGIC;
			  DATA_READY : out STD_LOGIC);
end component;



component ascii_encoder is
	Port(input	: in STD_LOGIC_VECTOR (7 downto 0);
		output	: out STD_LOGIC_VECTOR (7 downto 0)
	);
end component;


component mem_array is
	GENERIC(
		DATA_WIDTH : integer := 8;
		ADDR_WIDTH : integer := MEM_BUS_WIDTH);
	
	Port(
		ADDR : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
		DATAIN : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
		clk : in std_logic;
		WE : in std_logic;
		OUTPUT : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
	);
end component;

component mem_array_ROM is
	GENERIC(
		DATA_WIDTH : integer := 8;
		ADDR_WIDTH : integer := 6);

	Port(
		ADDR : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
		OUTPUT : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
	);
end component;

component RSA_top is
	port(
    clk       : in  std_logic;
    reset     : in  std_logic;
    valid_in  : in  std_logic;
    start_in  : in  std_logic;
    x         : in  std_logic_vector(15 downto 0);  -- estos 3 son x^y mod m
    y         : in  std_logic_vector(15 downto 0);
    m         : in  std_logic_vector(15 downto 0);
    r_c       : in  std_logic_vector(15 downto 0);  --constante de montgomery r^2 mod m
    s         : out std_logic_vector(15 downto 0);
    valid_out : out std_logic;
    bit_size  : in  std_logic_vector(15 downto 0)  --tamano bit del exponente y (log2(y))
    );
end component;


signal RAM_DATA_IN_USB, RAM_DATA_OUT_USB : STD_LOGIC_VECTOR(7 downto 0);
signal RAM_ADDR_USB : STD_LOGIC_VECTOR(MEM_BUS_WIDTH-1 downto 0);
signal RAM_WE_USB, READY_FOR_DATA, DATA_READY: STD_LOGIC;

signal RSA_X : STD_LOGIC_VECTOR (511 downto 0);

signal RESETN, soft_reset : STD_LOGIC;

signal secondpass : std_logic := '0';
signal timeout_timer : integer := 0;

--signal clk, tog : std_logic;


begin

ASCII: ascii_encoder port map (
		input => INPUT_ASCII,
		output => ASCII_ENCODED
		);


USB: USB_TOP Port map ( 
	CLK => clk,
	RESET => RESETN,
	TXD => TXD,
	RXD => RXD,
	RAM_ADDR => RAM_ADDR_USB,
	RAM_DATA_IN => RAM_DATA_OUT,
	RAM_DATA_OUT => RAM_DATA_OUT_USB,
	RAM_WE => RAM_WE_USB,
	DATA_READY => DATA_READY,
	READY_FOR_DATA => READY_FOR_DATA,
	RSA_DONE => RSA_DONE);

RSA_MODULE: RSA_top port map(
    clk       => clk,
    reset     => RESETN,
    valid_in  => valid_in,
    start_in  => start_in,
    x         => x,  -- estos 3 son x^y mod m
    y         => y,
    m         => m,
    r_c       => r_c,  --constante de montgomery r^2 mod m
    s         => s,
    valid_out => valid_out,
    bit_size  => x"0200"  --512 --tamano bit del exponente y (log2(y))
    );
		

SCREEN: LCD port map ( 
		INPUT 	=> LCD_INPUT,
		CLK 		=> clk,
		RESET 	=> RESETN,
		DATA_BUS	=> LCD_DB,
		RW			=> LCD_RW,
		RS			=> LCD_RS,
		E			=> LCD_E,
		MODE_SELECT => MODE_SELECT,
		RDY_CMD	=> RDY_CMD,
		DO_CMD	=> DO_CMD

		);

KBD : Keyboard port map (
		Row_Input => Hex_in,
		Col_Input_A => Hex_out,
		Output => In_data,
		RDY => RDY,
		CLK => clk,
		RESET => RESETN
		);
ROM: 
mem_array_ROM port map(
		ADDR => STD_LOGIC_VECTOR(ROM_ADDR),
		OUTPUT => ROM_DATA
	);

RAM:
mem_array port map(
		ADDR => STD_LOGIC_VECTOR(RAM_ADDR),
		DATAIN => RAM_DATA_IN,
		clk => clk,
		WE => WE,
		OUTPUT => RAM_DATA_OUT);


		
INPUT_ASCII <= "0000" & IN_DATA;

with STATE select 
	RAM_DATA_IN <=
			RAM_DATA_OUT_USB when GET_INPUT,
			RSA_MEM_DATA_IN when RSA,
			RAM_DATA_OUT_USB when others;
	
with STATE select
		RAM_ADDR <= 
			unsigned(RAM_ADDR_USB) when GET_INPUT,
			unsigned(RSA_MEM_ADDR) when RSA, --Give the RSA access to the memory when it needs it
			unsigned(RAM_ADDR_USB) when others; --Otherwise make the USB able to use it
			
with STATE select
		WE <= 
			RAM_WE_USB when GET_INPUT,
			RSA_WE when RSA,
			RAM_WE_USB when others;
	
LCD_INPUT <= 	ROM_DATA when LCD_INPUT_SELECT = SELECT_ROM else --LCD gets data from ROM
					RAM_DATA_OUT when LCD_INPUT_SELECT = SELECT_RAM else --LCD gets data from RAM
					ASCII_ENCODED when (LCD_INPUT_SELECT = SELECT_ASCII AND SHOW_PIN) else -- LCD gets data from keyboard and shows the characters (show PIN)
					x"2A" when (LCD_INPUT_SELECT = SELECT_ASCII AND NOT SHOW_PIN) else --LCD only prints '*' when otherwise it would read from keyboard (NOT show PIN)
					ROM_DATA;

RESETN <= NOT RESET or soft_reset; --Invert the reset signal as the input is low when the button is pressed

--State changes
process(clk)
begin
	if rising_edge(clk) then --synchronous reset
		if RESETN = '1' then
			STATE <= INIT;
			flag <= '0';
			ROM_ADDR <= (others => '0');
			LCD_INPUT_SELECT <= SELECT_ROM;
			valid_in <= '0';
			start_in <= '0';
			DO_CMD <= '0';
			Input_counter <= (others => '0');
			--WRONG_PIN_COUNTER <= (others => '0'); --Uncomment if debug
			PIN_CORRECT <= '0';
			READY_FOR_DATA <= '0';
			RSA_DONE <= '0';
			RSA_X <= (others => '0');
			RSA_MEM_ADDR <= (others => '0');
			RSA_BYTE <= 0;
			RSA_WORD <= 0;
			RSA_MEM_DATA_IN <= (others => '0');
			x <= (others => '0');
			y <= (others => '0');
			m <= (others => '0');
			r_c <= (others => '0');
			READY_FOR_DATA <= '0';
			soft_reset <= '0';
			timeout_timer <= 0;
			firstpass <= '1';
			secondpass <= '0';
		else

	
	
		--If we are telling the screen to do a command and RDY_CMD goes to 0
		--it means that the screen is working on it. Thus we should stop
		--telling the screen to do commands.
		if RDY_CMD = '0' and DO_CMD = '1' then
			DO_CMD <= '0';
			
		else
			
		--reset <= '0';
		
			case STATE is

------------------------------------------------------------------------------
				when INIT =>
				soft_reset <= '0';
			
				
					if RDY_CMD = '1' and DO_CMD = '0' then  --Wait for the LCD to be ready
						MODE_SELECT <= LCD_CLEAR;
						DO_CMD <= '1'; --Clear the screen
						STATE <= PIN; --if PIN is unwanted, change this to Print_MSG_1
						ROM_ADDR <= STRING_PTR_0 - 1;
						--RESET <= '1';
						flag <= '0';
					end if;
					
------------------------------------------------------------------------------

				when PIN =>
				
			
				
				--RESET <= '0';
				
				if flag = '0' then --If in print mode
					
					if RDY_CMD = '1' and DO_CMD = '0' then --If the screen is ready for a command
						LCD_INPUT_SELECT <= SELECT_ROM; --Use characters from ROM
						MODE_SELECT <= LCD_PRINT;  		--Set the screen in print mode
						DO_CMD <= '1';							--Execute the command
						
						if ROM_DATA = x"00" and ROM_ADDR /= STRING_PTR_0 - 1 then --char is '\0' (and not the last rom addr)
							MODE_SELECT <= LCD_CHANGE;	--Set screen in change row mode
							Input_counter <= to_unsigned(PIN_LENGTH, MEM_BUS_WIDTH); --Set the input counter to the PIN length
			--				RAM_ADDR <= (others => '0');
							PIN_CORRECT <= '1'; --Assume correct pin
							flag <= '1'; --Insert PIN mode
						
						else
							ROM_ADDR <= ROM_ADDR + 1; --Inc the ROM ptr while printing
						end if;
					end if;
					
					
				elsif RDY_CMD = '1' and DO_CMD = '0' then  --If the screen is ready for a character
				
				LCD_INPUT_SELECT <= SELECT_ASCII;
					if Input_counter = 0 and PIN_CORRECT = '1' then --if the entire PIN is put and it was correct
						MODE_SELECT <= LCD_CLEAR; --Clear the screen
						flag <= '0'; --reset this flag
						DO_CMD <= '1'; --Do the command
						STATE <= PRINT_MSG_1; --move on to next part of program
						ROM_ADDR <= STRING_PTR_2 - 1; --set the pointer for next part of program
						WRONG_PIN_COUNTER <= (others => '0'); --Reset the amount of incorrect tries
						
					elsif Input_counter = 0 and PIN_CORRECT = '0' then --If entire PIN is put and it was incorrect
						MODE_SELECT <= LCD_CLEAR; --Clear the screen
						STATE <= PRINT_MSG_3; --
						ROM_ADDR <= STRING_PTR_1 - 1;
						DO_CMD <= '1';
						WRONG_PIN_COUNTER <= WRONG_PIN_COUNTER + 1; --Inc the counter 
						flag <= '0'; --reset the flag
						
					elsif RDY = '1' then --if a character was input from the keyboard
						MODE_SELECT <= LCD_PRINT;
						DO_CMD <= '1';
						
						if PASSWORD(to_integer(input_counter * 4 - 1) downto to_integer(input_counter * 4 - 4)) /= In_data then -- if the current number was wrong the entire pin is wrong
							PIN_CORRECT <= '0'; --set to incorrect pin
						end if;
						Input_counter <= Input_counter - 1; --dec the counter 
					end if;
				end if;
	
	---------------------------------------------------------------------
	
	when PRINT_MSG_3 =>
	
			if WRONG_PIN_COUNTER < MAX_TRIES then
					if RDY_CMD = '1' and DO_CMD = '0' then
						LCD_INPUT_SELECT <= SELECT_ROM;
						MODE_SELECT <= LCD_PRINT;
						DO_CMD <= '1';
						
						if ROM_DATA /= x"00" or ROM_ADDR = STRING_PTR_1 - 1 then --char is not '\0', continue printing
							ROM_ADDR <= ROM_ADDR + 1;
					
						elsif RDY = '1' then
							MODE_SELECT <= LCD_CLEAR;
							STATE <= INIT;
							Input_counter <= (others => '0');
				--			RAM_ADDR <= (others => '0');
							
						else 
							DO_CMD <= '0';
						end if;
					end if;
				end if;
------------------------------------------------------------------------------					
				when PRINT_MSG_1 =>
				
			
					if RDY_CMD = '1' and DO_CMD = '0' then
						LCD_INPUT_SELECT <= SELECT_ROM;
						MODE_SELECT <= LCD_PRINT;
						DO_CMD <= '1';
						
						if ROM_DATA /= x"00" or ROM_ADDR = STRING_PTR_2 - 1 then --char is not '\0', continue printing
							ROM_ADDR <= ROM_ADDR + 1;
					
						else
							MODE_SELECT <= LCD_CHANGE;
							STATE <= GET_INPUT;
							READY_FOR_DATA <= '1'; --Signal the USB-controller that we are ready for loading the RAM with data
							Input_counter <= (others => '0');
				--			RAM_ADDR <= (others => '0');
						end if;
					end if;
					
------------------------------------------------------------------------------
				when GET_INPUT => 
		
					READY_FOR_DATA <= '1'; --Signal the USB-controller that we are ready for loading the RAM with data
					RSA_DONE <= '0'; --Signal the USB-controller that the RSA is NOT done
					flag <= '1';
					timeout_timer <= timeout_timer + 1;
					
					if timeout_timer = timeout_seconds * frequency then
						SOFT_RESET <= '1';
					elsif DATA_READY = '1' and flag = '1' then --Data recieved. (and one cycle extra passed to let things catch up in a loop scenario)
						STATE <= RSA;			 --Perform the RSA
						READY_FOR_DATA <= '0';--And set so the USB can't write to the RAM anymore
						RSA_MEM_ADDR <= (others => '0'); --reset the RSA_MEM_ADDR pointer
						READY_FOR_DATA <= '0';
						STATE <= RSA;
						flag <= '0';
						firstpass <= '1';
						
					end if;
				
				
------------------------------------------------------------------------------
				when RSA =>
		
				--First prepare the data from memory to introduction into RSA_512
				
					if flag = '0' then --if not in the writing stage
						if RSA_BYTE < 64 then --Loading of the data
							RSA_X(RSA_BYTE*8+7 downto RSA_BYTE*8) <= RAM_DATA_OUT;
							RSA_MEM_ADDR <= RSA_MEM_ADDR + 1; --inc the pointer
							RSA_BYTE <= RSA_BYTE + 1;
						else
							--RSA_X(RSA_BYTE*8+7 downto RSA_BYTE*8) <= RAM_DATA_OUT; --Last byte to be read
							RSA_MEM_ADDR <= (others => '1'); --reset the pointer
						end if;
					end if;
					
					--Because of a weird bug in RSA_512, we have to perform the encrytion twice.
					--Hey! Don't ask why! I'm just using it! Even their own testbench has this
					--odd behaviour!
						if RSA_WORD = 32 then
							valid_in <= '0';
						end if;					
					if flag = '0' then --The loading of the RSA module
						if RSA_MEM_ADDR < 31-7 then --preload the n_c value for the RSA init-sequence
							m(15 downto 0) <= RSA_M(15 downto 0);
						elsif RSA_MEM_ADDR = 31 - 7 then --Start the init-sequence when half-6 bytes are loaded to the register
							start_in <= '1';
						elsif RSA_MEM_ADDR <= 31 then --Set the flag low again and wait for 6 cycles
							start_in <= '0';
						elsif RSA_MEM_ADDR > 31 and RSA_WORD < 32 then --Start loading the RSA_512
							
							x <= RSA_X(RSA_WORD*16+15 downto RSA_WORD*16);		--Message value
							
							
							y <= RSA_E(RSA_WORD*16+15 downto RSA_WORD*16);		--Key value
							m <= RSA_M(RSA_WORD*16+15 downto RSA_WORD*16);		--Modulo value
							r_c <= RSA_R_C(RSA_WORD*16+15 downto RSA_WORD*16);	--R_C value
						
							valid_in <= '1'; --Valid data in flag
							
							RSA_WORD <= RSA_WORD + 1; --inc the pointer
							if RSA_WORD = 31 then
							     --notihing
							end if;
						else
							valid_in <= '0'; --No more data in
							flag <= '1'; --set the mode to write back to memory
							RSA_WORD <= 0; --reset the counter to 0
							
							
						end if;
						
						
						
						
						
					else --Writing to memory
						
						if firstpass = '1' then --If it was the first pass, we need to send in the data again
							state <= RSA_2;
							secondpass <= '0';
							RSA_BYTE <= 0;
							RSA_WORD <= 0;
						
						elsif RSA_WORD < 32 AND valid_out = '1' then --if not the final byte from RSA_512 result (s)
							RSA_X(RSA_WORD*16+15 downto RSA_WORD*16) <= s; --save it in the register
							RSA_WORD <= RSA_WORD + 1; --inc the pointer
							input_counter <= (others => '0');
							RSA_MEM_ADDR <= (others => '1'); --Set this to max to overflow back to 0 and thus inserting the correct number in that cell
							RSA_BYTE <= 0;
						elsif RSA_WORD = 32 then --start writing back to RAM
							
							if RSA_BYTE < 64 then --If we haven't written the entire result to memory
								RSA_MEM_ADDR <= RSA_MEM_ADDR + 1; --increase the addr
								RSA_MEM_DATA_IN <= RSA_X(RSA_BYTE*8+7 downto RSA_BYTE*8); --use the correct part of the result
								RSA_WE <= '1'; --write it to memory
								RSA_BYTE <= RSA_BYTE + 1; --increase the counter
							else --everything written back
								RSA_WE <= '0'; --stop writing
								flag <= '0'; --reset this flag
								RSA_DONE <= '1'; --The result is done and in memory. Tell USB-cmd so
								STATE <= PRINT_MSG_2; --move on
								RSA_BYTE <= 0;
								RSA_WORD <= 0;
								
							end if;
						end if;
					end if;
					
					
				when RSA_2 =>
				
					
					if valid_out = '1' then
						secondpass <= '1';
					elsif secondpass = '1' then
						if RSA_BYTE < 50 then --Give some time after the "valid" data is done to let the RSA module be ready for data again
							RSA_BYTE <= RSA_BYTE + 1;
						elsif RSA_WORD < 32 then
						
							x <= RSA_X(RSA_WORD*16+15 downto RSA_WORD*16);		--Message value
							y <= RSA_E(RSA_WORD*16+15 downto RSA_WORD*16);		--Key value
							m <= RSA_M(RSA_WORD*16+15 downto RSA_WORD*16);		--Modulo value
							r_c <= RSA_R_C(RSA_WORD*16+15 downto RSA_WORD*16);	--R_C value
						
							valid_in <= '1'; --Valid data in flag
							
							RSA_WORD <= RSA_WORD + 1; --inc the pointer
							
						elsif RSA_BYTE = 50 and RSA_WORD = 32 then
                            valid_in <= '0';
				--			if RDY = '1' then
							state <= RSA;
							RSA_BYTE <= 0;
							RSA_WORD <= 0;
							firstpass <= '0';

							flag <= '1';
						--	end if;
						end if;
					end if;
-----------------------------------------------------------------------------------------------------					
				
				when PRINT_MSG_2 =>
				if RDY_CMD = '1' and DO_CMD = '0' then

						MODE_SELECT <= LCD_PRINT;
						DO_CMD <= '1';

						LCD_INPUT_SELECT <= SELECT_ROM;
							if ROM_DATA /= x"00" or ROM_ADDR = STRING_PTR_3 - 1 then --char is not '\0', continue printing
								ROM_ADDR <= ROM_ADDR + 1;
						
							else
								DO_CMD <= '0';
								if RDY = '1' then --wait for a press on the keyboard

									Input_counter <= (others => '0');
									soft_reset <= '1';
									STATE <= INIT;
								end if;
							end if;
						end if;
------------------------------------------------------------------------------			
			when others =>
				--kill me
			end case;
		end if;
	end if;
end if;	
end process;
end USB_behav;