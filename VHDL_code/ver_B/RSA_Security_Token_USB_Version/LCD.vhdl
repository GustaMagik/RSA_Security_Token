
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
use work.all;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
-------------------------------------------------------------------------------
--FPGA to DMC16207 LCD interface. Takes care of inititation and after that sits
--ready to take commands from the top module to print, clear or row-change.
-------------------------------------------------------------------------------
entity LCD is
	 Generic ( Frequency : integer); --Needs to know the frequency the curcuit is running at
    Port (INPUT 	: in STD_LOGIC_VECTOR (7 downto 0); --ASCII IN
		CLK			: in STD_LOGIC;						--FPGA Clock (100MHz)
		RESET		: in STD_LOGIC;						--RESET
		DATA_BUS	: out STD_LOGIC_VECTOR (7 downto 0);--DB 7 downto DB 0
		RW			: out STD_LOGIC := '0';				--RW signal (unused as of now)
		RS			: out STD_LOGIC;					--RS signal
		E			: out STD_LOGIC;					--E (200Hz)
		MODE_SELECT : in STD_LOGIC_VECTOR (1 downto 0);	--Select cmd to be done
		RDY_CMD		: out STD_LOGIC := '0';				--Ready for cmd from top module
		DO_CMD		: in STD_LOGIC);					--Cmd to be done from top module
end LCD;






architecture Behaviour of LCD is
Signal INPUT_2 : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
Signal clock_div_1, clock_div_2: unsigned (7 downto 0) := (others => '0');
Signal clock_div_3, init_state : unsigned (3 downto 0) := (others => '0');
Signal E_toggle, e_step : STD_LOGIC := '0';
constant Clock_cutoff : integer := Frequency/800;
Signal Clock_div : integer range 0 to Frequency/800 := 0;


begin
-------------------------------------CLOCK DIVIDER----------------------------
--Divides a clock from FREQ to 400Hz
------------------------------------------------------------------------------
clock_divider: process (clk)
	begin
		if rising_edge(clk) then
			if RESET = '1' then
				Clock_div <= 0;
				E_toggle <= '0';
			else 
		
				if Clock_div < Clock_cutoff then --Inc the counter
					Clock_div <= Clock_div + 1;
				else --Happens at a frequency of 800Hz
					Clock_div <= 0; 
					E_toggle <= NOT E_toggle; --As this is the inverse of the previous signal, the E_toggle is at 400Hz
				end if;
			end if;
		end if;
end process;


---------------------------------State and Data changes------------------------
--Happens on high flank as on E low flank the action will be executed. Switches 
--between having the E 1 and 0 each high flank of E_toggle, and is as such half
--the frequency of E_toggle (200Hz).
-------------------------------------------------------------------------------
E_process: process (E_toggle)
	begin
		if rising_edge(E_toggle) then
			if e_step = '0' then
---------------------------------------------------Initilazion takes 8 E-cycles
				if init_state < 8 then
					init_state <= init_state + 1;
					e_step <= '1';
					case init_state is
						when x"4" => --Display OFF
							RS <= '0';
							RW <= '0';
							DATA_BUS <= "00001000";	
					
						when x"5" => --Clear Display
							RS <= '0';
							RW <= '0';
							DATA_BUS <= "00000001";
		
						when x"6" => --Entry Mode Set
							RS <= '0';
							RW <= '0';
							DATA_BUS <= "00000110";
		
						when x"7" => --Display ON (Blink and Cursor ON)
							RS <= '0';
							RW <= '0';
							DATA_BUS <= "00001111";
							RDY_CMD <= '1';

						when others => --Function set command (step 0,1,2,3)
 							RS <= '0';
							RW <= '0';
							DATA_BUS <= "00111100";

					end case;
-----------------------------------------------------Normal operation selection
				elsif DO_CMD = '1' then
					e_step <= '1';
					RDY_CMD <= '0';
					case MODE_SELECT is
						when "00" => --CLEAR DISPAY
							RS <= '0';
							RW <= '0';
							DATA_BUS <= "00000001";
							
						when "01" => --Print INPUT on DISPLAY
							RS <= '1';
							RW <= '0';
							DATA_BUS <= INPUT;
							
							if INPUT = "00000000" then --if char is '\0', don't print it
								e_step <= '0';
							end if;
							
						when "10" => --CHANGE ROW
							RS <= '0';
							RW <= '0';
							DATA_BUS <= "11000000";	
							
						when others => --CLEAR DISPLAY
							RS <= '0';
							RW <= '0';
							DATA_BUS <= "00000001";

					end case;
					
				else --Because we don't print '\0' we have to reset RDY_CMD here
					RDY_CMD <= '1';
				end if;
			else 
				e_step <= '0';
				RDY_CMD <= '1';
			end if;
			E <= e_step;
		end if;
	end process E_process;
	
	
end architecture;