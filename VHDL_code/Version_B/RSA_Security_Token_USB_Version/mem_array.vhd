
--Copyright 2017 Gustav Örtenberg
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
use IEEE.NUMERIC_STD.ALL;
use std.textio.ALL;



entity mem_array is
	GENERIC(
		DATA_WIDTH : integer := 8;
		ADDR_WIDTH : integer := 6;
		INIT_FILE : string := "RAM.mif");
	Port(
		ADDR : in STD_LOGIC_VECTOR(ADDR_WIDTH-1 downto 0);
		DATAIN : in STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
		clk : in std_logic;
		WE : in std_logic;
		OUTPUT : out STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0)
	);
end mem_array;

architecture dataflow of mem_array is

	Type MEMORY_ARRAY is ARRAY (0 to 2**(ADDR_WIDTH)-1) of STD_LOGIC_VECTOR(DATA_WIDTH-1 downto 0);
		


impure function init_memory_wfile(mif_file_name : in string) return MEMORY_ARRAY is
    file mif_file : text open read_mode is mif_file_name;
    variable mif_line : line;
    variable temp_bv : bit_vector(DATA_WIDTH-1 downto 0);
    variable temp_mem : MEMORY_ARRAY;
begin
    for i in MEMORY_ARRAY'range loop
        readline(mif_file, mif_line);
        read(mif_line, temp_bv);
        temp_mem(i) := to_stdlogicvector(temp_bv);
    end loop;
    return temp_mem;
end function;

	signal memory : MEMORY_ARRAY;--:=(init_memory_wfile(INIT_FILE));

begin	



process(clk, WE)
   begin
	if (clk'EVENT and clk = '1') then
		if (WE = '1') then
			memory(to_integer(unsigned(ADDR))) <= DATAIN;
		end if;
	end if;
end process;

OUTPUT <= memory(to_integer(unsigned(ADDR)));

end dataflow;