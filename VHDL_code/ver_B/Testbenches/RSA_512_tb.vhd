
--Copyright 2017 Christoffer Mathiesen
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity RSA_512_tb is
end RSA_512_tb;

--This is an improved version of the tb from the original creators of 
--RSA_512. 
--The original can be found in the folder containing the RSA_512 code

--The tb is self-testing. If you want to check exponent- modulo- and r_c values of your own, you can freely insert them
--instead of the ones there currently. Take note that you'll have to MANUALLY calculate the result of the
--encryption of ( message_1^exponent_1 ) mod modulo_1
--Useful tool to do just that can be found at http://www.mobilefish.com/services/big_number_equation/big_number_equation.php#equation_output

--The tb will take about 0.6 ms of in-simulation time.

architecture behavior of RSA_512_tb is

  -- Component Declaration 

  component rsa_top
    port(
      clk       : in  std_logic;
      reset     : in  std_logic;
      valid_in  : in  std_logic;
      start_in  : in  std_logic;
      x         : in  std_logic_vector(15 downto 0);
      y         : in  std_logic_vector(15 downto 0);
      m         : in  std_logic_vector(15 downto 0);
      r_c       : in  std_logic_vector(15 downto 0);
      s         : out std_logic_vector(15 downto 0);
      valid_out : out std_logic;
      bit_size  : in  std_logic_vector(15 downto 0)
      );
  end component;

  --constants (values to test)
  constant sanity_check : std_logic_vector(511 downto 0) := x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001";--RSA with val 1 should always result in 1
  constant message_1    : std_logic_vector(511 downto 0) := x"abc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abcabc123abc123abc123abc123abc123abc123abc123abc123abc123abc123abc12";
  constant exponent_1   : std_logic_vector(511 downto 0) := x"b15f20094a5fbcd7605b23bb7dbe7d421556df00d266c649d019cfc87eae543f703f6870013851130d3a2ed993ef76a1c377a96b95fe326f7326a319bae5fe01"; --encrypt exponent
  constant exponent_2   : std_logic_vector(511 downto 0) := x"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010001"; --decrypt exponent
  constant modulo_1     : std_logic_vector(511 downto 0) := x"bb847f2d87e8030926eea2a0a3f89877e6f63c1e2f65f3791e9c85549f48863a1dcc9f8b477c36dfea2573c49fc59259efe83b9996d093b4be09666e904cb17f";
  constant R_C_1        : std_logic_vector(511 downto 0) := x"8F80651391C778113C509FDD5C205AE6648A94DBC225A1ECA53F149BCF135AFCAC7E47DF209AC030325E1904AD7D260E236CE56D6753F488E3E489D50A6C2B0E";
  
  constant result_1     : std_logic_vector(511 downto 0) := x"AF42E73EE103ED7F96C40FB6FC14B483031239E4FC813C30B208C68042C9E08789E5D22E59163194498D3DB158AC6F5282943D81D5E59F518086A19BC0B33D9D";--result encrypting message_1
  
  --Inputs 
  signal clk       : std_logic                     := '1';
  signal reset     : std_logic                     := '0';
  signal valid_in  : std_logic                     := '0';
  signal start_in  : std_logic                     := '0';
  signal x         : std_logic_vector(15 downto 0) := (others => '0');
  signal y         : std_logic_vector(15 downto 0) := (others => '0');
  signal m         : std_logic_vector(15 downto 0) := (others => '0');
  signal r_c       : std_logic_vector(15 downto 0) := (others => '0');
  signal bit_size  : std_logic_vector(15 downto 0) := x"0200";
  

  --Outputs 
  signal s         : std_logic_vector(15 downto 0);
  signal valid_out : std_logic;
  signal result    : std_logic_vector(511 downto 0) := (others => '0');

  -- Clock period definitions 
  constant clk_period : time := 1 ns;

  
  
  --resetting
  procedure reset_circuit (modulo : in STD_LOGIC_VECTOR(15 downto 0);
    signal reset, valid_in, start_in : out STD_LOGIC;
    signal m : out STD_LOGIC_VECTOR(15 downto 0)) is
    begin
    
    --hard reset
        valid_in <= '0';
        start_in <= '0';
        reset <= '1';
        wait for 10 ns;
        reset <= '0';
        wait for clk_period*10;

        
    --set up for n_c calculation
    
        m <= modulo;
        start_in <= '1';
        wait for clk_period;
        start_in <= '0';
        wait for clk_period*7;

    end procedure reset_circuit;
  
begin

  RSA_512 : rsa_top port map (
    clk       => clk,
    reset     => reset,
    valid_in  => valid_in,
    start_in  => start_in,
    x         => x,
    y         => y,
    m         => m,
    r_c       => r_c,
    s         => s,
    valid_out => valid_out,
    bit_size  => bit_size
    );

    --clock process
process
begin
    clk <= not clk;
    wait for clk_period/2;
end process;

    --Stimulus process
process
begin
    --Reset the circuit
    reset_circuit(modulo    => modulo_1(15 downto 0),
                  reset     => reset,
                  valid_in  => valid_in,
                  start_in  => start_in,
                  m         => m
                  );
    --Have a sanity check with the value 1. 

               for J in 0 to 31 loop
         valid_in <= '1';
         x <= sanity_check(16*J+15 downto 16*J);
         y <= exponent_1(16*J+15 downto 16*J);
         m <= modulo_1(16*J+15 downto 16*J);
         r_c <= r_c_1(16*J+15 downto 16*J);
         wait for clk_period;
     end loop;
     valid_in <= '0';
     wait until valid_out = '1';
 
 
     --read all 32 words
     for J in 0 to 31 loop 
         
         wait for clk_period;

         result(16*J+15 downto 16*J) <= s;

     end loop;

     wait for clk_period * 10;
     wait for clk_period/2;


    assert result = sanity_check
        report "The encrypted value was not 1 after encryption. Something is very wrong! Double check the validity of the Exponent, Modulo and R_C values"
        severity failure;
        
        --Reset the circuit
    reset_circuit(modulo    => modulo_1(15 downto 0),
                  reset     => reset,
                  valid_in  => valid_in,
                  start_in  => start_in,
                  m         => m
                  );
                  
    --Try to encrypt the message message_1. 
               for J in 0 to 31 loop
         valid_in <= '1';
         x <= message_1(16*J+15 downto 16*J);
         y <= exponent_1(16*J+15 downto 16*J);
         m <= modulo_1(16*J+15 downto 16*J);
         r_c <= r_c_1(16*J+15 downto 16*J);
         wait for clk_period;
     end loop;
     valid_in <= '0';
     wait until valid_out = '1';
 
 
     --read all 32 words
     for J in 0 to 31 loop 
         
         wait for clk_period;
         result(16*J+15 downto 16*J) <= s;

     end loop;

     wait for clk_period * 10;
     wait for clk_period/2;

            
                
    assert result = result_1
        report "The encrypted message does not match the theoretical result!"
        severity failure;
                
        --Reset the circuit
    reset_circuit(modulo    => modulo_1(15 downto 0),
                  reset     => reset,
                  valid_in  => valid_in,
                  start_in  => start_in,
                  m         => m
                  );
                  
    --Try to decrypt the result from previous. 

               for J in 0 to 31 loop
         valid_in <= '1';
         x <= result(16*J+15 downto 16*J);
         y <= exponent_2(16*J+15 downto 16*J);
         m <= modulo_1(16*J+15 downto 16*J);
         r_c <= r_c_1(16*J+15 downto 16*J);
         wait for clk_period;
     end loop;
     valid_in <= '0';
     wait until valid_out = '1';
 
 
     --read all 32 words
     for J in 0 to 31 loop 
         
         wait for clk_period;
         result(16*J+15 downto 16*J) <= s;

     end loop;

     wait for clk_period * 10;
     wait for clk_period/2;

 
    assert result = message_1
        report "The decryption did not result in the original message!"
        severity failure;
        
        
    report "The testbench finished successfully!"
    severity failure;
    
    wait;
end process;

process
begin
wait for 1 ms;
report "It has gone way too long with the standard clock of 1ns! Make sure all the flags are being set correctly and that the memories are functional!"
severity failure;
end process;

end behavior;
