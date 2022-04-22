----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:04:11 01/26/2016 
-- Design Name: 
-- Module Name:    embeddedSystem - Behavioral 
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

use work.observer_package.all;
use work.controller_package.all;
use work.embeddedSystemPackage.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--- BEGIN MATLABGEN ---
--- END MATLABGEN ---

architecture Behavioral of embeddedSystem is

component inputShift is
Port(u_in : in in_matrix_ES;
	u_out : out in_matrix_ES);
end component;

component outputShift is
Port(y_in : in out_matrix_ES;
	y_out : out out_matrix_ES);
end component;

component switchedControllerCircuit is
	Port( clk : in std_logic;
			reset : in std_logic;
			start : in std_logic;
			 done : out std_logic;
                x : in x_matrix_CTRL;
          dynamic : in integer range 0 to nDyn_CTRL;
            mul_y : in mul_out_matrix_CTRL;
           mul_x1 : out mul_in_matrix_CTRL;
           mul_x2 : out mul_in_matrix_CTRL;
                u : out u_matrix_CTRL
);
end component;

component timingFSM is
Port(clk : in std_logic;
	reset : in std_logic;
	sample : out std_logic;
    update : out std_logic;
	end_update : in std_logic;
	ctrl : out std_logic;
	end_control : in std_logic;
	predict : out std_logic;
	end_predict : in std_logic;
    findDyn : out std_logic;
    end_findDyn : in std_logic;
	mux_select : out std_logic_vector(1 downto 0);
	sel_x_in_dyn : out std_logic);
end component;

component switchedKalmanFilter is
	Port( clk : in std_logic;
			reset : in std_logic;
			start_update : in std_logic;
			start_predict : in std_logic;
			stop_update : out std_logic;
			stop_predict : out std_logic;
            dynamic : in integer range 0 to nDyn_OBS-1;
			mulIn1 : out mul_in_matrix_OBS;
			mulIn2 : out mul_in_matrix_OBS;
			mulOut : in mul_out_matrix_OBS;
            in_matrix : in compositeInputType_OBS;
            out_matrix_pred : out compositeStateType_OBS;
            out_matrix_update : out compositeStateType_OBS);
end component;

component findDynamic is
    Port ( clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
			  start : in std_logic;
			  valid_output : out std_logic;
			  mulIn1 : out mul_in_matrix_ES;
			  mulIn2 : out mul_in_matrix_ES;
			  mulOut : in mul_out_matrix_ES;
			  u : in  in_matrix_ES; -- u = [u;p;y]
			  x : in  compositeStateType_OBS;
           dynamic : out integer range 0 to nDyn_OBS-1);
end component;

component mulBank is
Port(			  x1 : in mul_in_matrix_ES;
			  x2 : in mul_in_matrix_ES;
			  y : out mul_out_matrix_ES);
end component;

signal x1_to_mul : mul_in_matrix_ES;
signal x2_to_mul : mul_in_matrix_ES;
signal y_from_mul : mul_out_matrix_ES;

signal mul_y_CTRL : mul_out_matrix_CTRL;
signal mul_x1_CTRL :  mul_in_matrix_CTRL;
signal mul_x2_CTRL :  mul_in_matrix_CTRL;

signal mul_x1_OBS :  mul_in_matrix_OBS;
signal mul_x2_OBS :  mul_in_matrix_OBS;
signal mul_y_OBS :  mul_out_matrix_OBS;

signal mul_x1_dyn :  mul_in_matrix_ES;
signal mul_x2_dyn :  mul_in_matrix_ES;
signal mul_y_dyn :  mul_out_matrix_ES;

signal dynamic_signal : integer range 0 to nDyn_ES-1;

signal sample_signal : std_logic;

signal ctrl_signal : std_logic;
signal ctrl_signal_end : std_logic;
signal output_ready_reg : std_logic;

signal predict_signal : std_logic;
signal predict_signal_end : std_logic;

signal update_signal : std_logic;
signal update_signal_end : std_logic;

signal find_dyn_signal : std_logic;
signal find_dyn_signal_end : std_logic;

signal inCtrl: x_matrix_CTRL;
signal outCtrl : u_matrix_CTRL;

signal inObs: compositeInputType_OBS;
signal xFromObserver : compositeStateType_OBS;
signal x_next_observer : compositeStateType_OBS;


signal x_to_find_dyn : compositeStateType_OBS;

signal x_to_find_dyn_sel : std_logic;

signal inputSignal : in_matrix_ES;
signal inputSignalScale : in_matrix_ES;
signal inputReg : in_matrix_ES;

signal outputSignal : out_matrix_ES;
signal outputSignalScale : out_matrix_ES;
signal outputReg : out_matrix_ES;

signal mux_select : std_logic_vector(1 downto 0);
begin 

inst_inputShift : inputShift 
Port map(u_in => inputSignal,
	u_out => inputSignalScale);

inst_outputShift : outputShift
Port map(y_in => outputSignal,
	y_out => outputSignalScale);
			

inst_findDynamic : findDynamic 
    Port map ( clk => clk,
           reset => reset,
			  start => find_dyn_signal,
			  valid_output => find_dyn_signal_end,
			  mulIn1 => mul_x1_dyn,
			  mulIn2 => mul_x2_dyn,
			  mulOut => mul_y_dyn,
			  u => inputReg,
			  x => x_to_find_dyn,
           dynamic => dynamic_signal);

inst_timingFSM : timingFSM
Port map (clk => clk,
	reset => reset,
	sample => sample_signal,
	ctrl => ctrl_signal,
	end_control => ctrl_signal_end,
	update => update_signal,
	end_update => update_signal_end,
	predict => predict_signal,
	end_predict => predict_signal_end,
    findDyn => find_dyn_signal,
    end_findDyn => find_dyn_signal_end,
	mux_select => mux_select,
	sel_x_in_dyn => x_to_find_dyn_sel);

inst_mulBank : mulBank
Port map(x1 => x1_to_mul,
			  x2 => x2_to_mul,
			  y => y_from_mul);

inst_controllerCircuit : switchedControllerCircuit
	Port map( clk => clk,
			reset => reset,
			start => ctrl_signal,
			 done => ctrl_signal_end,
                x => inCtrl,
          dynamic => dynamic_signal,
            mul_y => mul_y_CTRL,
           mul_x1 => mul_x1_CTRL,
           mul_x2 => mul_x2_CTRL,
                u => outCtrl);
	
	
inst_kalmanFitler : switchedKalmanFilter 
	Port map( clk => clk,
			reset => reset,
			start_predict => predict_signal,
			stop_predict => predict_signal_end,
			start_update => update_signal,
			stop_update => update_signal_end,
			mulIn1 => mul_x1_OBS,
			mulIn2 => mul_x2_OBS,
			mulOut => mul_y_OBS,
           dynamic => dynamic_signal,
			in_matrix => inObs,
			out_matrix_update => xFromObserver,
			out_matrix_pred => x_next_observer);


signal_to_observer_process : process(outCtrl,inputReg)
begin
for i in 0 to nu_ES-1 loop
	inObs(i) <= std_logic_vector(resize(outCtrl(i),N_BIT_COEFF_ES));
end loop;
for i in 0 to np_ES-1 loop
	inObs(i+nu_ES) <= std_logic_vector(resize(signed(inputReg(i)),N_BIT_COEFF_ES));
end loop;
for i in 0 to ny_ES-1 loop
	inObs(i+nu_ES+np_ES) <= std_logic_vector(resize(signed(inputReg(i+np_ES+nxref_ES)),N_BIT_COEFF_ES));
end loop;
end process;

x_to_find_dyn <= xFromObserver when x_to_find_dyn_sel = '1' 
		else x_next_observer;

signal_to_controller_process : process(inputReg,xFromObserver)
begin
for i in 0 to nx_ES-1 loop
	inCtrl(i) <= resize(signed(xFromObserver(i)),N_BIT_COEFF_ES);
end loop;
for i in 0 to np_ES-1 loop
	inCtrl(i+nx_ES) <= resize(signed(inputReg(i)),N_BIT_COEFF_ES);
end loop;
for i in 0 to nd_ES-1 loop
	inCtrl(i+np_ES+nx_ES) <= resize(signed(xFromObserver(i+nx_ES)),N_BIT_COEFF_ES);
end loop;
for i in 0 to nxref_ES-1 loop
	inCtrl(i+np_ES+nx_ES+nd_ES) <= resize(signed(inputReg(i+np_ES)),N_BIT_COEFF_ES);
end loop;
end process;

out_reg_process : process(clk,reset)
begin
if reset = '0' then
for i in 0 to N_OUTPUT_ES-1 loop
	outputReg(i) <= std_logic_vector(defaultOutput(i));
end loop;
elsif rising_edge(clk) then
	if ctrl_signal_end = '1' then
		outputReg <= outputSignalScale;
	end if;
end if;
end process;

in_reg_process : process(clk,reset)
begin
if reset = '0' then
for i in 0 to N_INPUT_ES-1 loop
	inputReg(i) <= (others => '0');
end loop;
elsif rising_edge(clk) then
	if sample_signal = '1' then
		inputReg <= inputSignalScale;
	end if;
end if;
end process;

	

sel_mul_process : process(mul_x1_CTRL,mul_x2_CTRL,mul_x1_OBS,mul_x2_OBS,mul_x1_dyn,mul_x2_dyn,y_from_mul,mux_select)
begin
for i in 0 to N_MUL_ES-1 loop
x1_to_mul(i) <= (others => '0');
x2_to_mul(i) <= (others => '0');
mul_y_dyn(i) <= y_from_mul(i);
end loop;

for i in 0 to N_MUL_CTRL_ES-1 loop
	mul_y_CTRL(i) <= resize(y_from_mul(i),2*N_BIT_MUL_CTRL);
end loop;	
for i in 0 to N_MUL_OBS_ES-1 loop
	mul_y_OBS(i) <= resize(y_from_mul(i),2*N_BIT_MUL_OBS);
end loop;	

if mux_select = "01" then
	for i in 0 to N_MUL_CTRL_ES-1 loop
		x1_to_mul(i) <= resize(mul_x1_CTRL(i),N_BIT_MUL_CTRL);
		x2_to_mul(i) <= resize(mul_x2_CTRL(i),N_BIT_MUL_CTRL);
	end loop;	
elsif mux_select = "10" then
	for i in 0 to N_MUL_CTRL_ES-1 loop
		x1_to_mul(i) <= mul_x1_dyn(i);
		x2_to_mul(i) <= mul_x2_dyn(i);
	end loop;	
else -- observ
	for i in 0 to N_MUL_OBS_ES-1 loop
		x1_to_mul(i) <= resize(mul_x1_OBS(i),N_BIT_MUL_OBS);
		x2_to_mul(i) <= resize(mul_x2_OBS(i),N_BIT_MUL_OBS);
	end loop;	
end if;
end process;


output_ready_reg_process : process(clk,reset)
begin
if reset = '0' then
output_ready_reg <= '0';
elsif rising_edge(clk) then
output_ready_reg <= ctrl_signal_end;
end if;
end process;

controller_out_proc : process(outCtrl)
begin
for i in 0 to N_OUTPUT_ES-1 loop
	outputSignal(i) <= std_logic_vector(outCtrl(i));
end loop;
end process;

--- BEGIN MATLABGEN ---
--- END MATLABGEN ---

output_ready <= output_ready_reg;
sample <= sample_signal;

end Behavioral;

