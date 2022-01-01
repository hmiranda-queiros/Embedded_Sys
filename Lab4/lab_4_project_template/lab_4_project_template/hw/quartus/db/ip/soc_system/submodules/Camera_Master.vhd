library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Camera_Master is 
		port (
			Clk 				: in std_logic;
			nReset			: in std_logic;
			
			AM_Adr 			: out std_logic_vector(31 downto 0);
			AM_Write			: out std_logic;
			AM_DataWrite	: out std_logic_vector(31 downto 0);
			AM_ByteEnable	: out std_logic_vector(3 downto 0);
			AM_BurstCount	: out std_logic_vector(31 downto 0);
			AM_WaitRequest	: in std_logic;
			
			NewData 			: in std_logic;
			DataAck			: out std_logic;
			NewPixels		: in std_logic_vector(31 downto 0);
			EndBuffer		: inout std_logic;
			
			iRegAdr 			: in unsigned(31 downto 0);
			iRegLength 		: in unsigned(31 downto 0);
			iRegEnable		: in std_logic;
			iRegBurst		: in unsigned(31 downto 0);
			
			state_dma		: out unsigned(2 downto 0)
			
		);
end Camera_Master;


architecture comp of Camera_Master is
	type state 				is (Idle, WaitData, WriteData, AcqData, WaitCPU);
	signal SM				: state;
	
	Signal CntAddress    : unsigned(31 downto 0);		
	Signal CntLength     : unsigned(31 downto 0);				
	Signal CntBurst		: unsigned(31 downto 0);											
	
begin

	-- Acquisition process
	process (Clk, nReset)
	begin
		if nReset = '0' then 														-- Default values at Reset
			DataAck 				<= '0';
			SM 					<= Idle;
			AM_Write 			<= '0';
			EndBuffer			<= '0';
			AM_ByteEnable 		<= "0000";
			AM_DataWrite		<= (others => '0');
			AM_BurstCount		<= (others => '0');
			AM_Adr				<= (others => '0');
			CntAddress 			<= (others => '0');
			CntLength 			<= (others => '0');
			CntBurst				<= (others => '0');
			state_dma				<= (others => '0');
	
		elsif rising_edge(Clk) then 
			case SM is
				when Idle =>
					state_dma <= "001";
					if iRegLength /= 0 then 										-- Starts if iRegLength /=0
						SM 			<= WaitData;
						CntAddress	<= iRegAdr;
						CntLength	<= iRegLength; 
						CntBurst		<= iRegBurst;
					end if;
					
				when WaitData =>
					state_dma <= "010";
					if iRegLength = 0 then 											-- goes Idle if iRegLength = 0 
						SM <= Idle;
					elsif NewData = '1' then 										-- Receives new data burst 
						AM_Adr 			<= std_logic_vector(CntAddress);
						AM_Write 		<= '1';
						AM_BurstCount 	<= std_logic_vector(iRegBurst);
						AM_ByteEnable 	<= "1111";
						AM_DataWrite	<= NewPixels;
						if AM_WaitRequest = '0' then								-- Can receive next 32 bit word when the first is sent
							CntBurst 	<= CntBurst - 1;
							CntAddress 	<= CntAddress + 4;
							SM 			<= WriteData;
						end if;
					end if;
					
				when WriteData => 													-- Writes on Avalon Bus
					AM_DataWrite		<= NewPixels;
					state_dma <= "011";
					if AM_WaitRequest = '0' and CntBurst /= 0 then			-- Can receive next 32 bit word when the previous is sent
						CntBurst 		<= CntBurst - 1;
						CntAddress 		<= CntAddress + 4;
					elsif CntBurst = 0 then											-- Burst transfer finished
						SM 				<= AcqData;
						AM_Adr 			<= (others => '0');
						AM_BurstCount	<= (others => '0');
						AM_DataWrite	<= (others => '0');
						AM_Write 		<= '0';
						AM_ByteEnable 	<= "0000";
						DataAck 			<= '1';
						CntBurst			<= iRegBurst;
					end if;
					
				when AcqData => 														-- Waits end of request
					state_dma <= "100";
					if NewData <= '0' then
						DataAck <= '0';
						
						if CntLength /= iRegBurst then 							-- Not End of buffer → goes back to WaitData for a new Burst Transfer
							CntLength	<= CntLength - iRegBurst;
							SM				<= WaitData;
						else 																-- Yes → disable camera interface and put EndBuffer to '1'
							EndBuffer	<= '1';
							SM 			<= WaitCPU;
						end if;
						
					end if;
					
				when WaitCPU => 														-- Waits for CPU polling to start a new frame
					state_dma <= "101";
					EndBuffer	<= '0';
					if iRegEnable = '1' and EndBuffer = '0' then
						SM 		<= Idle;
					end if;	
			end case;
			
			if iRegEnable = '0' then												-- When acquisition is disabled, state goes to WaitCPU
				SM		<= WaitCPU;
			end if;
			
		end if;
		
	end process;

end comp;