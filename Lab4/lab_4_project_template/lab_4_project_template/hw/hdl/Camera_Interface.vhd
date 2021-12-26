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
		AM_WaitRequest	: in std_logic
		
	);
end Camera_Interface;


architecture comp of Camera_Interface is
	type state 						is (Idle, Read_G1_B, Read_R_G2, Ops, WritePixels, WaitRead);
	type state_Entry 				is (Idle, WaitLine1, WaitLine2, ReadLine1, ReadLine2);
	type state_Exit 				is (Idle, SendData);
	signal SM						: state;
	signal SM_Entry					: state_Entry;
	signal SM_Exit					: state_Exit;
	
	signal wrreq_FIFO_Entry_1	: std_logic;
	signal wrreq_FIFO_Entry_2	: std_logic; 										
	signal wrreq_FIFO_Exit		: std_logic;										
	
	signal rdreq_FIFO_Entry_1	: std_logic;										
	signal rdreq_FIFO_Entry_2	: std_logic;										
	signal rdreq_FIFO_Exit		: std_logic;										
											
	signal usedw_FIFO_Exit		: std_logic_vector(7 downto 0);
	signal empty_FIFO_1			: std_logic;
	signal empty_FIFO_2			: std_logic;
	
	signal q_FIFO_Entry_1		: std_logic_vector(11 downto 0);				
	signal q_FIFO_Entry_2		: std_logic_vector(11 downto 0);
	
	signal PixelsReady			: std_logic_vector(31 downto 0);
	signal Clear					: std_logic;
	
	signal R							: std_logic_vector(11 downto 0);
	signal G1						: std_logic_vector(11 downto 0);
	signal G2						: std_logic_vector(11 downto 0);
	signal G							: std_logic_vector(11 downto 0);
	signal B							: std_logic_vector(11 downto 0);
	signal CntPixels				: unsigned(2 downto 0);
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
			usedw				: out std_logic_vector(7 downto 0)
		);
	end component FIFO_Exit;

begin
	
	FIFO_Entry_1 : component FIFO_Entry
		port map (
			aclr	 			=> Clear,
			clock	 			=> Clk,
			data	 			=> D,
			rdreq	 			=> rdreq_FIFO_Entry_1,
			wrreq	 			=> wrreq_FIFO_Entry_1,
			empty				=> empty_FIFO_1,
			q	 				=> q_FIFO_Entry_1
		);
		
	FIFO_Entry_2 : component FIFO_Entry 
		port map (
			aclr	 			=> Clear,
			clock	 			=> Clk,
			data	 			=> D,
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
		
	
	RESETn <= nReset;
	XCLKIN <= Clk;
	
	-- Clear FIFOs
	process (nReset, Clk)
	begin
		Clear <= not nReset;
		
		if rising_edge(Clk) and iRegEnable = '0' then 
			Clear <= '1';
		end if;
		
	end process;
	
	
	-- Acquisition rows from Camera
	process (nReset, LVAL, FVAL)
	begin
		if nReset = '0' then
			wrreq_FIFO_Entry_1		<= '0';
			wrreq_FIFO_Entry_2		<= '0';
			SM_Entry				<= Idle;
			
		
		elsif iRegEnable = '0' then
			SM_Entry <= Idle;	
		end if;
			
		case SM_Entry is
			when Idle =>
				wrreq_FIFO_Entry_1		<= '0';
				wrreq_FIFO_Entry_2		<= '0';
				
				if iRegEnable = '1' and FVAL = '0' then
					SM_Entry <= WaitLine1;
				end if;
			
			when WaitLine1 =>
				if LVAL = '1' then
					wrreq_FIFO_Entry_1	<= '1';
					wrreq_FIFO_Entry_2	<= '0';
					SM_Entry <= ReadLine1;
				end if;
			
			when ReadLine1 =>
				if LVAL = '0' then
					wrreq_FIFO_Entry_1	<= '0';
					wrreq_FIFO_Entry_2	<= '0';
					SM_Entry <= WaitLine2;
				end if;
				
			when WaitLine2 =>
				if LVAL = '1' then
					wrreq_FIFO_Entry_1 <= '0';
					wrreq_FIFO_Entry_2 <= '1';
					SM_Entry <= ReadLine2;
				end if;
					
			when ReadLine2 =>
				if  LVAL = '0' then
					wrreq_FIFO_Entry_1 <= '0';
					wrreq_FIFO_Entry_2 <= '0';
					SM_Entry <= WaitLine1;
				end if;		
		end case;
		
	end process;
	
	
	-- Transformation Pixels
	process (Clk, nReset)
	begin
		if nReset = '0' then
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
			if iRegEnable = '0' then
				SM <= Idle;
			end if;
			
			case SM is
				when Idle =>
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
					
				when WaitRead =>
					wrreq_FIFO_Exit		<= '0';
					SM					<= Read_G1_B;
					
				when Read_G1_B =>
					wrreq_FIFO_Exit		<= '0';
					G1							<= q_FIFO_Entry_1;				
					B     					<= q_FIFO_Entry_2;
					SM 						<= Read_R_G2;
					
					rdreq_FIFO_Entry_1	<= '0';										
					rdreq_FIFO_Entry_2	<= '0';
					
				when Read_R_G2 =>
					R							<= q_FIFO_Entry_1;				
					G2    					<= q_FIFO_Entry_2;
					SM 						<= Ops;
				
				when Ops =>
					G 					<= std_logic_vector(shift_right(unsigned(G1) + unsigned(G2), 1));
					CntPixels 		<= CntPixels + 1;
					SM					<= WritePixels;
						
				When WritePixels =>
					if CntPixels = 1 then 
						PixelsReady(15 downto 0)	<= B(11 downto 7) & G(11 downto 6) & R(11 downto 7); 
					
					else 
						PixelsReady(31 downto 16)	<= B(11 downto 7) & G(11 downto 6) & R(11 downto 7);
						wrreq_FIFO_Exit				<= '1';
						CntPixels 					<= (others => '0');
					end if;
					
					if Empty_FIFO_2 = '1' then
						SM 	<= Idle;
					
					else 
						rdreq_FIFO_Entry_1	<= '1';										
						rdreq_FIFO_Entry_2	<= '1';
						SM							<= WaitRead;
					end if;
			end case;
		end if;
	end process;
	
	
		
	-- Send Pixel to DMA
	process (Clk, nReset)
	begin
		if nReset = '0' then
			NewData						<= '0';
			CntBurst						<= (others => '0');
			rdreq_FIFO_Exit			<= '0';
			NewPixels					<= (others => '0');
			SM_Exit				<= Idle;
			
		elsif rising_edge(Clk) then
			if iRegEnable = '0' then
				SM_Exit <= Idle;
			end if;
			
			case SM_Exit is
				when Idle =>
					rdreq_FIFO_Exit			<= '0';
					NewPixels					<= (others => '0');
					NewData						<= '0';
					CntBurst						<= iRegBurst;
					
					if unsigned(usedw_FIFO_Exit) >= iRegBurst and iRegEnable = '1' then
						SM_Exit				<= SendData;
						rdreq_FIFO_Exit		<= '1';
					end if;
					
				when SendData =>
					NewData 	<= '1';
					
					if AM_WaitRequest = '0' and CntBurst /= 1 then
						CntBurst <= CntBurst - 1;
						rdreq_FIFO_Exit	<= '1';
						
					else
						rdreq_FIFO_Exit	<= '0';
						if DataAck 	<= '1' then
							NewData	<= '0';
							SM_Exit		<= Idle;
						end if;
					end if;
			end case;	
		end if;
	end process;


end comp;