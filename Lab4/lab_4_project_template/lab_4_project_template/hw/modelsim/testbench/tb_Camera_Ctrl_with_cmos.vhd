library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.cmos_sensor_output_generator_constants.all;

entity tb_Camera_Ctrl_with_cmos is
end tb_Camera_Ctrl_with_cmos;

architecture test of tb_Camera_Ctrl_with_cmos is

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
	
	
    signal reset : std_logic;

    -- cmos_sensor_output_generator --------------------------------------------
    constant PIX_DEPTH         : positive := 12;
    constant MAX_WIDTH         : positive := 1920;
    constant MAX_HEIGHT        : positive := 1080;
    constant FRAME_WIDTH       : positive := 4;
    constant FRAME_HEIGHT      : positive := 4;
    constant FRAME_FRAME_BLANK : positive := 1;
    constant FRAME_LINE_BLANK  : natural  := 1;
    constant LINE_LINE_BLANK   : positive := 1;
    constant LINE_FRAME_BLANK  : natural  := 1;

    signal addr        : std_logic_vector(2 downto 0);
    signal read        : std_logic;
    signal write       : std_logic;
    signal rddata      : std_logic_vector(CMOS_SENSOR_OUTPUT_GENERATOR_MM_S_DATA_WIDTH - 1 downto 0);
    signal wrdata      : std_logic_vector(CMOS_SENSOR_OUTPUT_GENERATOR_MM_S_DATA_WIDTH - 1 downto 0);
    signal frame_valid : std_logic;
    signal line_valid  : std_logic;
    signal data        : std_logic_vector(PIX_DEPTH - 1 downto 0);

begin

	-- Generate CLK signal
	clk_generation : process
	begin
		Clk	<= '1';
		wait for CLK_PERIOD / 2;
		Clk <= '0';
		wait for CLK_PERIOD / 2;
	end process clk_generation;
	
	cmos_sensor_output_generator_inst : entity work.cmos_sensor_output_generator
        generic map(PIX_DEPTH  => PIX_DEPTH,
                    MAX_WIDTH  => MAX_WIDTH,
                    MAX_HEIGHT => MAX_HEIGHT)
        port map(clk         => Clk,
                 reset       => reset,
                 addr        => addr,
                 read        => read,
                 write       => write,
                 rddata      => rddata,
                 wrdata      => wrdata,
                 frame_valid => frame_valid,
                 line_valid  => line_valid,
                 data        => data
		);
		
	-- Instantiate Camera_Ctrl
	camera_ctrl_inst : entity work.Camera_Ctrl
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
		D				=> data,
		LVAL			=> line_valid,	
		FVAL			=> frame_valid, 	
		PIXCLK			=> Clk
	);

	-- Test Camera_Ctrl
	simulation : process
	
		procedure async_reset is
		begin
			wait until rising_edge(Clk);
			wait for CLK_PERIOD / 4;
			nReset	<= '0';
			reset	<= '1';
			wait for CLK_PERIOD / 2;
			nReset	<= '1';
			reset	<= '0';
		end procedure async_reset;
		
		procedure WR(constant REG_ID : in natural; constant data : in natural) is
		begin
			wait until rising_edge(Clk);
			
			AS_Write		<= '1';
			AS_Adr			<= std_logic_vector(to_unsigned(REG_ID, AS_Adr'length));
			AS_DataWrite	<= std_logic_vector(to_unsigned(data, AS_DataWrite'length));
			
			wait until rising_edge(Clk);
			
			AS_Write		<= '0';
			AS_Adr			<= (others => '0');
			AS_DataWrite	<= (others => '0');
		end procedure WR;
		
		procedure RD(constant REG_ID : in natural) is
		begin
			wait until rising_edge(Clk);
			
			AS_Read		<= '1';
			AS_Adr		<= std_logic_vector(to_unsigned(REG_ID, AS_Adr'length));
			
			wait until rising_edge(Clk);
			
			AS_Read		<= '0';
			AS_Adr		<= (others => '0');
		end procedure RD;
		
		-------------------------- CMOS -------------------------------------
		
		procedure write_register(constant ofst : in std_logic_vector;
                                 constant val  : in natural) is
        begin
            wait until falling_edge(Clk);
            addr   <= ofst;
            write  <= '1';
            wrdata <= std_logic_vector(to_unsigned(val, wrdata'length));

            wait until falling_edge(Clk);
            addr   <= (others => '0');
            write  <= '0';
            wrdata <= (others => '0');
        end procedure write_register;

        procedure write_register(constant ofst : in std_logic_vector;
                                 constant val  : in std_logic_vector) is
        begin
            wait until falling_edge(Clk);
            addr   <= ofst;
            write  <= '1';
            wrdata <= std_logic_vector(resize(unsigned(val), wrdata'length));

            wait until falling_edge(Clk);
            addr   <= (others => '0');
            write  <= '0';
            wrdata <= (others => '0');
        end procedure write_register;

        procedure read_register(constant ofst : in std_logic_vector) is
        begin
            wait until falling_edge(Clk);
            addr <= ofst;
            read <= '1';

            wait until falling_edge(Clk);
            addr <= (others => '0');
            read <= '0';
        end procedure read_register;

        procedure check_idle is
        begin
            read_register(CMOS_SENSOR_OUTPUT_GENERATOR_STATUS_OFST);
            assert rddata = CMOS_SENSOR_OUTPUT_GENERATOR_STATUS_IDLE report "Error: unit should be idle, but is busy" severity error;
        end procedure check_idle;

        procedure check_busy is
        begin
            read_register(CMOS_SENSOR_OUTPUT_GENERATOR_STATUS_OFST);
            assert rddata = CMOS_SENSOR_OUTPUT_GENERATOR_STATUS_BUSY report "Error: unit should be busy, but is idle" severity error;
        end procedure check_busy;

        procedure wait_clock_cycles(constant count : in positive) is
        begin
            wait for count * CLK_PERIOD;
        end procedure wait_clock_cycles;

	begin
		
		--Default values
		AS_Adr 			<= (others => '0');
		AS_Write		<= '0';
		AS_Read 		<= '0';
		AS_DataWrite	<= (others => '0');
		AM_WaitRequest	<= '0';
		nReset			<= '1';
		reset			<= '0';
		
		
		wait for CLK_PERIOD;
		-- Reset the circuit.
		async_reset;
		
		-- configure
		write_register(CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_WIDTH_OFST, FRAME_WIDTH);
		write_register(CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_HEIGHT_OFST, FRAME_HEIGHT);
		write_register(CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_FRAME_BLANK_OFST, FRAME_FRAME_BLANK);
		write_register(CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_FRAME_LINE_BLANK_OFST, FRAME_LINE_BLANK);
		write_register(CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_LINE_BLANK_OFST, LINE_LINE_BLANK);
		write_register(CMOS_SENSOR_OUTPUT_GENERATOR_CONFIG_LINE_FRAME_BLANK_OFST, LINE_FRAME_BLANK);

		-- start generator
		write_register(CMOS_SENSOR_OUTPUT_GENERATOR_COMMAND_OFST, CMOS_SENSOR_OUTPUT_GENERATOR_COMMAND_START);
		check_busy;
		
		--Test
		WR(0, 777);			-- Writes RegAdr
		WR(3, 2);			-- Writes RegBurst
		WR(1, 16);			-- Writes RegLength
		WR(4, 0);			-- Writes RegLength
		WR(2, 1);			-- Writes RegEnable
		
		RD(0);				-- Reads RegAdr
		RD(3);				-- Reads RegBurst
		RD(1);				-- Reads RegLength
		RD(2);				-- Reads RegEnable
		
		
		wait;
	end process simulation;

end architecture test;