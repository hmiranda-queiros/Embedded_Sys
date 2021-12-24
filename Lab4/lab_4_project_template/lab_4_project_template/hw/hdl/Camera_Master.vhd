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
			
			iRegAdr 			: in unsigned(31 downto 0);
			iRegLength 		: in unsigned(31 downto 0);
			iRegEnable		: inout std_logic;
			iRegBurst		: in unsigned(31 downto 0)
			
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
		if nReset = '0' then 													-- Default values at Reset
			DataAck 				<= '0';
			SM 					<= Idle;
			AM_Write 			<= '0';
			AM_ByteEnable 		<= "0000";
			AM_DataWrite		<= (others => '0');
			AM_BurstCount		<= (others => '0');
			AM_Adr				<= (others => '0');
			CntAddress 			<= (others => '0');
			CntLength 			<= (others => '0');
			CntBurst				<= (others => '0');
	
		elsif rising_edge(Clk) then 
			case SM is
				when Idle =>
					if iRegLength /= 0 then 									-- Start if Length /=0
						SM 			<= WaitData;
						CntAddress	<= iRegAdr;
						CntLength	<= iRegLength;
						CntBurst		<= iRegBurst; 
					end if;
					
				when WaitData =>
					if iRegLength = 0 then 										-- Idle if Length =0 -> go Idle
						SM <= Idle;
					elsif NewData = '1' then 									-- Receive new data burst 
						AM_Adr 			<= std_logic_vector(CntAddress);
						AM_Write 		<= '1';
						AM_BurstCount 	<= std_logic_vector(iRegBurst);
						AM_ByteEnable 	<= "1111";
						AM_DataWrite	<= NewPixels;
						if AM_WaitRequest = '0' then
							CntBurst 		<= CntBurst - 1;
							CntAddress 		<= CntAddress + 4;
							SM 				<= WriteData;
						end if;
					end if;
					
				when WriteData => 												-- Write on Avalon Bus
					AM_DataWrite		<= NewPixels;
					if AM_WaitRequest = '0' and CntBurst /= 0 then
						CntBurst 		<= CntBurst - 1;
						CntAddress 		<= CntAddress + 4;
					elsif CntBurst = 0 then										-- Burst tranfer finished
						SM 				<= AcqData;
						AM_Adr 			<= (others => '0');
						AM_BurstCount	<= (others => '0');
						AM_DataWrite	<= (others => '0');
						AM_Write 		<= '0';
						AM_ByteEnable 	<= "0000";
						DataAck 			<= '1';
					end if;
					
				when AcqData => 													-- Wait end of request
					if NewData <= '0' then
						DataAck <= '0';
						SM <= WaitData;
						
						if CntLength /= iRegBurst then 						-- Not End of buffer → new address
							CntLength <= CntLength - iRegBurst;
						else 															-- Yes → desable camera interface and send flag to CPU
							iRegEnable <= '0';
							SM <= WaitCPU;
						end if;
						
					end if;
					
				when WaitCPU => 													-- Wait for CPU to start a new frame
					if iRegEnable = '1' then
						SM <= Idle;
					end if;
						
			end case;
		end if;
		
	end process;

end comp;