
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
use IEEE.NUMERIC_STD.ALL;

entity TXD_Controller is
	 Generic (BAUD_RATE : integer; --Baud of this port
				 CLOCK_RATE : integer; --Frequency of the CLK. Needed to perform correct sampling
				 OVERSAMPLES : integer := 4);
				 
    Port ( CLK : in  STD_LOGIC; --Global clock	
			  RESET : in STD_LOGIC; --reset signal (synchronous)
           TXD_PIN : out  STD_LOGIC; --data pin
           FIFO_DATA_IN : in  STD_LOGIC_VECTOR (7 downto 0); --byte from FIFO
           FIFO_READ : out  STD_LOGIC; --Read next signal to the FIFO
           FIFO_EMPTY : in  STD_LOGIC); --Flag from FIFO to signal if the FIFO is empty or not
end TXD_Controller;

--This module handles transmission of bytes (8 bit) from a FIFO to a serial port (UART)

architecture Behavioral of TXD_Controller is

type STATES is (IDLE, START, DATA, STOP);
signal STATE : STATES := IDLE;
signal SAMPLE_COUNTER : integer := 0;
signal SAMPLE_COUNT : integer range 0 to OVERSAMPLES := 1;
signal bit_counter : integer range 0 to 8 := 0;
signal SAMPLE_NOW, BYTE_SENT, over_sampling_done : STD_LOGIC := '0';


begin


oversampler: process (CLK) 

	constant RATE_OF_SAMPLING : integer := CLOCK_RATE/BAUD_RATE/OVERSAMPLES; --How many cycles beween each sample
	variable CURRENT_SAMPLE_COUNTER : integer := 0;

	
	begin
		if rising_edge(CLK) then
		SAMPLE_NOW <= '0'; --Default is to NOT sample now
		over_sampling_done <= '0'; --Default is that the sampling is not done
			if RESET = '1' then --If reset signal
				SAMPLE_COUNTER <= 0; --reset counter
				
			--If not reset perform standard behaviour	
			elsif STATE /= IDLE then --We need sampling in every state but IDLE
				CURRENT_SAMPLE_COUNTER := SAMPLE_COUNTER;
				if CURRENT_SAMPLE_COUNTER < RATE_OF_SAMPLING then --If less than the sampling rate we are just to increase the counter
					SAMPLE_COUNTER <= SAMPLE_COUNTER + 1;
				else --otherwise we put SAMPLE_NOW to high and reset the counter
					SAMPLE_COUNTER <= 0;
					SAMPLE_NOW <= '1';
					SAMPLE_COUNT <= SAMPLE_COUNT + 1; --count which sample it was
					--count the amount of samples done and when the 4th is done 
					if SAMPLE_COUNT = OVERSAMPLES - 1 then --signal that the oversampling is done
						over_sampling_done <= '1';
						SAMPLE_COUNT <= 0;
					end if;
					
				end if;
			end if;
		end if;
	end process;
	
State_process: process (CLK)

begin
	if rising_edge(CLK) then
		if RESET = '1' then --If reset, return to known state
			STATE <= IDLE;
			FIFO_READ <= '0';
		else
					FIFO_READ <= '0'; --Do NOT read any more bytes from the FIFO than the absolute first one

			case STATE is
			
				when IDLE => 
					if FIFO_EMPTY = '0' then --Do nothing until there's a byte in the FIFO to work on
						STATE <= START;
						FIFO_READ <= '1'; --Read the byte from FIFO. Data will remain on FIFO_DATA_IN
						
					end if;
				
				when START =>
					if (over_sampling_done = '1') then --wait for the start signal to be on the pin long enough
						STATE <= DATA;	   --Go to the data transmit state
					end if;
				when DATA => 		
					
					if BYTE_SENT = '1' then --IFF we have sent the ENTIRE byte we can move on to the STOP state, otherwise we have to remain here
						state <= STOP;
					end if;
				
				when STOP =>
				
				if over_sampling_done = '1' then
					if FIFO_EMPTY = '1' then --FIFO empty, return to idle
						STATE <= IDLE;
					else 							--FIFO not empty, return to start
						STATE <= START;
						FIFO_READ <= '1'; --Read the byte from FIFO. Data will remain on FIFO_DATA_IN
					end if;
				end if;
				when others => 
						STATE <= IDLE; --Catch all state that returns us to known state
				end case;
			end if;
		end if;
	end process;



TXD_process: process(CLK)

begin

	if rising_edge(CLK) then
	--Standard is that this signals are low
	BYTE_SENT <= '0';
	
	
		if RESET = '1' then
			TXD_PIN <= '1'; --Drive pin high if reset as this is the idle state
			bit_counter <= 0; --Reset the counters
			
		else
			if SAMPLE_NOW = '1' then --If we are to sample now
			
			case STATE is
				when IDLE => 
					TXD_PIN <= '1'; --Drive the pin high when idle as we have no data now
					bit_counter <= 0;
					
				when START =>
					
					TXD_PIN <= '0'; --Drive the pin low to signal that there's data on the way
					
				when DATA =>
				
					TXD_PIN <= FIFO_DATA_IN(bit_counter); --Drive the pin with the correct bit
					if over_sampling_done = '1' then
						bit_counter <= bit_counter + 1;
					end if;
				when STOP =>
					
					TXD_PIN <= '1'; --set the pin back to the idle state
					bit_counter <= 0;

					
				when others => --assume others = IDLE
					TXD_PIN <= '1'; --Drive the pin high when idle as we have no data now
					bit_counter <= 0;

					
				end case;
				
				--generate signal for byte transfered and reset the bit counter
				if bit_counter = 7 and over_sampling_done = '1' then
					bit_counter <= 0;
					BYTE_SENT <= '1';
				end if;
			end if;
		end if;
	end if;
end process;
				

end Behavioral;

