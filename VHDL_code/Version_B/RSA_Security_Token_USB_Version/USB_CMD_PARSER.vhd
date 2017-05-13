
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

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.NUMERIC_STD.all;


entity USB_CMD_PARSER is
	generic ( data_addr_width : integer;
				 Frequency : integer);
    Port ( RXD_BYTE 			: in  STD_LOGIC_VECTOR (7 downto 0);						--Input byte from the serial-to-parallell translator
           TXD_BYTE 			: out STD_LOGIC_VECTOR (7 downto 0);						--Output byte to the parallell-to-serial translator
           RAM_ADDR 			: out STD_LOGIC_VECTOR (data_addr_width-1 downto 0) := (others => '1');	--RAM ADDR where the RSA (signed) message is
           RAM_DATA_IN 		: in  STD_LOGIC_VECTOR (7 downto 0);						--DATA from the active RAM cell
           RAM_DATA_OUT 	: out STD_LOGIC_VECTOR (7 downto 0);						--DATA to be written to active RAM cell if WE is high
			  VALID_DATA_IN 	: in  STD_LOGIC;													--Flag to the parallell-to-serial translator to tell it that there's a new byte on the bus 
           VALID_DATA_OUT 	: out STD_LOGIC;													--Flag from the serial-to-parallell translator to tell that there's a new byte on the bus
			  RAM_WE 			: out STD_LOGIC;													--RAM Write Enable flag
			  RSA_DONE 			: in 	STD_LOGIC;													--Flag from RSA module that the values in RAM are the signed message
			  READY_FOR_DATA 	: in 	STD_LOGIC;													--Flag from RSA module that it is ready to recive a new message to sign
			  RESET 				: in 	STD_LOGIC;													--Reset for module. When high all registers and counters resets at next high flank of the clock
           CLK 				: in  STD_LOGIC;													--Global clock signal
			  DATA_READY		: out STD_LOGIC := '0';													--Flag for 64 byte recieved
			  FIFO_EMPTY		: in 	STD_LOGIC);
end USB_CMD_PARSER;


--USB_CMD_PARSER is a module that recives whole bytes from RXD_Controller and parses them as 
--either command or data. 
--The commands are all this module accepts, and any other data recieved is disgarded.
--Everything that is to be sent is put in the TXD_FIFO in order of how it should be sent.
--The commands are all on the form '*' followed by the command specific character, and are as follows:
--*I - Request ID. The parser will respond with *IHEJ
--*W[64 byte] - Write request. Depending on READY_FOR_DATA flag, this will either 
--respond with *B for "busy" or *D when all 64 bytes has been written to memory
--*R -- Request encrypted data. Depending on DATA_READY flag, this will either 
--respond with *B for "busy" or *M[64 bytes], where the 64 bytes are the encrypted data
--In certain cases if data is either not recieved or not provided, the module will respond
--with *T for timeout
architecture Behavioral of USB_CMD_PARSER is

constant ASCII_ASTERISK : STD_LOGIC_VECTOR(7 downto 0) := x"2A"; 	--*
constant ASCII_B : STD_LOGIC_VECTOR(7 downto 0) := x"42";		--B
constant ASCII_D : STD_LOGIC_VECTOR(7 downto 0) := x"44";		--D
constant ASCII_E : STD_LOGIC_VECTOR(7 downto 0) := x"45";		--E
constant ASCII_H : STD_LOGIC_VECTOR(7 downto 0) := x"48";		--H
constant ASCII_J : STD_LOGIC_VECTOR(7 downto 0) := x"4A";		--J
constant ASCII_W : STD_LOGIC_VECTOR(7 downto 0) := x"57";		--W
constant ASCII_R : STD_LOGIC_VECTOR(7 downto 0) := x"52";		--R
constant ASCII_M : STD_LOGIC_VECTOR(7 downto 0) := x"4D";		--M
constant ASCII_I : STD_LOGIC_VECTOR(7 downto 0) := x"49";		--I
constant ASCII_T : STD_LOGIC_VECTOR(7 downto 0) := x"54";		--T

--No. They are not in alphabetical order. Deal with it

type STATES is (IDLE, TRANSLATE_CMD, DO_CMD); --States for the overarching functionality
type CMDS	is (TIMEOUT, RECIVE_DATA, TRANSMIT_DATA, TRANSMIT_ID, TRANSMIT_BUSY); --Depending on flags and inputs different commands are to be executed

signal TIMEOUT_COUNTER : integer range 0 to Frequency/2 := 0;

signal BYTE_COUNTER : unsigned (7 downto 0) := (others => '0'); --Counter to keep track of what byte in memory to read/write
signal HEADER_COUNTER : unsigned (1 downto 0) := (others => '0'); --counter to keep track of if an * or a message specific char is to be sent

signal STATE : STATES := IDLE;
signal CMD : CMDS;

signal flag : std_logic := '0';

Signal DATA_READY_S : STD_LOGIC;
	
begin

DATA_READY <= DATA_READY_S;

process(clk) 

variable RECIVED_DATA : STD_LOGIC_VECTOR(7 downto 0);

--Procedure for IDLE state
procedure IDLE
	(DATA : in STD_LOGIC_VECTOR(7 downto 0); --Data form RXD
	signal STATE : out STATES) is
	begin
	if DATA = ASCII_ASTERISK then --Procede iff the header * is detected
		state <= TRANSLATE_CMD;
	end if;
end IDLE;

--Procedure for TRANSLATE_CMD state
procedure TRANSLATE 
	(DATA : in STD_LOGIC_VECTOR(7 downto 0); --Data from RXD
	signal STATE : out STATES;
	signal CMD : out CMDS;
	signal RAM_ADDR : out STD_LOGIC_VECTOR(data_addr_width-1 downto 0)) is
	begin
	
	case DATA is
	
		--Write request
		when ASCII_W =>
			STATE <= DO_CMD;
			
			--If ready for recieving data we can execute this command
			if READY_FOR_DATA = '1' then
				CMD <= RECIVE_DATA;
			else --otherwise we have to tell the PC that we're busy
				CMD <= TRANSMIT_BUSY;
			end if;
		
		--Request of data from the PC
		when ASCII_R =>
			STATE <= DO_CMD;
			
			--If the RSA is done and in memory, and no other active transmit jobs, we can transmit it to the PC
			if RSA_DONE = '1' AND FIFO_EMPTY = '1' then
				CMD <= TRANSMIT_DATA;
				RAM_ADDR <= (others => '0');
			else --Otherwise tell the PC that the unit is busy
				CMD <= TRANSMIT_BUSY;
			end if;
			
		--Request of ID-sequence from the PC	
		when ASCII_I =>
			STATE <= DO_CMD;
			CMD <= TRANSMIT_ID;
			
		--Illegal command. Go back to idle	
		when others => 
			STATE <= IDLE;
		
	end case;
end TRANSLATE;

--Procedure for DO_CMD state
procedure DO_CMD
	(DATA : in STD_LOGIC_VECTOR(7 downto 0); 						--Data form RXD as input
	 BYTE_COUNT : in unsigned(7 downto 0); 	--Byte_counter as input
	 HEADER_COUNT : in unsigned(1 downto 0);						--Header_counter as input
	 CMD  : in CMDS;														--current CMD as input
	 VALID_DATA_IN : in STD_LOGIC;									--VALID_DATA_IN as input
	variable byte_count_var, header_count_var : in integer;	--integer versions of the counters as inputs

	signal STATE : out STATES;											--May change current state
	signal RAM_ADDR : out STD_LOGIC_VECTOR(data_addr_width-1 downto 0); --May change RAM_ADDR 
	signal RAM_WE, VALID_DATA_OUT : out STD_LOGIC;							--May change WE and VALID flags
	signal RAM_DATA_OUT, TXD_BYTE : out STD_LOGIC_VECTOR (7 downto 0);--May change RAM_DATA_OUT and TXD 
	signal BYTE_COUNTER : out unsigned(7 downto 0);	--May change the counters
	signal HEADER_COUNTER : out unsigned(1 downto 0)) is
	begin

	case CMD is 
		--Recieve data case. Write the following 64 bytes to the RAM
		when RECIVE_DATA =>
			
			if BYTE_COUNT_var > 63 then --all bytes have been written

				RAM_ADDR <= (others => '1'); --Reset signals that are not used anymore
				RAM_WE <= '0';
				RAM_DATA_OUT <= (others => '0');

				VALID_DATA_OUT <= '1';
				
				DATA_READY_S <= '1';
				if header_count_var = 0 then -- When the message is recived, tell the PC by sending *D
					TXD_BYTE <= ASCII_ASTERISK;
					HEADER_COUNTER <= HEADER_COUNT + 1;
				else 
					TXD_BYTE <= ASCII_D;
					HEADER_COUNTER <= (others => '0');
					STATE <= IDLE;											
					BYTE_COUNTER <= (others => '0');
				end if;
				
			elsif VALID_DATA_IN = '1' then  --Write the current number to the current cell in memory
				DATA_READY_S <= '0';
				RAM_ADDR <= STD_LOGIC_VECTOR(BYTE_COUNT(5 downto 0));
				RAM_DATA_OUT <= DATA;
				RAM_WE <= '1';
	
				BYTE_COUNTER <= BYTE_COUNT + 1; --inc the RAM ptr
			
			end if;

		--Tansmit data case. Write the first 64 bytes in RAM to the port
		when TRANSMIT_DATA =>
			VALID_DATA_OUT <= '1';
			--First write the header *M for signal to the PC that a message is comming
			if HEADER_COUNT_var = 0 then
				TXD_BYTE <= ASCII_ASTERISK;
				HEADER_COUNTER <= HEADER_COUNT + 1;
			
			elsif HEADER_COUNT_var = 1 then
				TXD_BYTE <= ASCII_M;
				HEADER_COUNTER <= HEADER_COUNT + 1;
				BYTE_COUNTER <= BYTE_COUNT + 1;
			
			elsif BYTE_COUNT_VAR > 63 then --all bytes has been transmitted
				STATE <= IDLE;
				RAM_ADDR <= (others => '0');
				BYTE_COUNTER <= (others => '0');
				TXD_BYTE <= RAM_DATA_IN;
				
				
			else --Put the data to the serial out
				
				RAM_ADDR <= STD_LOGIC_VECTOR(BYTE_COUNT(5 downto 0));
				TXD_BYTE <= RAM_DATA_IN;
				BYTE_COUNTER <= BYTE_COUNT + 1;
			
			end if;
		
		when TRANSMIT_ID =>
		
			--First write the header *I for signal to the PC that an ID is comming
			if HEADER_COUNT_var = 0 then
				TXD_BYTE <= ASCII_ASTERISK;
				HEADER_COUNTER <= HEADER_COUNT + 1;
				
			elsif HEADER_COUNT_var = 1 then
				TXD_BYTE <= ASCII_I;
				HEADER_COUNTER <= HEADER_COUNT + 1;
			
			else 
				--Put the ID on the serial out. The ID is: HEJ
				case BYTE_COUNT_VAR  is 
					when 0 =>
						TXD_BYTE <= ASCII_H;
						BYTE_COUNTER <= BYTE_COUNT + 1;
					when 1 =>
						TXD_BYTE <= ASCII_E;
						BYTE_COUNTER <= BYTE_COUNT + 1;
					when others =>
						TXD_BYTE <= ASCII_J; --Last char to be transmitted. Return to IDLE state
						STATE <= IDLE;
						HEADER_COUNTER <= (others => '0');
						BYTE_COUNTER <= (others => '0');
					end case;		
			end if;
			VALID_DATA_OUT <= '1';
			
		when TRANSMIT_BUSY =>
		
		--First write the header *B for signal to tell PC that unit is busy
			if HEADER_COUNT_var = 0 then
				TXD_BYTE <= ASCII_ASTERISK;
				HEADER_COUNTER <= HEADER_COUNT + 1;
				
			else 
				TXD_BYTE <= ASCII_B;
				HEADER_COUNTER <= (others => '0');
				STATE <= IDLE;
				
			end if;
			
			VALID_DATA_OUT <= '1';
		
		
		when TIMEOUT =>
			
			RAM_ADDR <= (others => '1'); --Reset signals that are not used anymore
			RAM_WE <= '0';
			RAM_DATA_OUT <= (others => '0');
			VALID_DATA_OUT <= '1';
			BYTE_COUNTER <= (others => '0');
			if HEADER_COUNT_var = 0 then
				TXD_BYTE <= ASCII_ASTERISK;
				HEADER_COUNTER <= HEADER_COUNT + 1;
				
			else 
				TXD_BYTE <= ASCII_T;
				HEADER_COUNTER <= (others => '0');
				STATE <= IDLE;
				
			end if;
			
		end case;
end DO_CMD;
	

variable BYTE_COUNT_VAR : integer := 0;
variable HEADER_COUNT_VAR : integer := 0;
begin

if rising_edge(clk) then
	if RESET = '1' then --synchronous reset
		STATE <= IDLE;
--		CMD <= NONE;
		VALID_DATA_OUT <= '0';
		RAM_ADDR <= (others => '0');
		RAM_DATA_OUT <= (others => '0');
		RAM_WE <= '0';
		TXD_BYTE <= (others => '0');
		BYTE_COUNTER <= (others => '0');
		HEADER_COUNTER <= (others => '0');
		TIMEOUT_COUNTER <= 0;
		DATA_READY_S <= '0';
		
		else 
	
		if DATA_READY_S = '1' and READY_FOR_DATA = '1' then
			DATA_READY_S <= '0';
		end if;
	
	
	case STATE is
		when IDLE => --Reset everything

			VALID_DATA_OUT <= '0';
			RAM_ADDR <= (others => '0');
			RAM_DATA_OUT <= (others => '0');
			RAM_WE <= '0';
			TXD_BYTE <= (others => '0');
			BYTE_COUNTER <= (others => '0');
			HEADER_COUNTER <= (others => '0');
			TIMEOUT_COUNTER <= 0;
			
			--If we have a valid input and that input is * then we are going to the TRANSLATE_CMD state
			if VALID_DATA_IN = '1' then
			
				RECIVED_DATA := RXD_BYTE; --create variable for procedure
				
				--Use the procedure IDLE with the signals and variables that it desires
				IDLE(RECIVED_DATA, STATE);
			end if;
		
		--Parse the command
		when TRANSLATE_CMD =>

			
			--Timeout counter		
					
			if TIMEOUT_COUNTER < Frequency/2-1 then --If not timeout yet, increase the counter
				TIMEOUT_COUNTER <= TIMEOUT_COUNTER + 1;
			end if;
			
			if VALID_DATA_IN = '1' then
			
				RECIVED_DATA := RXD_BYTE; --create variable for procedure
				
				--Use the procedure TRANSLATE with the signals and variables that it desires
				TRANSLATE(RECIVED_DATA, STATE, CMD, RAM_ADDR);
				TIMEOUT_COUNTER <= 0;
			
			elsif TIMEOUT_COUNTER >= Frequency/2-1 then
				
				STATE <= DO_CMD;
				CMD <= TIMEOUT;
				TIMEOUT_COUNTER <= 0;
			end if;
			
		--Do the command that was decided from TRANSLATE
		when DO_CMD =>

			RECIVED_DATA := RXD_BYTE;
			BYTE_COUNT_VAR := to_integer(BYTE_COUNTER); --create variables for procedure
			HEADER_COUNT_VAR := to_integer(HEADER_COUNTER);

			
			--Use the procedure DO_CMD with the signals and variables that it desires unless timeout
			DO_CMD(DATA => RECIVED_DATA,
					BYTE_COUNT => BYTE_COUNTER,
					HEADER_COUNT => HEADER_COUNTER, 
					CMD => CMD, 
					VALID_DATA_IN => VALID_DATA_IN,
					BYTE_COUNT_VAR => BYTE_COUNT_VAR, 
					HEADER_COUNT_VAR => HEADER_COUNT_VAR, --inputs
					STATE => STATE,
					RAM_ADDR => RAM_ADDR, 
					RAM_WE => RAM_WE, 
					VALID_DATA_OUT => VALID_DATA_OUT, 
					RAM_DATA_OUT => RAM_DATA_OUT, 
					TXD_BYTE => TXD_BYTE, 
					BYTE_COUNTER => BYTE_COUNTER, 
					HEADER_COUNTER => HEADER_COUNTER); --outputs
				
			--Timeout counter		
					
			if TIMEOUT_COUNTER < Frequency/2-1 then --If not timeout yet, increase the counter
				TIMEOUT_COUNTER <= TIMEOUT_COUNTER + 1;
			else --Timeout. Proceed to send *T
				CMD <= TIMEOUT;
				TIMEOUT_COUNTER <= 0;
			end if;		
		end case;
	end if;
end if;
end process;

end Behavioral;

