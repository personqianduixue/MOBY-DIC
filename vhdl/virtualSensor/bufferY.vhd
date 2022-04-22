----------------------------------------------------------------------------------
-- MOBY-DIC Project
-- www.mobydic-project.eu
--
-- Copyright:
-- (C) 2011 Tomaso Poggi, Spain, tpoggi@essbilbao.org
-- (C) 2011 Alberto Oliveri, University of Genoa, Italy, alberto.oliveri@unige.it
--
-- Legal note:
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public
-- License as published by the Free Software Foundation; either
-- version 2.1 of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public
-- License along with this library; if not, write to the 
-- Free Software Foundation, Inc., 
-- 59 Temple Place, Suite 330, 
-- Boston, MA  02111-1307  USA
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.vsPackage.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity bufferY is
Generic ( default : std_logic_vector(N_BIT_VS-1 downto 0) := (others => '0'));
Port (    clk : in std_logic;
        reset : in std_logic;
       sample : in std_logic;
		    yin : in std_logic_vector(N_BIT_VS-1 downto 0);
			yout : out buf_y_matrix_vs);
end bufferY;

architecture Behavioral of bufferY is

	signal bufy : buf_y_matrix_vs;

begin

	proc_outputs : process(clk,reset,yin,sample)
	begin
		if reset = '0' then
			for i in 0 to MY_VS-1 loop
				bufy(i) <= default;
			end loop;
		elsif rising_edge(clk) and sample = '1' then
			bufy(0) <= yin;
			for i in 1 to MY_VS-1 loop
				bufy(i) <= bufy(i-1);
			end loop;
		end if;
	end process;

	yout <= bufy;

end Behavioral;

