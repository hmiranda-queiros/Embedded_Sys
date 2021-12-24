library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_Camera_Ctrl is
end tb_Camera_Ctrl;

architecture test of tb_Camera_Ctrl is

	constant CLK_PERIOD 	: time := 100 ns;

	signal Clk 				: std_logic;
	signal nReset 			: std_logic;
	
	-- Internal interface (i.e. Avalon Slave).
	signal	AS_Adr 			: std_logic_vector(2 downto 0);
	signal	AS_Write		: std_logic;
	signal	AS_Read 		: std_logic;
	signal	AS_DataWrite	: std_logic_vector(31 downto 0);
	signal	AS_DataRead		: std_logic_vector(31 downto 0);
		
	-- Internal interface (i.e. Avalon Master).
	signal	AM_Adr 			: std_logic_vector(31 downto 0);
	signal	AM_Write		: std_logic;
	signal	AM_DataWrite	: std_logic_vector(31 downto 0);
	signal	AM_ByteEnable	: std_logic_vector(3 downto 0);
	signal	AM_BurstCount	: std_logic_vector(31 downto 0);
	signal	AM_WaitRequest	: std_logic;
		
	-- Camera Interface
	signal	XCLKIN			: std_logic;
	signal	RESETn			: std_logic;
	signal	D				: std_logic_vector(11 downto 0);
	signal	LVAL			: std_logic;
	signal	FVAL			: std_logic;
	signal	PIXCLK			: std_logic;

begin

	-- Instantiate DUT
	dut : entity work.Camera_Ctrl
	port map(
		Clk 			=> Clk,
		nReset			=> nReset,
		
		AS_Adr 			=> AS_Adr,
		AS_Write		=> AS_Write,
		AS_Read 		=> AS_Read,
		AS_DataWrite	=> AS_DataWrite,
		AS_DataRead		=> AS_DataRead,
		
		AM_Adr 			=> AM_Adr,
		AM_Write		=> AM_Write,
		AM_DataWrite	=> AM_DataWrite,
		AM_ByteEnable	=> AM_ByteEnable,
		AM_BurstCount	=> AM_BurstCount,
		AM_WaitRequest	=> AM_WaitRequest,
		
		XCLKIN			=> XCLKIN,
		RESETn			=> RESETn,
		D				=> D,
		LVAL			=> LVAL,	
		FVAL			=> FVAL, 	
		PIXCLK			=> PIXCLK
	);
	
	-- Generate CLK signal
	clk_generation : process
	begin
		Clk	<= '1';
		wait for CLK_PERIOD / 2;
		Clk <= '0';
		wait for CLK_PERIOD / 2;
	end process clk_generation;

	
	-- Test PWM_gen
	simulation : process
	
	procedure async_reset is
	begin
		wait until rising_edge(CLK);
		wait for CLK_PERIOD / 4;
		nReset	<= '0';
		
		wait for CLK_PERIOD / 2;
		nReset	<= '1';
	end procedure async_reset;
	
	procedure WR(constant REG_ID : in natural; constant data : in natural) is
	begin
		wait until rising_edge(CLK);
		
		AS_Write		<= '1';
		AS_Adr			<= std_logic_vector(to_unsigned(REG_ID, AS_Adr'length));
		AS_DataWrite	<= std_logic_vector(to_unsigned(data, AS_DataWrite'length));
		
		wait until rising_edge(CLK);
		
		AS_Write		<= '0';
		AS_Adr			<= (others => '0');
		AS_DataWrite	<= (others => '0');
	end procedure WR;
	
	procedure RD(constant REG_ID : in natural) is
	begin
		wait until rising_edge(CLK);
		
		AS_Read		<= '1';
		AS_Adr		<= std_logic_vector(to_unsigned(REG_ID, AS_Adr'length));
		
		wait until rising_edge(CLK);
		
		AS_Read		<= '0';
		AS_Adr		<= (others => '0');
	end procedure RD;

	begin
	
		-- Reset the circuit.
		async_reset;
		
		--Test
		WR(0, 777);			-- Writes RegAdr
		WR(3, 4);			-- Writes RegBurst
		WR(1, 153600);		-- Writes RegLength
		WR(2, 1);			-- Writes RegEnable
		
		RD(0);				-- Reads RegAdr
		RD(3);				-- Reads RegBurst
		RD(1);				-- Reads RegLength
		RD(2);				-- Reads RegEnable
		
		
		wait;
	end process simulation;

end architecture test;