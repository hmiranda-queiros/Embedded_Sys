library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_PWM_gen is
end tb_PWM_gen;

architecture test of tb_PWM_gen is

	constant CLK_PERIOD : time := 100 ns;

	signal clk 				: std_logic;
	signal nReset 			: std_logic;
	
	-- Internal interface (i.e. Avalon slave).
	signal address 			: std_logic_vector(2 downto 0);
	signal write 			: std_logic;
	signal read 			: std_logic;
	signal writedata 		: std_logic_vector(31 downto 0);
	signal readdata 		: std_logic_vector(31 downto 0);
	
	-- External interface (i.e. conduit).
	signal GPIO 			: std_logic_vector(7 downto 0);

begin

	-- Instantiate DUT
	dut : entity work.PWM_gen
	port map(
		clk => clk,
		nReset => nReset,
		address => address,
		write => write,
		read => read,
		writedata => writedata,
		readdata => readdata,
		GPIO => GPIO
	);
	
	-- Generate CLK signal
	clk_generation : process
	begin
		clk <= '1';
		wait for CLK_PERIOD / 2;
		clk <= '0';
		wait for CLK_PERIOD / 2;
	end process clk_generation;

	
	-- Test PWM_gen
	simulation : process
	
	procedure async_reset is
	begin
		wait until rising_edge(CLK);
		wait for CLK_PERIOD / 4;
		nReset <= '0';
		
		wait for CLK_PERIOD / 2;
		nReset <= '1';
	end procedure async_reset;
	
	procedure WR(constant REG_ID : in natural; constant data : in natural) is
	begin
		wait until rising_edge(CLK);
		
		write <= '1';
		address <= std_logic_vector(to_unsigned(REG_ID, address'length));
		writedata <= std_logic_vector(to_unsigned(data, writedata'length));
		
		wait until rising_edge(CLK);
		
		write <= '0';
		address <= (others => '0');
		writedata <= (others => '0');
	end procedure WR;
	
	procedure RD(constant REG_ID : in natural) is
	begin
		wait until rising_edge(CLK);
		
		read <= '1';
		address <= std_logic_vector(to_unsigned(REG_ID, address'length));
		
		wait until rising_edge(CLK);
		
		read <= '0';
		address <= (others => '0');
	end procedure RD;

	begin
	
		-- Default values
		nReset <= '1';
		address <= (others => '0');
		write <= '0';
		read <= '0';
		writedata <= (others => '0');
		
		wait for CLK_PERIOD;
		
		-- Reset the circuit.
		async_reset;
		
		--Test
		WR(0, 255);		-- Writes REGDIR
		WR(4, 1);		-- Writes REGPOLARITY
		WR(2, 10);		-- Writes REGPERIOD
		WR(3, 3);		-- Writes REGDUTY
		
		RD(0);			-- Reads REGDIR
		RD(4);			-- Reads REGPOLARITY
		RD(2);			-- Reads REGPERIOD
		RD(3);			-- Reads REGDUTY
		
		wait;
	end process simulation;



end architecture test;