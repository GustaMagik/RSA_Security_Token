
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

--Wrapper for everything USB


-------------------------------------------------------------------------------------
--Communicates over an USB UART port
--Implements a simple request-response protocol
--The commands from the PC -> response from token
--
--*I -> *IHEJ (ID)
--*W[64 byte] -> *D if successful, *T if timeout, *B if device busy with other task
--*R -> *M[64 byte] if data ready, *B if device busy with other task
--
-------------------------------------------------------------------------------------

entity USB_TOP is
	generic ( data_addr_width : integer := 6;
				BAUD_RATE : integer := 115200; --baud of 115200
				 CLOCK_RATE : integer := 100_000_000; --100MHz
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
end USB_TOP;

architecture Behavioral of USB_TOP is

component FIFO_TXD IS
  PORT (
    clk : IN STD_LOGIC;
    rst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC
  );
END component;


component TXD_Controller is
	 Generic (BAUD_RATE : integer := BAUD_RATE; --baud of 115200
				 CLOCK_RATE : integer := CLOCK_RATE; --100MHz
				 OVERSAMPLES : integer := OVERSAMPLES);
				 
    Port ( CLK : in  STD_LOGIC; --Global clock	
			  RESET : in STD_LOGIC; --reset signal (synchronous)
           TXD_PIN : out  STD_LOGIC; --data pin
           FIFO_DATA_IN : in  STD_LOGIC_VECTOR (7 downto 0); --byte from FIFO
           FIFO_READ : out  STD_LOGIC; --Read next signal to the FIFO
           FIFO_EMPTY : in  STD_LOGIC); --Flag from FIFO to signal if the FIFO is empty or not
end component;

component RXD_Controller is

Generic (Baud_Rate : integer := BAUD_RATE; --Baud of 115200
	  CLOCK_RATE : integer := CLOCK_RATE; --100MHz
	  OVERSAMPLES : integer := OVERSAMPLES);

Port(
	CLK : in STD_LOGIC;
	RESET : in STD_LOGIC;
	RXD_PIN : in STD_LOGIC;
	RXD_BYTE : out STD_LOGIC_VECTOR(7 downto 0);
	VALID_DATA_IN : out STD_LOGIC);
	end component;

component USB_CMD_PARSER is
	generic ( data_addr_width : integer := data_addr_width;
				Frequency : integer := CLOCK_RATE);
    Port ( RXD_BYTE 			: in  STD_LOGIC_VECTOR (7 downto 0);						--Input byte from the serial-to-parallell translator
           TXD_BYTE 			: out STD_LOGIC_VECTOR (7 downto 0);						--Output byte to the parallell-to-serial translator
           RAM_ADDR 			: out STD_LOGIC_VECTOR (data_addr_width-1 downto 0);	--RAM ADDR where the RSA (signed) message is
           RAM_DATA_IN 		: in  STD_LOGIC_VECTOR (7 downto 0);						--DATA from the active RAM cell
           RAM_DATA_OUT 	: out STD_LOGIC_VECTOR (7 downto 0);						--DATA to be written to active RAM cell if WE is high
			  VALID_DATA_IN 	: in  STD_LOGIC;													--Flag to the parallell-to-serial translator to tell it that there's a new byte on the bus 
           VALID_DATA_OUT 	: out STD_LOGIC;													--Flag from the serial-to-parallell translator to tell that there's a new byte on the bus
			  RAM_WE 			: out STD_LOGIC;													--RAM Write Enable flag
			  RSA_DONE 			: in 	STD_LOGIC;													--Flag from RSA module that the values in RAM are the signed message
			  READY_FOR_DATA 	: in 	STD_LOGIC;													--Flag from RSA module that it is ready to recive a new message to sign
			  RESET 				: in 	STD_LOGIC;													--Reset for module. When high all registers and counters resets at next high flank of the clock
           CLK 				: in  STD_LOGIC;													--Global clock signal
			  DATA_READY 		: out  STD_LOGIC;
			  FIFO_EMPTY		: in STD_LOGIC);
end component;

signal RXD_BYTE, TXD_BYTE, FIFO_DATA_OUT, FIFO_DATA_IN : STD_LOGIC_VECTOR(7 downto 0);
signal VALID_DATA_IN, VALID_DATA_OUT, FIFO_READ, FIFO_EMPTY : STD_LOGIC;


begin

TXD_CONTRL: TXD_Controller port map(
	CLK => CLK,
	RESET => RESET,
	TXD_PIN => TXD,
	FIFO_DATA_IN => FIFO_DATA_OUT, --confusing name. DATA is OUT from FIFO and is IN to TXD
	FIFO_READ => FIFO_READ,
	FIFO_EMPTY => FIFO_EMPTY 
	);

RXD_CONTRL: RXD_Controller port map(
	CLK => CLK,
	RESET => RESET,
	RXD_PIN => RXD,
	RXD_BYTE => RXD_BYTE,
	VALID_DATA_IN => VALID_DATA_IN);
	

CMD_PARSER: USB_CMD_PARSER port map(
	RXD_BYTE => RXD_BYTE,
   TXD_BYTE => TXD_BYTE,
   RAM_ADDR => RAM_ADDR,
   RAM_DATA_IN => RAM_DATA_IN,
   RAM_DATA_OUT => RAM_DATA_OUT,
	VALID_DATA_IN => VALID_DATA_IN,
   VALID_DATA_OUT => VALID_DATA_OUT,
	RAM_WE => RAM_WE,
	RSA_DONE => RSA_DONE,
	READY_FOR_DATA => READY_FOR_DATA,
	DATA_READY => DATA_READY,
	RESET => RESET,
   CLK => CLK,
	FIFO_EMPTY => FIFO_EMPTY);

FIFO: FIFO_TXD PORT MAP(
    clk => CLK,
    rst => RESET,
    din => TXD_BYTE,
    wr_en => VALID_DATA_OUT,
    rd_en => FIFO_READ,
    dout => FIFO_DATA_OUT,
    full => open,
    empty => FIFO_EMPTY
  );
end Behavioral;

