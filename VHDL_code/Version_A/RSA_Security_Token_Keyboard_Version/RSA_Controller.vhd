
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

----------------------------RSA_Top_Module-----------------------------
--
-----------------------------------------------------------------------
Entity RSA_Controller is
	Generic( 		i : integer;
				Mem_addr_width : integer;
				e_val : STD_LOGIC_VECTOR;
				N_val : STD_LOGIC_VECTOR);--length of crypto in bits
	Port(clk		: in STD_LOGIC;
		resetN	: in STD_LOGIC;
		done		: out STD_LOGIC;
		mem_we	: out STD_LOGIC;
		input_addr: in STD_LOGIC_VECTOR (mem_addr_width downto 0);
		mem_addr : out STD_LOGIC_VECTOR(mem_addr_width downto 0) := (others => '0');
		mem_data : in STD_LOGIC_VECTOR(7 downto 0);
		data_out : out STD_LOGIC_VECTOR(7 downto 0)
		);
end RSA_Controller;

architecture Behavioral of RSA_Controller is
function CounterSize (X : integer)
	return integer is
	
	variable POWER : integer := 1;
	variable RET : integer := 0;
	begin

	while (POWER < X) loop
		POWER := POWER * 2;
		RET := RET + 1;
	end loop;
	return RET;
end CounterSize;
type CMD is (GET_MSG, CTxCT, CTxMSG, WRITE_ENCRYPTED, COMPLETE);
signal state : CMD := COMPLETE;
signal mult_operator1, mult_operator2, ct, res, msg : STD_LOGIC_VECTOR( i-1 downto 0);
signal do_mult, reset, mult_done, first, second, third : STD_LOGIC;
signal mem_addr_saved : unsigned(5 downto 0) := (others => '0');
signal counter : unsigned (4 downto 0) := (others => '0');
signal itteration : unsigned (CounterSize(i)-1 downto 0) := (others => '0');
constant e : STD_LOGIC_VECTOR(i-1 downto 0) := e_val;
constant i_byte : integer := i/8;
signal resetN_s : STD_LOGIC;

component modmult is
	Generic (MPWID	: integer := i);
   Port ( mpand 	: in std_logic_vector(MPWID-1 downto 0);
          mplier 	: in std_logic_vector(MPWID-1 downto 0);
          modulus 	: in std_logic_vector(MPWID-1 downto 0);
          product 	: out std_logic_vector(MPWID-1 downto 0);
          clk 		: in std_logic;
	  ds 		: in std_logic;
	  reset 	: in std_logic;
	  ready 	: out std_logic);
end component;


begin

Mod_Multiplier: modmult Port map ( 
	clk 		=> clk,
   mpand 	=>	mult_operator1,
	mplier 	=>	mult_operator2,
	modulus  =>	N_val,
	product 	=> res,
	ds 		=> do_mult,
	reset		=> resetN_s,
	ready 	=>	mult_done
	);


resetN_s <= NOT resetN;

rsa:process(clk)
begin
	if(rising_edge(clk)) then
		if(resetN = '0') then
			
			--Reset all the operators to initial values
			mult_operator1 <= (others => '0');
			mult_operator2 <= (others => '0');
			ct 				<= (others => '0');
			ct(0) 			<= '1';
			counter 			<= (others => '0');
			itteration 		<= (others => '0');
			msg 				<= (others => '0');

			--Reset all flags to inital value
			do_mult 			<= '0';
			done 				<= '0';
			mem_we			<= '0';
			first 			<= '0';
			second 			<= '0';
			third				<= '0';
			state 			<= GET_MSG;

			--reset memory_pointers
			mem_addr_saved <= unsigned(input_addr);
			mem_addr <= (others => '0');
		else
			
			case state is 
			
			
			
				when GET_MSG =>
				reset <= '0';
				counter <= counter + 1;
				mem_addr <= STD_LOGIC_VECTOR(mem_addr_saved + counter + 1);
					
					if counter > 0 then
					msg((to_integer(counter*8 - 1)) downto (to_integer(counter*8 - 8))) <= mem_data;
					
						if(counter = i_byte) then
							state <= CTxCT;
							itteration <= (others => '1');
							counter <= (others => '0');
							mem_addr <= STD_LOGIC_VECTOR(mem_addr_saved);
						end if;
						
					end if;
					
				when CTxCT =>
					if first = '0' then
						do_mult <= '1';
						first <= '1';
						itteration <= itteration + 1;
						
					else 
						do_mult <= '0';
						second <= '1';
					end if;
					
					if first = '0' then	
						mult_operator1 <= ct;
						mult_operator2 <= ct;
						--reset 			<= '0';
					elsif mult_done = '1' and second = '1' and third = '1' then
						
						first 		<= '0';
						do_mult <= '0';
						second <= '0';
						third <= '0';
						ct <= res;
						--e 				<= e srl 1;
						if e(to_integer(i-1-itteration)) = '0' then
							
							
							state <= CTxCT;
							
							if itteration = i-1 then 
								state <= WRITE_ENCRYPTED;
							end if;
							
						else
							state <= CTxMSG;
						end if;
						
					elsif mult_done = '1' and second = '1' and third = '0' then
						third <= '1';
						do_mult <= '0';
					end if;
					
					
				when CTxMSG =>
					if first = '0' then
						do_mult <= '1';
						first <= '1';
						
					else
						second <= '1';
						do_mult <= '0';
					end if;
					
					if first = '0' then
						mult_operator1 <= ct;
						mult_operator2 <= msg;
						--reset				<= '0';
					elsif mult_done = '1' and second = '1' and third = '1' then
						
						first <= '0';
						second <= '0';
						third <= '0';
						counter <= (others => '0');
						do_mult <= '0';
						ct 	<= res;
						
						if itteration = i-1 then	
							state <= WRITE_ENCRYPTED;
							counter <= (others => '0');
						else
							state <= CTxCT;
						end if;
					elsif mult_done = '1' and second = '1' and third = '0' then
						third <= '1';
						do_mult <= '0';
					end if;
					

				when WRITE_ENCRYPTED =>
				
				if first = '0' then
					ct 	<= res;
					first <= '1';
					mem_we <= '1';
				else
					
					counter <= counter + 1;
					data_out <= ct(to_integer(counter)*8 + 7 downto to_integer(counter)*8);
					mem_addr <= STD_LOGIC_VECTOR(mem_addr_saved + counter + 1);
						if(counter = i_byte-1) then
							state <= COMPLETE;
						end if;
				end if;	
				when others => 
					done <= '1';
					mem_we <= '0';
					
			end case;
		end if;
	end if;
end process;
end Behavioral;
