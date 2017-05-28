--Copyright 2017 Christoffer Mathiesen
---Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
---
---1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
---
---2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the 
---documentation and/or other materials provided with the distribution.
---
---3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this 
---software without specific prior written permission.
---
---THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
---THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
---BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
---GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
---LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.STD_LOGIC_MISC.all;
use IEEE.NUMERIC_STD.all;

Entity USB_tb is
end USB_tb;

---This testbench shows a simple write request followed up by a read request.
---The data is not encrypted in this tb
---The tb is self-testing, but the main purpose of it is to make
---waveforms so that you can check your own implementation
---It should be possible to use this code for testing if other frequencies/baud rates
---are faulty.


Architecture behavioral of USB_tb is

constant BAUD_RATE : integer := 115200; --baud of 115200
constant CLOCK_RATE : integer := 100_000_000; --100MHz (10 ns)


Component USB_TOP is
	generic ( data_addr_width : integer := 6;
				BAUD_RATE : integer := BAUD_RATE; --baud of 115200
				 CLOCK_RATE : integer := CLOCK_RATE; --100MHz (10 ns)
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

Component mem_array is
	GENERIC(
		DATA_WIDTH : integer := 8;
		ADDR_WIDTH : integer := 6);
	Port(
		ADDR : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
		DATAIN : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
		clk : in std_logic;
		WE : in std_logic;
		OUTPUT : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
	);
end component;


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

constant clk_period : time := 1 sec * 1/CLOCK_RATE;
constant bit_period : time := clk_period*CLOCK_RATE/BAUD_RATE;


signal bool : boolean := true;

Signal TXD_PIN, RXD_PIN, READY_FOR_DATA, RSA_DONE, DATA_READY, CLK, RESET, RAM_WE : STD_LOGIC := '0';
Signal RAM_DATA_IN, RAM_DATA_OUT : STD_LOGIC_VECTOR(7 downto 0);
Signal RAM_ADDR : STD_LOGIC_VECTOR(5 downto 0);
signal done : std_logic := '0';

signal tst_data : STD_LOGIC_VECTOR(7 downto 0);
signal TMP : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
begin
test_USB_TOP: USB_TOP Port Map(CLK => CLK,
			  RESET => RESET,
           TXD => TXD_PIN, 
           RXD => RXD_PIN,
           RAM_ADDR => RAM_ADDR,
           RAM_DATA_IN => RAM_DATA_OUT,
           RAM_DATA_OUT => RAM_DATA_IN,
           RAM_WE => RAM_WE,
           READY_FOR_DATA => READY_FOR_DATA,
           RSA_DONE => RSA_DONE,
			  DATA_READY => DATA_READY);
              
test_RAM: mem_array Port Map (    
        ADDR => RAM_ADDR,
		DATAIN => RAM_DATA_IN,
		clk => clk,
		WE => RAM_WE,
		OUTPUT => RAM_DATA_OUT
	);         
             


--Create the clock
process
begin
CLK <= NOT CLK;
wait for clk_period/2;
end process;

--Main test process
process

begin

--first reset the circuits

reset <= '1';
RXD_PIN <= '1';
wait for clk_period*10;
reset <= '0';
wait for clk_period;

--Set so that we can get, but not send data.
READY_FOR_DATA <= '1';
RSA_DONE <= '0';

--Start transmission into the circuit

RXD_PIN <= '0'; --start bit

wait for bit_period; --time it takes to transmit one bit with 100MHz and 115200 baud

--Send *
for I in 0 to 7 loop
    RXD_PIN <= ASCII_ASTERISK(I);
    wait for bit_period;
end loop;

RXD_PIN <= '1'; --stop bit

wait for bit_period*2;

RXD_PIN <= '0'; --start bit

wait for bit_period;

--Send W
for I in 0 to 7 loop
    RXD_PIN <= ASCII_W(I);
    wait for bit_period;
end loop;

RXD_PIN <= '1'; --stop bit

wait for bit_period;


--send 64 bytes of data. Use the tst_data and dec by 1 each itteration

for I in 0 to 63 loop

    TMP <= STD_LOGIC_VECTOR(to_unsigned(I,8));
    RXD_PIN <= '0'; --start bit
    wait for bit_period;
    
    --send the data
    for J in 0 to 7 loop
        RXD_PIN <= TMP(J);
        if I < 63 or J < 7 then --last time we can't wait as we need to check the RAM
            wait for bit_period;
        end if;
    end loop;


if I = 63 then
    wait until RAM_WE = '0';
    wait for clk_period;
end if;

    RXD_PIN <= '1'; --stop bit

    
    --report errors
    assert RAM_DATA_OUT = TMP
        report "The value put to memory is not the same as the one written on the RXD_PIN!"
        severity error;
    
    wait for bit_period;    
end loop;


--Now we should have values in the memory. Simulate that we have encrypted them by setting flags
READY_FOR_DATA <= '0';
RSA_DONE <= '1';
    
--Send request *R

wait for bit_period * 25;


RXD_PIN <= '0'; --start bit

wait for bit_period*1; --time it takes to transmit one bit with 100MHz and 115200 baud

--Send *
for I in 0 to 7 loop
    RXD_PIN <= ASCII_ASTERISK(I);
    wait for bit_period;
end loop;

RXD_PIN <= '1'; --stop bit

wait for bit_period;

RXD_PIN <= '0'; --start bit

wait for bit_period;
--Send R
for I in 0 to 7 loop
    RXD_PIN <= ASCII_R(I);
    if I < 7 then
        wait for bit_period;
    end if;
end loop;



--wait for clk_period;

--Now it should start reading the memory, put it into the FIFO and then the TXD will start transmitting

wait until TXD_PIN = '0'; --wait until the start bit on TXD
RXD_PIN <= '1'; --stop bit
wait for bit_period*3/2; --set to halfway into a bit-transmission

    for J in 0 to 7 loop
        tst_data(J) <= TXD_PIN;
        wait for bit_period;
    end loop;
   
assert tst_data = ASCII_ASTERISK
        report "The first character sent is not '*'!"
        severity error;
        
wait until TXD_PIN = '0';
wait for bit_period*3/2;

    for J in 0 to 7 loop
        tst_data(J) <= TXD_PIN;
        wait for bit_period;
    end loop;
    
assert tst_data = ASCII_M
    report "The second character sent is not 'M'!"
    severity error;

wait until TXD_PIN = '0';
wait for bit_period*3/2;

for I in 0 to 63 loop
    
    TMP <= STD_LOGIC_VECTOR(to_unsigned(I,8));
    --send the data
    for J in 0 to 7 loop
        tst_data(J) <= TXD_PIN;
        wait for bit_period;
    end loop;

    bool <= to_integer(unsigned(tst_data)) = to_integer(unsigned(tmp));
    wait for 0 ns; --update bool
    --report errors
    assert bool
        report "The value out from TXD_PIN is not the same as the one written previously!"
        severity error;

    if I < 63 then    
      wait until TXD_PIN = '0'; --Wait for start bit
      wait for bit_period*3/2;
    end if;
end loop;

done <= '1';
wait for clk_period;
report "Testbench complete! If no errors, run was successful!" severity FAILURE;     
wait;
end process;

--timeout
process
begin
wait for 5000*bit_period;
report "Testbench failed! Something hanged!" severity failure;
wait;
end process;


end behavioral;
