
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

Entity Keyboard is
	Port ( 	Row_Input 	: in 	STD_LOGIC_VECTOR (3 downto 0);
		Col_Input_A	: out 	STD_LOGIC_VECTOR (3 downto 0) := (others => '1');
		Output 		: out 	STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
		RDY		: out 	STD_LOGIC := '0';
		CLK		: in 	STD_LOGIC;
		ARESETN 	: in	STD_LOGIC
		);
end Keyboard; 
--------------------------------------------------------------------------------------
--This is a translator for the Keypad v3.0 to hex.
--To be connected to the outside world. First it debounces the signal.
--It takes the 8 bit wide input and translates it down to the corresponding hex value.
--Any input besides the accepted ones gives output 0 and the RDY-bit to 0.
--When an accepted input is parsed the module sets the RDY-bit to 1.
--------------------------------------------------------------------------------------
architecture Behaviour of Keyboard is
component Debouncer
		port(	Input 	: in 	STD_LOGIC;
		Output 	: out 	STD_LOGIC;
		CLK	: in 	STD_LOGIC
		);
end component;

type input_vector is array (3 downto 0) of STD_LOGIC;

signal input_debounced : STD_LOGIC_VECTOR (3 downto 0);
signal  input_vector_tmp: input_vector := (others => '0');
signal counter : unsigned (11 downto 0) := (others => '0');
signal translated : STD_LOGIC_VECTOR (7 downto 0) := "00000000";
Begin

Process (CLK)
Begin
	if rising_edge(CLK) then
	
	input_debounced <= Row_Input;
		IF ARESETN = '1' THEN
		if input_debounced = "0000" and counter = "0000" then
			--counter <= "0000";
			RDY <= '0';
			translated <= (others => '0');
		else 
			if counter = to_unsigned(0, 12) then 	Col_Input_A <= "0001";
			elsif counter = to_unsigned(500, 12) then	--Wait for 500 cycles 
					if input_debounced /= "0000" then
					translated <= STD_LOGIC_VECTOR(input_debounced) & "0001";
					end if;
					Col_Input_A <= "0010";
			elsif counter = to_unsigned(1000, 12) then--Wait for 500 cycles
					if input_debounced /= "0000" then
					translated <= translated or STD_LOGIC_VECTOR(input_debounced) & "0010";
					end if;					
					Col_Input_A <= "0100";
			elsif counter = to_unsigned(1500, 12) then	--Wait for 500 cycles
					if input_debounced /= "0000" then
					translated <= translated or STD_LOGIC_VECTOR(input_debounced) & "0100";
					end if;
					Col_Input_A <= "1000";
			elsif counter = to_unsigned(2000, 12) then --Wait for 500 cycles
					if input_debounced /= "0000" then
					translated <= translated or STD_LOGIC_VECTOR(input_debounced) & "1000";
					end if;
					Col_Input_A <= "1111";
			else 
			end if;
			if counter /= to_unsigned(4000, 12) then --Wait for 2000 cycles fom previous step
				counter <= counter + 1; 
			elsif input_debounced = "0000" then	--Wait for release of button
				counter <= (others => '0');
----------------------------------------------------------------------------------
--Case for translations. In order of magnitude.
--Input is in the format 7 downto 4 row, 3 downto 0 col.
--I.e. the vector 0100 0001 is row 3, col 1.
---------------------------------------------------------------------------------
			Translate: case translated is 
				when "10000010" => 	
							RDY <= '1'; 		--0
							Output <= "0000";
				when "00010001" => 	
							RDY <= '1'; 		--1
							Output <= "0001";
				when "00010010" =>	
							RDY <= '1'; 		--2
							Output <= "0010";
				when "00010100" => 	
							RDY <= '1'; 		--3
							Output <= "0011";
				when "00100001" => 	
							RDY <= '1'; 		--4
							Output <= "0100";
				when "00100010" => 	
							RDY <= '1'; 		--5
							Output <= "0101";
				when "00100100" => 	
							RDY <= '1'; 		--6
							Output <= "0110";
				when "01000001" => 	
							RDY <= '1'; 		--7
							Output <= "0111";
				when "01000010" => 
							RDY <= '1'; 		--8
							Output <= "1000";
				when "01000100" => 	
							RDY <= '1'; 		--9
							Output <= "1001";
				when "00011000" => 	
							RDY <= '1'; 		--A
							Output <= "1010";
				when "00101000" => 	
							RDY <= '1'; 		--B
							Output <= "1011";
				when "01001000" => 	
							RDY <= '1'; 		--C
							Output <= "1100";
				when "10001000" => 	 
							RDY <= '1'; 		--D
							Output <= "1101";
				when "10000100" => 	
							RDY <= '1'; 		--E
							Output <= "1110";
				when "10000001" => 	
							RDY <= '1'; 		--F
							Output <= "1111";
				when others => 		
							RDY <= '0'; 		--Others
							
				end case Translate;
				end if;
			end if;
		elsif ARESETN = '0' then
			RDY 			<= '0';
			Output	 		<= (others => '0');			--Reset
			--input_debounced 	<= (others => '0');
--			input_vector_debounced 	<= (others => '0');
			translated 		<= (others => '0'); 
			counter 		<= (others => '0');	
			end if;
			end if;
	end process;
end Behaviour;
		