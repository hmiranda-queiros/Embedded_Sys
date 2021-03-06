library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity tb_adder_combinatorial is
end entity tb_adder_combinatorial;

architecture test of tb_adder_combinatorial is

	constant TIME_DELTA : time := 100 ns;

	-- adder_combinatorial GENERICS
	constant N_BITS : positive range 2 to positive'right := 4;
	
	-- adder_combinatorial PORTS
	signal OP1 : std_logic_vector(N_BITS - 1 downto 0);
	signal OP2 : std_logic_vector(N_BITS - 1 downto 0);
	signal SUM : std_logic_vector(N_BITS downto 0);

begin

	-- Instantiate DUT
	dut : entity work.adder_combinatorial
	generic map(N_BITS => N_BITS)
	port map(
		OP1 => OP1,
		OP2 => OP2,
		SUM => SUM
	);
	
	
	-- Test adder_combinatorial
	simulation : process
	begin
		-- Assign values to circuit inputs.
		OP1 <= "0001"; -- 1
		OP2 <= "0101"; -- 5
		-- OP1 and OP2 are NOT yet assigned. We have to wait for some time
		-- for the simulator to "propagate" their values. Any infinitesimal
		-- period would work here since we are testing a combinatorial
		-- circuit.
		
		wait for TIME_DELTA;
		
		-- Assign values to circuit inputs.
		OP1 <= "0011"; -- 3
		OP2 <= "0010"; -- 2
		-- OP1 and OP2 are NOT yet assigned. We have to wait for some time
		-- for the simulator to "propagate" their values. Any infinitesimal
		-- period would work here since we are testing a combinatorial
		-- circuit.
		
		wait for TIME_DELTA;
	end process simulation;
	

end architecture test;