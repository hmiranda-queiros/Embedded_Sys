library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Camera_Ctrl is
	port(
		Clk 				: in std_logic;
		nReset			: in std_logic;
		
		-- Internal interface (i.e. Avalon Slave).
		AS_Adr 			: in std_logic_vector(2 downto 0);
		AS_Write			: in std_logic;
		AS_Read 			: in std_logic;
		AS_DataWrite	: in std_logic_vector(31 downto 0);
		AS_DataRead		: out std_logic_vector(31 downto 0);
		
		-- Internal interface (i.e. Avalon Master).
		AM_Adr 			: out std_logic_vector(31 downto 0);
		AM_Write			: out std_logic;
		AM_DataWrite	: out std_logic_vector(31 downto 0);
		AM_ByteEnable	: out std_logic_vector(3 downto 0);
		AM_BurstCount	: out std_logic_vector(31 downto 0);
		AM_WaitRequest : in std_logic;
		
		-- Camera Interface
		XCLKIN			: out std_logic;
		RESETn			: out std_logic;
		D					: in std_logic_vector(11 downto 0);
		LVAL				: in std_logic;
		FVAL			 	: in std_logic;
		PIXCLK			: in std_logic
		
	);
	
end Camera_Ctrl;


architecture main of Camera_Ctrl is
	
	signal iRegAdr 		: unsigned(31 downto 0);				
	signal iRegLength 	: unsigned(31 downto 0); 		
	signal iRegEnable		: std_logic; 
	signal iRegBurst		: unsigned(31 downto 0);
	signal iRegLight		: std_logic;
	
	signal NewData 		: std_logic; 						
	signal DataAck			: std_logic;								
	signal NewPixels		: std_logic_vector(31 downto 0);
	signal EndBuffer		: std_logic;

	
	component Camera_Master is 
		port (
			Clk 				: in std_logic;
			nReset			: in std_logic;
			
			AM_Adr 			: out std_logic_vector(31 downto 0);
			AM_Write			: out std_logic;
			AM_DataWrite	: out std_logic_vector(31 downto 0);
			AM_ByteEnable	: out std_logic_vector(3 downto 0);
			AM_BurstCount	: out std_logic_vector(31 downto 0);
			AM_WaitRequest	: in std_logic;
			EndBuffer		: inout std_logic;
			
			NewData 			: in std_logic;
			DataAck			: out std_logic;
			NewPixels		: in std_logic_vector(31 downto 0);
			
			iRegAdr 			: in unsigned(31 downto 0);
			iRegLength 		: in unsigned(31 downto 0);
			iRegEnable		: inout std_logic;
			iRegBurst		: in unsigned(31 downto 0)
			
		);
	end component Camera_Master;
	
	
	component Camera_Interface is 
		port (
			Clk 				: in std_logic;
			nReset			: in std_logic;
			
			XCLKIN			: out std_logic;
			RESETn			: out std_logic;
			D					: in std_logic_vector(11 downto 0);
			LVAL				: in std_logic;
			FVAL			 	: in std_logic;
			PIXCLK			: in std_logic;
			
			NewData 			: out std_logic;
			DataAck			: in std_logic;
			NewPixels		: out std_logic_vector(31 downto 0);
			
			iRegEnable		: in std_logic;
			iRegBurst		: in unsigned(31 downto 0);
			iRegLight		: in std_logic;
			AM_WaitRequest	: in std_logic
			
		);
	end component Camera_Interface;
	
begin
	
	u0 : component Camera_Master
			port map (
				Clk 				=> Clk,
				nReset			=> nReset,
				
				AM_Adr 			=> AM_Adr,
				AM_Write			=> AM_Write,
				AM_DataWrite	=> AM_DataWrite,
				AM_ByteEnable	=> AM_ByteEnable,
				AM_BurstCount	=> AM_BurstCount,
				AM_WaitRequest => AM_WaitRequest,
				EndBuffer		=> EndBuffer,
			
				NewData 			=> NewData,
				DataAck			=> DataAck,				
				NewPixels		=> NewPixels,
				
				iRegAdr 			=> iRegAdr,
				iRegLength 		=> iRegLength,
				iRegEnable		=> iRegEnable,
				iRegBurst		=> iRegBurst

			);
		
	u1 : component Camera_Interface
		port map (
			Clk 				=> Clk,
			nReset			=> nReset,
			
			XCLKIN			=> XCLKIN,
			RESETn			=> RESETn,
			D					=> D,
			LVAL				=> LVAL,
			FVAL			 	=> FVAL, 
			PIXCLK			=> PIXCLK,
		
			NewData 			=> NewData,
			DataAck			=> DataAck,				
			NewPixels		=> NewPixels,
			
			iRegEnable		=> iRegEnable,
			iRegBurst		=> iRegBurst,
			iRegLight		=> iRegLight,
			AM_WaitRequest => AM_WaitRequest

		);
			
	-- Avalon slave write to registers.
	process(Clk, nReset)
	begin
		if nReset = '0' then							-- Default values at Reset
			iRegAdr			<= (others => '0');
			iRegLength		<= (others => '0');
			iRegEnable		<= '0';
			iRegBurst		<= (others => '0');
			iRegLight		<= '0';
			
		elsif rising_edge(Clk) then
			if EndBuffer = '1' then					-- disable the Camera interface when it finishes writting a full frame in memory
				iRegEnable <= '0';
			end if;
			if AS_Write = '1' then
				case AS_Adr is
					when "000"  => iRegAdr			<= unsigned(AS_DataWrite);   		-- sets the start address of the frame in memory
					when "001"  => iRegLength		<= unsigned(AS_DataWrite);			-- sets the length of one frame in memory in number of 32 bit words
					when "010"  => iRegEnable		<= AS_DataWrite(0);					-- sets the state of the camera interface
					when "011"  => iRegBurst		<= unsigned(AS_DataWrite);			-- sets the length of the burst to transfer in words of 32 bits
					when "100"	=> iRegLight		<= AS_DataWrite(0);					-- sets the lighting conditions of the camera
					when others => null;
				end case;
			end if;
		end if;
	end process;
	
	
	-- Avalon slave read from registers.
	process(Clk, EndBuffer)
	begin
		if rising_edge(Clk) then
			AS_DataRead <= (others => '0');
			if AS_Read = '1' then
				case AS_Adr is
					when "000"  => AS_DataRead		<= std_logic_vector(iRegAdr);   			-- reads the start address of the frame in memory
					when "001"  => AS_DataRead		<= std_logic_vector(iRegLength);			-- reads the length of one frame in memory in number of 32 bit words
					when "010"  => AS_DataRead(0)	<= iRegEnable;									-- reads the state of the camera interface
					when "011"  => AS_DataRead		<= std_logic_vector(iRegBurst);			-- reads the lentgth of the busrt to transfer
					when "100"	=> AS_DataRead(0)	<= iRegLight;									-- reads the lighting conditions of the camera
					when others => null;
				end case;
			end if;
		end if;
	end process;
		
end main;