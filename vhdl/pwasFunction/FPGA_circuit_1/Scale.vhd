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

-- See file pwas_ser_package.vhd for comments.
use work.pwasFunctionPackage.all;

entity Scale is
	Port ( clk : in std_logic;
	     reset : in std_logic;
	     start : in std_logic;
	         x : in x_matrix_pwas;
	      Axmb : in mul_out_matrix_pwas;
	       xmb : out x_matrix_pwas;
	    scaleA : out coeff_matrix_pwas;
	     x_int : out int_matrix_pwas;
	     x_dec : out dec_matrix_pwas;
	      done : out  std_logic);
end Scale;

architecture Behavioral of Scale is

	signal signal_scaleInput_A_PWAS : coeff_matrix_pwas;
	signal signal_scaleInput_b_PWAS : x_matrix_pwas;
	signal int : int_matrix_pwas;
	
begin
	
proc_scaleB: process(reset,x,signal_scaleInput_b_PWAS)
	begin
		if reset = '0' then
			for i in 0 to N_DIM_PWAS-1 loop
				xmb(i) <= (others => '0');
			end loop;
		else
			for i in 0 to N_DIM_PWAS-1 loop
				xmb(i) <= x(i)-signal_scaleInput_b_PWAS(i);
			end loop;
		end if;
	end process;


	proc_intdec: process(clk,start,reset)
		variable signal_Axmb : mul_out_matrix_pwas;
	begin
		if reset = '0' then
			for i in 0 to N_DIM_PWAS-1 loop
				x_int(i) <= (others => '0');
				x_dec(i) <= (others => '0');
			end loop;
		elsif rising_edge(clk) and start = '1' then
			for i in 0 to N_DIM_PWAS-1 loop
				if Axmb(i) > NP_PWAS(i) then
					signal_Axmb(i) := NP_PWAS(i);
				elsif Axmb(i) < ZERO_PWAS then
					signal_Axmb(i) := ZERO_PWAS;
				else
					signal_Axmb(i) := Axmb(i);
				end if;
                x_int(i) <= int(i);
                x_dec(i) <= unsigned(signal_Axmb(i)(POINT_POSITION_PWAS(i)-1 downto POINT_POSITION_PWAS(i)-N_BIT_COEFF_PWAS));
			end loop;
		end if;
	end process;

	scaleA <= signal_scaleInput_A_PWAS;

	done <= '0' when reset = '0' else
	        start when rising_edge(clk);

--- BEGIN MATLABGEN ---

	-- In this process the indexes of the hyper-rectangle containing the point are found
	proc_find_index: process(reset,x)
	begin
		if reset = '0' then
			for i in 0 to N_DIM_PWAS-1 loop
				signal_scaleInput_A_PWAS(i) <= (others => '0');
				signal_scaleInput_b_PWAS(i) <= (others => '0');
				int(i) <= (others => '0');
			end loop;
		else
			if x(0) < P0_PWAS(0) then
				signal_scaleInput_A_PWAS(0) <= scaleInput0_A_PWAS(0);
				signal_scaleInput_b_PWAS(0) <= scaleInput0_b_PWAS(0);
				int(0) <= "000";
			elsif x(0) < P0_PWAS(1) then
				signal_scaleInput_A_PWAS(0) <= scaleInput0_A_PWAS(1);
				signal_scaleInput_b_PWAS(0) <= scaleInput0_b_PWAS(1);
				int(0) <= "001";
			elsif x(0) < P0_PWAS(2) then
				signal_scaleInput_A_PWAS(0) <= scaleInput0_A_PWAS(2);
				signal_scaleInput_b_PWAS(0) <= scaleInput0_b_PWAS(2);
				int(0) <= "010";
			elsif x(0) < P0_PWAS(3) then
				signal_scaleInput_A_PWAS(0) <= scaleInput0_A_PWAS(3);
				signal_scaleInput_b_PWAS(0) <= scaleInput0_b_PWAS(3);
				int(0) <= "011";
			elsif x(0) < P0_PWAS(4) then
				signal_scaleInput_A_PWAS(0) <= scaleInput0_A_PWAS(4);
				signal_scaleInput_b_PWAS(0) <= scaleInput0_b_PWAS(4);
				int(0) <= "100";
			elsif x(0) < P0_PWAS(5) then
				signal_scaleInput_A_PWAS(0) <= scaleInput0_A_PWAS(5);
				signal_scaleInput_b_PWAS(0) <= scaleInput0_b_PWAS(5);
				int(0) <= "101";
			else
				signal_scaleInput_A_PWAS(0) <= scaleInput0_A_PWAS(6);
				signal_scaleInput_b_PWAS(0) <= scaleInput0_b_PWAS(6);
				int(0) <= "110";
			end if;
			if x(1) < P0_PWAS(0) then
				signal_scaleInput_A_PWAS(1) <= scaleInput1_A_PWAS(0);
				signal_scaleInput_b_PWAS(1) <= scaleInput1_b_PWAS(0);
				int(1) <= "000";
			elsif x(1) < P0_PWAS(1) then
				signal_scaleInput_A_PWAS(1) <= scaleInput1_A_PWAS(1);
				signal_scaleInput_b_PWAS(1) <= scaleInput1_b_PWAS(1);
				int(1) <= "001";
			elsif x(1) < P0_PWAS(2) then
				signal_scaleInput_A_PWAS(1) <= scaleInput1_A_PWAS(2);
				signal_scaleInput_b_PWAS(1) <= scaleInput1_b_PWAS(2);
				int(1) <= "010";
			elsif x(1) < P0_PWAS(3) then
				signal_scaleInput_A_PWAS(1) <= scaleInput1_A_PWAS(3);
				signal_scaleInput_b_PWAS(1) <= scaleInput1_b_PWAS(3);
				int(1) <= "011";
			elsif x(1) < P0_PWAS(4) then
				signal_scaleInput_A_PWAS(1) <= scaleInput1_A_PWAS(4);
				signal_scaleInput_b_PWAS(1) <= scaleInput1_b_PWAS(4);
				int(1) <= "100";
			elsif x(1) < P0_PWAS(5) then
				signal_scaleInput_A_PWAS(1) <= scaleInput1_A_PWAS(5);
				signal_scaleInput_b_PWAS(1) <= scaleInput1_b_PWAS(5);
				int(1) <= "101";
			else
				signal_scaleInput_A_PWAS(1) <= scaleInput1_A_PWAS(6);
				signal_scaleInput_b_PWAS(1) <= scaleInput1_b_PWAS(6);
				int(1) <= "110";
			end if;
		end if;
	end process;
--- END MATLABGEN ---

end Behavioral;

