
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
use IEEE.numeric_std.all;

entity RXD_Controller is

Generic (Baud_Rate : integer; --Baud of this port
	  CLOCK_RATE : integer;   --Frequency of the CLK. Needed to perform correct sampling
	  OVERSAMPLES : integer := 4);

Port(	CLK		: in STD_LOGIC;
	RESET		   : in STD_LOGIC;
	RXD_PIN		: in STD_LOGIC;
	RXD_BYTE 	: out STD_LOGIC_VECTOR(7 downto 0);
	VALID_DATA_IN		: out STD_LOGIC := '0'
);
end RXD_Controller;

--This module handles reciving of bytes (8 bit) from a serial port (UART)

architecture Behavioral of RXD_Controller is

	type STATES is (IDLE, START, DATA, STOP);
	signal state	: STATES := IDLE;
	signal bit_counter : integer range 0 to 8 := 0;
	signal middle	: STD_LOGIC;
	signal over_sampling_done : STD_LOGIC := '0';
	signal SAMPLE_COUNTER : integer := 0;
	signal SAMPLE_COUNT : integer range 0 to OVERSAMPLES;
	signal SAMPLE_NOW : STD_LOGIC;
begin

-- Handle the oversampler	
oversampler: process (CLK) 

	constant RATE_OF_SAMPLING : integer := CLOCK_RATE/BAUD_RATE/OVERSAMPLES; --How many cycles beween each sample
	variable CURRENT_SAMPLE_COUNTER : integer := 0;

	
	begin
		if rising_edge(CLK) then
		SAMPLE_NOW <= '0'; --Default is to NOT sample now
		over_sampling_done <= '0'; --Default is that the sampling is not done
		middle <= '0'; --Default is that the sample is NOT the middle one
			if RESET = '1' then --If reset signal
				SAMPLE_COUNTER <= 0;
				SAMPLE_COUNT <= 0;--reset counter
			elsif STATE = IDLE then
				SAMPLE_COUNTER <= 0; 
				SAMPLE_COUNT <= 0;
			--If not reset perform standard behaviour	
			elsif STATE /= IDLE then --We need sampling in every state but IDLE
				CURRENT_SAMPLE_COUNTER := SAMPLE_COUNTER;
				if CURRENT_SAMPLE_COUNTER < RATE_OF_SAMPLING then --If less than the sampling rate we are to increase the counter
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
					if SAMPLE_COUNT = OVERSAMPLES/2-1 then --signal that we have done half of the samples
						middle <= '1';
					end if;
					
				end if;
			end if;
		end if;
	end process;
	


-- Compute the next state
stateProcess: process(CLK)
begin
if rising_edge(CLK) then
	if RESET = '1' then
		state <= IDLE;
	else
	
		case state is
			when IDLE => 
				
				if RXD_PIN = '0' then --Start bit?
					STATE <= START;
				end if;

			when START =>
				--check if start bit
				if middle = '1' then
					if RXD_PIN = '0' then --Start bit confirmed
						state <= DATA;
					else --Start bit not confirmed
						state <= IDLE;
					end if;
				end if;
			when DATA => --Receive data
				if bit_counter >= 8 then --All bits accounted for
			 		state <= STOP; --Set stop bit
					VALID_DATA_IN <= '1'; --Signal that valid data is on the bus
				end if;
			when STOP =>
			VALID_DATA_IN <= '0'; --Stop signaling as we only want this flag to be high one cycle
				if middle = '1' and RXD_PIN = '1' then --when enough time has passed and the pin is reset to IDLE state
					state <= IDLE; --go back to IDLE
				end if;
			when others =>
				state <= IDLE;
		end case;
	end if;
end if;
end process stateProcess;

-- Tracking the bits
bitTracker: process (CLK)
begin
if rising_edge(CLK) then
	if RESET = '1' then
		bit_counter <= 0;
	else
		if middle = '1' then
			if state = START then
				bit_counter <= 0;
			elsif state = DATA then
				bit_counter <= bit_counter + 1;
			end if;
		end if;
	end if;
end if;
end process bitTracker;

-- Controlling the data
readyController: process (CLK)
begin
if rising_edge(CLK) then
	if RESET = '1' then --Reset regiseters and signal to known value
		RXD_BYTE <= x"00";
	else
			if middle = '1' then
				if state = DATA AND bit_counter < 8 then
					RXD_BYTE(bit_counter) <= RXD_PIN;
				elsif state = STOP then
				end if;
			end if;
		end if;
	end if;
end process readyController;

end Behavioral;