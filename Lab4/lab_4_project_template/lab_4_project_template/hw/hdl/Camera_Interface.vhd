library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Camera_Interface is
	port(
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
end Camera_Interface;


architecture comp of Camera_Interface is
	type state 						is (Idle, Read_G1_B, Read_R_G2, Ops, WritePixels, WaitRead);
	type state_Entry 				is (Idle, WaitLine1, WaitLine2, ReadLine1, ReadLine2);
	type state_Exit 				is (Idle, SendData);
	signal SM						: state;
	signal SM_Entry				: state_Entry;
	signal SM_Exit					: state_Exit;
	
	signal wrreq_FIFO_Entry_1	: std_logic;
	signal wrreq_FIFO_Entry_2	: std_logic; 										
	signal wrreq_FIFO_Exit		: std_logic;										
	
	signal rdreq_FIFO_Entry_1	: std_logic;										
	signal rdreq_FIFO_Entry_2	: std_logic;										
	signal rdreq_FIFO_Exit		: std_logic;										
											
	signal usedw_FIFO_Exit		: std_logic_vector(11 downto 0);
	signal empty_FIFO_1			: std_logic;
	signal empty_FIFO_2			: std_logic;
	
	signal q_FIFO_Entry_1		: std_logic_vector(11 downto 0);				
	signal q_FIFO_Entry_2		: std_logic_vector(11 downto 0);
	
	signal data_FIFO_Entry_1	: std_logic_vector(11 downto 0);
	signal data_FIFO_Entry_2	: std_logic_vector(11 downto 0);
	
	signal PixelsReady			: std_logic_vector(31 downto 0);
	signal Clear					: std_logic;
	
	signal R							: std_logic_vector(11 downto 0);
	signal G1						: std_logic_vector(11 downto 0);
	signal G2						: std_logic_vector(11 downto 0);
	signal G							: std_logic_vector(11 downto 0);
	signal B							: std_logic_vector(11 downto 0);
	signal CntPixels				: unsigned(1 downto 0);
	signal CntBurst				: unsigned(31 downto 0);
	

	component FIFO_Entry is
		port(
			aclr	 			: in std_logic;
			clock	 			: in std_logic;
			data	 			: in std_logic_vector(11 downto 0);
			rdreq	 			: in std_logic;
			wrreq	 			: in std_logic;
			empty				: out std_logic;
			q	 				: out std_logic_vector(11 downto 0)
		);
	end component FIFO_Entry;
		
		
	component FIFO_Exit is
		port(
			aclr	 			: in std_logic;
			clock	 			: in std_logic;
			data	 			: in std_logic_vector(31 downto 0);
			rdreq	 			: in std_logic;
			wrreq	 			: in std_logic;
			q	 				: out std_logic_vector(31 downto 0);
			usedw				: out std_logic_vector(11 downto 0)
		);
	end component FIFO_Exit;

begin
	
	FIFO_Entry_1 : component FIFO_Entry
		port map (
			aclr	 			=> Clear,
			clock	 			=> Clk,
			data	 			=> data_FIFO_Entry_1,
			rdreq	 			=> rdreq_FIFO_Entry_1,
			wrreq	 			=> wrreq_FIFO_Entry_1,
			empty				=> empty_FIFO_1,
			q	 				=> q_FIFO_Entry_1
		);
		
	FIFO_Entry_2 : component FIFO_Entry 
		port map (
			aclr	 			=> Clear,
			clock	 			=> Clk,
			data	 			=> data_FIFO_Entry_2,
			rdreq	 			=> rdreq_FIFO_Entry_2,
			wrreq	 			=> wrreq_FIFO_Entry_2,
			empty				=> empty_FIFO_2,
			q	 				=> q_FIFO_Entry_2
		);
		
	FIFO_Exit_1 : component FIFO_Exit 
		port map (
			aclr	 	=> Clear,
			clock	 	=> Clk,
			data	 	=> PixelsReady,
			rdreq	 	=> rdreq_FIFO_Exit,
			wrreq	 	=> wrreq_FIFO_Exit,
			q	 		=> NewPixels,
			usedw	 	=> usedw_FIFO_Exit
		);
		
	-- Continuously updates these output signals
	RESETn <= nReset;
	XCLKIN <= Clk;
	
	-- Acquisition rows from Camera
	process (nReset, PIXCLK)
	begin
		if nReset = '0' then										-- Default values at Reset
			wrreq_FIFO_Entry_1		<= '0';
			wrreq_FIFO_Entry_2		<= '0';
			SM_Entry						<= Idle;
			Clear 						<= '1';
			data_FIFO_Entry_1 		<= (others => '0');
			data_FIFO_Entry_2 		<= (others => '0');
		
		elsif rising_edge(PIXCLK) then
			case SM_Entry is
				when Idle =>											-- Stays idle while a frame ends and camera interface is enabled
					wrreq_FIFO_Entry_1		<= '0';
					wrreq_FIFO_Entry_2		<= '0';
					data_FIFO_Entry_1 		<= (others => '0');
					data_FIFO_Entry_2 		<= (others => '0');
					
					if iRegEnable = '1' and FVAL = '0' then
						SM_Entry <= WaitLine1;
					end if;
				
				when WaitLine1 =>										-- Waits for the beginning of the first line
					if LVAL = '1' then
						data_FIFO_Entry_1 	<= D;
						wrreq_FIFO_Entry_1	<= '1';
						wrreq_FIFO_Entry_2	<= '0';
						SM_Entry 				<= ReadLine1;
					end if;
				
				when ReadLine1 =>										-- Reads the first line
					data_FIFO_Entry_1 		<= D;
					if LVAL = '0' then
						wrreq_FIFO_Entry_1	<= '0';
						wrreq_FIFO_Entry_2	<= '0';
						data_FIFO_Entry_1 	<= (others => '0');
						SM_Entry 				<= WaitLine2;
					end if;
					
				when WaitLine2 =>										-- Waits for the beginning of the second line
					if LVAL = '1' then
						data_FIFO_Entry_2 	<= D;
						wrreq_FIFO_Entry_1 	<= '0';
						wrreq_FIFO_Entry_2 	<= '1';
						SM_Entry 				<= ReadLine2;
					end if;
						
				when ReadLine2 =>										-- Reads the second line
					data_FIFO_Entry_2 		<= D;
					if  LVAL = '0' then
						wrreq_FIFO_Entry_1 	<= '0';
						wrreq_FIFO_Entry_2 	<= '0';
						data_FIFO_Entry_2 	<= (others => '0');
						SM_Entry 				<= WaitLine1;
					end if;		
			end case;
			
			Clear <= '0';
			if iRegEnable = '0' then								-- When acquisition is disabled, state goes to idle and FIFOs are cleared
				SM_Entry	<= Idle;
				Clear		<= '1';
			end if;
		end if;
	end process;
	
	
	-- Transformation Pixels from Camera to LCD format
	process (Clk, nReset)
	begin
		if nReset = '0' then													-- Default values at Reset
			rdreq_FIFO_Entry_1		<= '0';
			rdreq_FIFO_Entry_2		<= '0';
			wrreq_FIFO_Exit			<= '0';
			R								<= (others => '0');
			G1								<= (others => '0');
			G2								<= (others => '0');
			G								<= (others => '0');
			B								<= (others => '0');
			PixelsReady					<= (others => '0');
			CntPixels					<= (others => '0');
			SM 							<= Idle;
		
		elsif rising_edge(Clk) then
			case SM is
				when Idle =>													-- Stays idle till the second FIFO is not empty
					rdreq_FIFO_Entry_1		<= '0';
					rdreq_FIFO_Entry_2		<= '0';
					wrreq_FIFO_Exit			<= '0';
					R								<= (others => '0');
					G1								<= (others => '0');
					G2								<= (others => '0');
					G								<= (others => '0');
					B								<= (others => '0');
					PixelsReady					<= (others => '0');
					CntPixels					<= (others => '0');
					
					if empty_FIFO_2 = '0' then
						rdreq_FIFO_Entry_1	<= '1';										
						rdreq_FIFO_Entry_2	<= '1';
						SM 						<= WaitRead;
					end if;
					
				when WaitRead =>												-- Waits one clock cycle before reading the two first pixels of the pair of rows
					wrreq_FIFO_Exit		<= '0';
					SM							<= Read_G1_B;
					
				when Read_G1_B =>												-- Reads the pixels G1 and B
					wrreq_FIFO_Exit		<= '0';
					G1							<= q_FIFO_Entry_1;				
					B     					<= q_FIFO_Entry_2;
					SM 						<= Read_R_G2;
					
					rdreq_FIFO_Entry_1	<= '0';										
					rdreq_FIFO_Entry_2	<= '0';
					
				when Read_R_G2 =>												-- Reads the pixles R and G2
					R							<= q_FIFO_Entry_1;				
					G2    					<= q_FIFO_Entry_2;
					SM 						<= Ops;
				
				when Ops =>														-- Averages G1 and G2 to create G
					G 					<= std_logic_vector(shift_right(unsigned(G1) + unsigned(G2), 1));
					CntPixels 		<= CntPixels + 1;
					SM					<= WritePixels;
						
				When WritePixels =>											-- Writes the previous pixel RGB into PixelsReady
					if CntPixels = 1 then 
						if iRegLight = '1' then
							PixelsReady(15 downto 0)	<= B(11 downto 7) & G(11 downto 6) & R(11 downto 7);
						else 
							PixelsReady(15 downto 0)	<= B(4 downto 0) & G(5 downto 0) & R(4 downto 0); 
						end if;
					
					else 															-- When CntPixels = 2, these two 16 pixels are written into FIFO Exit
						if iRegLight = '1' then
							PixelsReady(31 downto 16)	<= B(11 downto 7) & G(11 downto 6) & R(11 downto 7);
						else 
							PixelsReady(31 downto 16)	<= B(4 downto 0) & G(5 downto 0) & R(4 downto 0); 
						end if;
						
						wrreq_FIFO_Exit			<= '1';
						CntPixels 					<= (others => '0');
					end if;
					
					if Empty_FIFO_2 = '1' then								-- If FIFO Entry 2 is empty we go back to idle state
						SM 	<= Idle;
					
					else															-- If not we go to WaitRead to read the next pixel in the row
						rdreq_FIFO_Entry_1	<= '1';										
						rdreq_FIFO_Entry_2	<= '1';
						SM							<= WaitRead;
					end if;
			end case;
			
			if iRegEnable = '0' then										-- When acquisition is disabled, state goes to idle
				SM <= Idle;
			end if;
			
		end if;
	end process;
	
	
		
	-- Send Pixel to DMA
	process (Clk, nReset)
	begin
		if nReset = '0' then											-- Default values at Reset
			NewData						<= '0';
			CntBurst						<= (others => '0');
			rdreq_FIFO_Exit			<= '0';
			SM_Exit						<= Idle;
			
		elsif rising_edge(Clk) then
			case SM_Exit is
				when Idle =>											-- Stays idle till FIFO Exit has at least iRegurst 32 bit words ready in its buffer
					rdreq_FIFO_Exit			<= '0';
					NewData						<= '0';
					CntBurst						<= iRegBurst;
					
					if unsigned(usedw_FIFO_Exit) >= iRegBurst then
						SM_Exit					<= SendData;
						rdreq_FIFO_Exit		<= '1';
					end if;
					
				when SendData =>										-- Sends iRegBurst data to DMA and finishes by putting NewData to '0'
					NewData 	<= '1';
					
					if AM_WaitRequest = '0' and CntBurst /= 1 then
						CntBurst 			<= CntBurst - 1;
						rdreq_FIFO_Exit	<= '1';
						
					else
						rdreq_FIFO_Exit	<= '0';
						if DataAck 	= '1' then
							NewData		<= '0';
							SM_Exit		<= Idle;
						end if;
					end if;
			end case;
			
			if iRegEnable = '0' then								-- When acquisition is disabled, state goes to idle
				SM_Exit <= Idle;
			end if;
		end if;
	end process;


end comp;