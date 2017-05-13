
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

----------------------------------------------------------------------------------
--This module splices memory(arrays) of 8 bits into 6 bit(arrays)
--When on the third byte it has to take a cycle to output the remaining 
--6 bits. Then it loops.
--Active as long as the input flag ACTICVE = '1'
--Asks the above module to increment the address pointer with INC_ADDR;
----------------------------------------------------------------------------------

entity byte_to_six_bit_splitter is
    Port ( DATA_IN 		: in  STD_LOGIC_VECTOR (7 downto 0);
           DATA_OUT 		: out STD_LOGIC_VECTOR (5 downto 0);
			  INC_ADDR		: out STD_LOGIC := '0';
			  ACTIVE			: in 	STD_LOGIC;
           CLK 			: in  STD_LOGIC;
           RESET 			: in  STD_LOGIC);
end byte_to_six_bit_splitter;

architecture Behavioral of byte_to_six_bit_splitter is

type Current is (WAIT_1, SIX_TWO, FOUR_FOUR, TWO_SIX, INTERMISSION);

signal State 	: Current := SIX_TWO;
signal TMP 		: STD_LOGIC_VECTOR (5 downto 0) := (others => '0');

begin

process (clk)
Begin
	if rising_edge(clk) then
		if ACTIVE = '1' then --and RESET = '0' then --State changes 
			case State is
				when INTERMISSION =>
					State <= SIX_TWO;
				when SIX_TWO =>
					State <= FOUR_FOUR;
				when FOUR_FOUR =>
					State <= TWO_SIX;
				when TWO_SIX =>
					State <= INTERMISSION; --Pause to give fourth 6-bit
				when others => 
					State <= SIX_TWO;
			end case;
			
			else 
				State <= SIX_TWO;

		
	--	elsif RESET = '1' then
			--TMP 			<= (others => '0');	
		--	State 		<= SIX_TWO;
			--INC_ADDR 	<= '0';
		end if;
	end if;
end process;

process (State, clk)
Begin
if rising_edge(clk) then
	
	case State is
		when SIX_TWO =>
			DATA_OUT 		<= DATA_IN(5 downto 0); 						--Output the 6 MSB of data in
			TMP(1 downto 0)<= DATA_IN(7 downto 6);						 	--Store the 2 LSB of data in
			INC_ADDR 		<= '1';												--Tell the above module to inc the RAM address
			
		when FOUR_FOUR =>
			DATA_OUT 		<= DATA_IN(3 downto 0) & TMP(1 downto 0); --Output the stored 2 bits as MSB and the 4 MSB of data in as LSB
			TMP(3 downto 0)<= DATA_IN(7 downto 4);							--Store the 4 LSB of data in
			INC_ADDR			<= '0';												--Tell the above module to inc the RAM address
			
		when TWO_SIX =>
			DATA_OUT 		<= DATA_IN(1 downto 0) & TMP(3 downto 0); --Output the stored 4 bits as MSB and the 2 MSB of data in as LSB
			TMP				<= DATA_IN(7 downto 2);							--Store the 6 LSB of data in
			INC_ADDR			<= '1';												--Tell the above module to inc the RAM address
			
		when INTERMISSION =>
			DATA_OUT 		<= TMP;												--Output the stored 6 bits as the complete vector
			INC_ADDR			<= '1';												--Tell the above module to NOT inc the RAM address
			
		when others =>
			INC_ADDR <= '1';
	end case;
end if;
end process;

end Behavioral;

