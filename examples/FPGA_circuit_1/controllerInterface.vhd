----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:04:34 01/07/2016 
-- Design Name: 
-- Module Name:    controllerCircuit - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


use work.controller_package.all;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--- BEGIN MATLABGEN ---

entity controllerInterface is
	Port ( clk : in std_logic;
	        ce : in std_logic;
	     reset : in std_logic;
	       x1 : in std_logic_vector(N_BIT_CTRL-1 downto 0);
	       x2 : in std_logic_vector(N_BIT_CTRL-1 downto 0);
	       p1 : in std_logic_vector(N_BIT_CTRL-1 downto 0);
	       xref1 : in std_logic_vector(N_BIT_CTRL-1 downto 0);
	       u1 : out std_logic_vector(N_BIT_OUT_CTRL-1 downto 0);
	     sample : out std_logic;
	      done : out std_logic);
end controllerInterface;

--- END MATLABGEN ---

architecture Behavioral of controllerInterface is

component controllerCircuit is
	Port( clk : in std_logic;
			reset : in std_logic;
			start : in std_logic;
			 done : out std_logic;
                x : in x_matrix_CTRL;
            mul_y : in mul_out_matrix_CTRL;
           mul_x1 : out mul_in_matrix_CTRL;
           mul_x2 : out mul_in_matrix_CTRL;
                u : out u_matrix_CTRL
);

end component;

component mulBank is
Port(			  x1 : in mul_in_matrix_CTRL;
			  x2 : in mul_in_matrix_CTRL;
			  y : out mul_out_matrix_CTRL);
end component;

	
	-- Signals declaration
	
	signal signal_u: u_matrix_CTRL;
	signal signal_x: x_matrix_CTRL;


signal counter : integer range 0 to sampling_latency_CTRL-1;
signal u_reg : u_matrix_CTRL;
signal x_reg : x_matrix_CTRL;


signal start : std_logic;
signal sign_sample : std_logic;
signal signal_done : std_logic;

signal mulIn1 : mul_in_matrix_CTRL;
signal mulIn2 : mul_in_matrix_CTRL;
signal mulOut : mul_out_matrix_CTRL;

begin

	-- Port maps
	
	inst_controllerCircuit: controllerCircuit
		port map (  clk => clk,
		         reset => reset,
		         start => start,
		             x => x_reg,
		         mul_y => mulOut,
		        mul_x1 => mulIn1,
		        mul_x2 => mulIn2,
		             u => signal_u,
		          done => signal_done);

inst_mulBank : mulBank 
    port map(x1 => mulIn1,
			  x2 => mulIn2,
			  y => mulOut);


counter_process : process(clk,reset)
begin
if reset = '0' then
    counter <= 0;
elsif rising_edge(clk) then
    if counter = sampling_latency_CTRL-1 then
        counter <= 0;
    else
        counter <= counter+1;
    end if;
end if;
end process;



sign_sample <= '1' when counter = 0
    else '0';

start <= '1' when counter = 1
    else '0';

input_reg_process : process(clk,reset)
begin
if reset = '0' then
    for i in 0 to nx_CTRL+npar_CTRL+nd_CTRL+nxref_CTRL-1 loop
        x_reg(i) <= (others => '0');
    end loop;
elsif rising_edge(clk) then
    if sign_sample = '1' then
        x_reg <= signal_x;
    end if;
end if;
end process;


output_reg_process : process(clk,reset)
begin
if reset = '0' then
    for i in 0 to nu_CTRL-1 loop
        u_reg(i) <= defaultOutput(i);
    end loop;
elsif rising_edge(clk) then
    if signal_done = '1' then
        u_reg <= signal_u;
    end if;
end if;
end process;

--- BEGIN MATLABGEN ---

	u1 <= std_logic_vector(u_reg(0));
	signal_x(0) <= signed(x1);
	signal_x(1) <= signed(x2);
	signal_x(0+nx_CTRL) <= signed(p1);
	signal_x(0+nx_CTRL+npar_CTRL+nd_CTRL) <= signed(xref1);

--- END MATLABGEN ---

sample <= sign_sample;
done <= signal_done;
end Behavioral;

