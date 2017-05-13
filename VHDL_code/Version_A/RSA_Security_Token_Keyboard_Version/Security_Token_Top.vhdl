
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
Use work.all;
-----------------------------------Top_Module----------------------------------
--This module house all submodules that make up the 'koddosa' which is a 
--challenge-response system that takes in 6 hexadecimal charracters and returns
--12 "alpha-numerical" + '!' + '"' characters via the attached LCD.
--The flow of the program is:
--PowerOn->Init->PIN->Input_from_HexKeyboard->RSA-encryption->Partition and ASCII 
--encode the RSA-encrypted bitString->Print on LCD->endOfProgram.
--If a wrong PIN is input 3 times in a row the program freezes at a blank screen
-------------------------------------------------------------------------------
Entity Security_Token_Top is

	Generic( PIN_LENGTH 		: Integer := 4;							--Variable length of PIN
				PIN_PSWRD  		: STD_LOGIC_VECTOR := x"ABCD";		--PIN, should have the same amount of numbers as PIN_LENGTH
				MAX_TRIES  		: Integer := 3;							--Number of tries. 3 means one initial and 2 retries
				
				KEY_LENGTH 		: Integer := 72; 							--Key length in bits, preferably mod 8 = 0 and mod 6 = 0
				RSA_E				: STD_LOGIC_VECTOR := x"08_37_F8_0B_8B_52_EF_32_C1"; --Exponent of the RSA
				RSA_N				: STD_LOGIC_VECTOR := x"CD_E5_68_77_70_51_D6_07_37"; --Modulus of the RSA
				MESSAGE_LENGTH : Integer := 6; --Number of keyboard presses. Must be less than KEY_LENGTH/4 - 2
				
				
				--String pointers
				INIT_FILE 		: string   := "mem.mif";
				STRING_PTR_0 	: unsigned := to_unsigned(0,6);
				STRING_PTR_1	: unsigned := to_unsigned(10,6);
				STRING_PTR_2 	: unsigned := to_unsigned(21,6);
				STRING_PTR_3 	: unsigned := to_unsigned(38,6)
				
);

	Port ( 	clk : in STD_LOGIC;
		--aresetn: in STD_LOGIC := '1';
		Hex_in : in STD_LOGIC_VECTOR(3 downto 0);    
		Hex_out : out STD_LOGIC_VECTOR (3 downto 0); 

		LCD_RS : out STD_LOGIC;
		LCD_RW : out STD_LOGIC;
		LCD_E  : out STD_LOGIC;
		LCD_DB : out STD_LOGIC_VECTOR (7 downto 0)
		);
end Security_Token_Top; 

architecture behav of Security_Token_Top is 

function MemSize (X : integer) --Function to determine how big the RAM addr-vector should be
	return integer is
	variable TMP : integer;
	variable POWER : integer := 1;
	variable RET : integer := 0;
	begin
	TMP := X/6;
	while (POWER < TMP) loop
		POWER := POWER * 2;
		RET := RET + 1;
	end loop;
	return RET;
end MemSize;

function ASCII_MEM_SIZE(X : integer) --Function to determine how big the TMP-MEM should be. If mod 6 /= 0 we need one extra cell for the overflow
	return integer is
	begin
	if (X mod 6 = 0) then
		return X/6 - 1;
	else 
		return X/6;
	end if;
end ASCII_MEM_SIZE;
	
constant LCD_CLEAR : STD_LOGIC_VECTOR (1 downto 0) := "00";
constant LCD_PRINT : STD_LOGIC_VECTOR (1 downto 0) := "01";
constant LCD_CHANGE: STD_LOGIC_VECTOR (1 downto 0) := "10";
constant PASSWORD : STD_LOGIC_VECTOR (PIN_LENGTH * 4 - 1 downto 0) := PIN_PSWRD;
constant KEY_LENGTH_BYTES : Integer := KEY_LENGTH / 8;
constant RAM_MAX_ADDR: unsigned(MemSize(KEY_LENGTH)-1 downto 0) := (others => '1');
constant ROM_MAX_ADDR: unsigned(5 downto 0) := (others => '1');

Type MEMORY_ARRAY is ARRAY (0 to ASCII_MEM_SIZE(KEY_LENGTH)) of STD_LOGIC_VECTOR(5 downto 0); --Mem array to store the ASCII temporarily. In cases
type PRG_STATE is (INIT, PRINT_MSG_1, GET_INPUT, PIN, LOCK, RSA, BYTE_TO_6, PRINT_MSG_2,PRINT_MSG_3, CLEAR_RAM);
type LCD_SELECT is (SELECT_ASCII, SELECT_ROM, SELECT_RAM);

Signal STATE : PRG_STATE := INIT;
Signal bit6_mem : MEMORY_ARRAY;

Signal WRONG_PIN_COUNTER : unsigned(1 downto 0) := (others => '0'); --if max tries more than 3, change this vector
Signal In_data : STD_LOGIC_VECTOR(3 downto 0); --From Keyboard
signal In_data_e, LCD_INPUT, INPUT_ASCII : STD_LOGIC_VECTOR (7 downto 0) := x"00";
Signal RDY, DO_CMD, RDY_CMD, WRITE_BACK, PIN_CORRECT : STD_LOGIC := '0';
Signal flag, WE, Read_RAM, INPUT_LSB, no_print : STD_LOGIC := '0';
Signal ROM_ADDR : UNSIGNED (5 downto 0)  := (others => '0');
Signal RAM_ADDR : UNSIGNED (MemSize(KEY_LENGTH)-1 downto 0) := (others => '0');
Signal ROM_DATA, RAM_DATA_IN, RAM_DATA_OUT, ASCII_ENCODED : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
Signal Input_counter : UNSIGNED (5 downto 0) := (others => '0');
Signal MODE_SELECT : STD_LOGIC_VECTOR (1 downto 0) := LCD_CLEAR;
Signal TMP_INPUT : STD_LOGIC_VECTOR (3 downto 0);

Signal RSA_RESET, RSA_DONE, RSA_WE : STD_LOGIC := '0';
Signal RSA_START_ADDR, RSA_MEM_ADDR : STD_LOGIC_VECTOR (MemSize(KEY_LENGTH)-1 downto 0) := (others => '0');
Signal RSA_MEM_DATA_IN, RSA_MEM_DATA_OUT : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

Signal SPLITTER_DATA_IN : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
Signal SPLITTER_DATA_OUT	 : STD_LOGIC_VECTOR (5 downto 0) := (others => '0');
Signal SPLITTER_INC_ADDR : STD_LOGIC_VECTOR (0 downto 0) := (others => '0');
Signal SPLITTER_ACTIVE, SPLITTER_RESET : STD_LOGIC := '0';

Signal LCD_INPUT_SELECT : LCD_SELECT := SELECT_ROM;


component Keyboard 
	Port ( 	Row_Input 	: in 	STD_LOGIC_VECTOR (3 downto 0);
		Col_Input_A	: out 	STD_LOGIC_VECTOR (3 downto 0) := (others => '1');
		Output 		: out 	STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
		RDY		: out 	STD_LOGIC := '0';
		CLK		: in 	STD_LOGIC;
		ARESETN 	: in	STD_LOGIC
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
    Port ( 	INPUT 	: in 	STD_LOGIC_VECTOR (7 downto 0); 	--ASCII IN
		CLK				: in 	STD_LOGIC;								--FPGA Clock (100MHz)
		ARESETN			: in 	STD_LOGIC;								--RESET
		DATA_BUS			: out STD_LOGIC_VECTOR (7 downto 0); 	--DB 7 downto DB 0
		RW					: out STD_LOGIC := '0';						--RW signal (unused as of now)
		RS					: out STD_LOGIC;								--RS signal
		E					: out STD_LOGIC;								--E (200Hz)
		MODE_SELECT 	: in 	STD_LOGIC_VECTOR (1 downto 0);	--SELECT WHAT THE SCREEN IS TO DO
		RDY_CMD			: out STD_LOGIC := '0';						--Tell ouside world that the ready for the command
		DO_CMD			: in	STD_LOGIC);						--Outside world tell module to do the current command

end component;

component ascii_encoder is
	Port(input	: in STD_LOGIC_VECTOR (7 downto 0);
		output	: out STD_LOGIC_VECTOR (7 downto 0)
	);
end component;


component mem_array is
	GENERIC(
		DATA_WIDTH : integer := 8;
		ADDR_WIDTH : integer := MemSize(KEY_LENGTH));
	
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
		ADDR_WIDTH : integer := 6;
		INIT_FILE  : string  := INIT_FILE);

	Port(
		ADDR : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
		OUTPUT : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
	);
end component;

component RSA_Controller is
	Generic( i : integer := KEY_LENGTH;
		 mem_addr_width : integer := MemSize(KEY_LENGTH)-1;
				e_val : STD_LOGIC_VECTOR := RSA_E;
				N_val : STD_LOGIC_VECTOR := RSA_N);
	Port(clk		: in STD_LOGIC;
		resetN	: in STD_LOGIC;
		done		: out STD_LOGIC;
		mem_we	: out STD_LOGIC;
		input_addr: in STD_LOGIC_VECTOR (5 downto 0);
		mem_addr : out STD_LOGIC_VECTOR(5 downto 0);
		mem_data : in STD_LOGIC_VECTOR(7 downto 0);
		data_out : out STD_LOGIC_VECTOR(7 downto 0)
		);
end component;


begin

SPLITT: byte_to_six_bit_splitter port map(
		DATA_IN 	=> SPLITTER_DATA_IN,
		DATA_OUT => SPLITTER_DATA_OUT,
		INC_ADDR	=> SPLITTER_INC_ADDR(0),
		ACTIVE	=> SPLITTER_ACTIVE,
		CLK 		=> CLK,
		RESET 	=>	SPLITTER_RESET
		);

RSA_MODULE: RSA_Controller port map(
		clk			=> clk,
		resetN		=> RSA_RESET,
		done			=>	RSA_DONE,
		mem_we		=> RSA_WE,
		input_addr 	=> RSA_START_ADDR,
		mem_addr 	=> RSA_MEM_ADDR,
		mem_data 	=>	RSA_MEM_DATA_IN,
		data_out 	=>	RSA_MEM_DATA_OUT
		);

ASCII: ascii_encoder port map (
		input => INPUT_ASCII,
		output => ASCII_ENCODED
		);

SCREEN: LCD port map ( 
		INPUT 	=> LCD_INPUT,
		CLK 		=> clk,
		ARESETN	=> '1',
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
		ARESETN => '1'
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
		clk => CLK,
		WE => WE,
		OUTPUT => RAM_DATA_OUT);



RSA_MEM_DATA_IN <= RAM_DATA_OUT;

with STATE select 
	RAM_DATA_IN <=
			In_data_e when GET_INPUT,
			RSA_MEM_DATA_OUT when RSA,
			In_data_e when others;
	
with LCD_INPUT_SELECT select
	LCD_INPUT <=
			ROM_DATA when SELECT_ROM,
			RAM_DATA_OUT when SELECT_RAM,
			ASCII_ENCODED when SELECT_ASCII,
			ROM_DATA when others;


--State changes
process(clk)
begin
	if rising_edge(clk) then
	
	
		if WE = '1' then
			WE <= '0';
		end if;
	
	
		--If we are telling the screen to do a command and RDY_CMD goes to 0
		--it means that the screen is working on it. Thus we should stop
		--telling the screen to do commands.
		if RDY_CMD = '0' and DO_CMD = '1' then
			DO_CMD <= '0';
			
		else
			
		
		
			case STATE is

------------------------------------------------------------------------------
				when INIT =>
					if RDY_CMD = '1' and DO_CMD = '0' then  --Wait for the LCD to be ready
						STATE <= PIN;
						ROM_ADDR <= STRING_PTR_0 - 1;
						
						WE <= '0';
					end if;
					
------------------------------------------------------------------------------

				when PIN =>
				
				if flag = '0' then
					
					if RDY_CMD = '1' and DO_CMD = '0' then
						LCD_INPUT_SELECT <= SELECT_ROM;
						MODE_SELECT <= LCD_PRINT;
						DO_CMD <= '1';
						
						if ROM_DATA = x"00" and ROM_ADDR /= ROM_MAX_ADDR then --char is '\0' (and not the last rom addr)
							MODE_SELECT <= LCD_CHANGE;
							Input_counter <= to_unsigned(PIN_LENGTH, 6);
							RAM_ADDR <= (others => '0');
							PIN_CORRECT <= '1';
							flag <= '1';
						
						else
							ROM_ADDR <= ROM_ADDR + 1;
						end if;
					end if;
					
					
				elsif RDY_CMD = '1' and DO_CMD = '0' then 
					if Input_counter = 0 and PIN_CORRECT = '1' then
						MODE_SELECT <= LCD_CLEAR;
						flag <= '0';
						DO_CMD <= '1';
						STATE <= PRINT_MSG_1;
						ROM_ADDR <= STRING_PTR_2 - 1;
						WRONG_PIN_COUNTER <= (others => '0');
						
					elsif Input_counter = 0 and PIN_CORRECT = '0' then
						MODE_SELECT <= LCD_CLEAR;
						STATE <= PRINT_MSG_3;
						ROM_ADDR <= STRING_PTR_1 - 1;
						DO_CMD <= '1';
						WRONG_PIN_COUNTER <= WRONG_PIN_COUNTER + 1;
						
					elsif RDY = '1' then
						if PASSWORD(to_integer(input_counter * 4 - 1) downto to_integer(input_counter * 4 - 4)) /= In_data then -- if the current number was wrong the entire pin is wrong
							PIN_CORRECT <= '0';
						end if;
						Input_counter <= Input_counter - 1;
					end if;
				end if;
	
	
	
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
							STATE <= CLEAR_RAM;
							Input_counter <= (others => '0');
							RAM_ADDR <= (others => '0');
							
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
							Input_counter <= (others => '0');
							RAM_ADDR <= (others => '0');
						end if;
					end if;
					
------------------------------------------------------------------------------
				when GET_INPUT => 
			
				if RDY_CMD = '1' and DO_CMD = '0' then
				
					if Input_counter = MESSAGE_LENGTH/2 then --All the inputs have been put
						Input_counter <= (others => '0');
						STATE <= RSA;
						ROM_ADDR <= ROM_ADDR; 
						MODE_SELECT <= LCD_CLEAR;
						RAM_ADDR <= (others => '0');
						DO_CMD <= '1';
						INPUT_LSB <= '0';
						
						
					elsif RDY = '1' then

			
						LCD_INPUT_SELECT <= SELECT_ASCII; --Print the pushed number
						MODE_SELECT <= LCD_PRINT;
						WE <= '0';
						INPUT_ASCII <= ("0000" & In_data);

						DO_CMD <= '1';
						
						if INPUT_LSB = '0' then --Put the number correctly into memory
							tmp_input <= In_data;
						else	
							In_data_e <= (tmp_input & In_data);
							RAM_ADDR <= input_counter;
							Input_counter <= Input_counter + 1;
							WE <= '1';
					
						end if;
						INPUT_LSB <= NOT INPUT_LSB;
						
					end if;
				end if;
				
------------------------------------------------------------------------------
				when RSA =>
				
					WE <= RSA_WE;
					RSA_RESET <= '1';
					
					RSA_START_ADDR <= (others => '0'); --placeholder
					
					

					RAM_ADDR 	<= (unsigned(RSA_MEM_ADDR));
					
					if RSA_DONE = '1' then
						RSA_RESET <= '0';
						STATE <= BYTE_TO_6;
						--SPLITTER_ACTIVE <= '1';
						RAM_ADDR <= (others => '0');
						
					end if;
					
------------------------------------------------------------------------------
				when BYTE_TO_6 => --translate the number into an array of bytes of maximum 6 byte length
					
					SPLITTER_DATA_IN <= RAM_DATA_OUT;

					if RAM_ADDR < KEY_LENGTH/6 then
					In_data_e <= "00" & bit6_mem(to_integer(unsigned(RAM_ADDR)));
					end if;

					if flag = '0' then --Give one cycle to get splitter to have a chance to catch up
						RAM_ADDR <= (others => '0');
						RAM_ADDR(0) <= '1';
						SPLITTER_ACTIVE <= '1';
						flag <= '1';
						
					elsif WRITE_BACK = '0' then --Create all the 6 bit numbers and save them temporarily
						
						RAM_ADDR <= RAM_ADDR + unsigned(SPLITTER_INC_ADDR);
						if input_counter > 0 then
							bit6_mem(to_integer(input_counter)-1) <= SPLITTER_DATA_OUT;
						end if;
						input_counter <= input_counter + 1;
						
						if input_counter = KEY_LENGTH/6 then --all the numbers have been made
							WRITE_BACK <= '1';
							SPLITTER_ACTIVE <= '1';
							RAM_ADDR <= (others => '1');
						end if;
					
					else	--Write the converted numbers back to memory
					
						if RAM_ADDR = RAM_MAX_ADDR then
							In_data_e <= "00" & bit6_mem(0);
						elsif RAM_ADDR < KEY_LENGTH/6 - 1 then
							In_data_e <= "00" & bit6_mem(to_integer(unsigned(RAM_ADDR + 1)));
						end if;
						
						RAM_ADDR <= RAM_ADDR + 1;
						WE <= '1';
						
						if RAM_ADDR = KEY_LENGTH/6 -1 then --Write back complete
							flag <= '0';
							WRITE_BACK <= '0';
							WE <= '0';
							input_counter <= (others => '0');
							RAM_ADDR <= (others => '1');
							SPLITTER_ACTIVE <= '0';
							STATE <= PRINT_MSG_2;
							ROM_ADDR <= STRING_PTR_3 - 1;
						end if;
					end if;
	
------------------------------------------------------------------------------	
				
				when PRINT_MSG_2 =>
				if RDY_CMD = '1' and DO_CMD = '0' then
						
						INPUT_ASCII <= RAM_DATA_OUT;
						MODE_SELECT <= LCD_PRINT;
						DO_CMD <= '1';
						
						if flag = '0' then
						LCD_INPUT_SELECT <= SELECT_ROM;
							if ROM_DATA /= x"00" or ROM_ADDR = STRING_PTR_3 - 1 then --char is not '\0', continue printing
								ROM_ADDR <= ROM_ADDR + 1;
						
							else
								MODE_SELECT <= LCD_CHANGE;
								Input_counter <= (others => '0');
								RAM_ADDR <= to_unsigned(KEY_LENGTH/6-1,6);
								flag <= '1';
								LCD_INPUT_SELECT <= SELECT_ASCII;
								MODE_SELECT <= LCD_CHANGE;
					
							end if;
						else
							
							if RAM_ADDR /= RAM_MAX_ADDR then
								RAM_ADDR <= RAM_ADDR - 1;
								
							elsif RDY = '1' then
								STATE <= CLEAR_RAM;
								MODE_SELECT <= LCD_CLEAR;
								ROM_ADDR <= STRING_PTR_0 - 1;
								RAM_ADDR <= (others => '0');
								flag <= '0';
							else 
								DO_CMD <= '0';
								
							end if;
						end if;
					end if;

------------------------------------------------------------------------------
			when CLEAR_RAM =>

				RAM_ADDR <= RAM_ADDR + 1;
				In_data_e <= (others => '0');
				WE <= '1';
				flag <= '1';
				if RAM_ADDR = 0 and flag = '1' then
					STATE <= INIT;
					flag <= '0';
					RAM_ADDR <= (others => '0');
					WE<= '0';
					Input_counter <= (others => '0');
				end if;
				
				
			when others =>
				--kill me
			end case;
		end if;
	end if;
end process;
end behav;

