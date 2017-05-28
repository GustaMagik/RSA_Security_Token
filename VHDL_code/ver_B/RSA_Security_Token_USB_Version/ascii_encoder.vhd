
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
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_MISC.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE IEEE.NUMERIC_STD.ALL;
-------------------------ASCII-Encoder------------------------------
--Takes a byte with 6-bits of data and maps it to alpha-numerical + 
--[ + { ascii chars and outputs it in byte size.
--------------------------------------------------------------------
Entity ascii_encoder is
	Port(input	: in STD_LOGIC_VECTOR (7 downto 0);
		output	: out STD_LOGIC_VECTOR (7 downto 0)
	);
end ascii_encoder;

architecture Behavioral of ascii_encoder is
signal i, u : unsigned(7 downto 0);
signal tmp : integer range 0 to ((2**7)-1);

begin
	i <= unsigned(input);
	tmp <= to_integer(i);
	with tmp select 
	u <=
		to_unsigned((tmp+48),8) when 0 to 9, 	--0 to 9
		to_unsigned((tmp+55),8) when 10 to 35, -- A to Z 
		to_unsigned(33,8) 			when 36 ,      -- !
		to_unsigned((tmp+60),8) when 37 to 62, -- a to z
		to_unsigned(34,8)			when 63,			-- "
		"00111111" when others; --?
	output <= STD_LOGIC_VECTOR(u);
end Behavioral;

