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
	type state 						is (Idle, Read_G1_B, Read_R_G2, Ops, WritePixels);
	type state_EXIT 				is (Idle, SendData);
	signal SM						: state;
	signal SM_EXIT					: state_EXIT;
	
	signal wrreq_FIFO_Entry_1	: std_logic;
	signal wrreq_FIFO_Entry_2	: std_logic; 										
	signal wrreq_FIFO_Exit		: std_logic;										
	
	signal rdreq_FIFO_Entry_1	: std_logic;										
	signal rdreq_FIFO_Entry_2	: std_logic;										
	signal rdreq_FIFO_Exit		: std_logic;										
	
	signal almost_full_FIFO_1	: std_logic; 										
	signal almost_full_FIFO_2	: std_logic;										
	signal usedw_FIFO_Exit		: std_logic_vector(7 downto 0);

	signal Empty_FIFO_1			: std_logic;
	signal Empty_FIFO_2			: std_logic;
	
	signal q_FIFO_Entry_1		: std_logic_vector(11 downto 0);				
	signal q_FIFO_Entry_2		: std_logic_vector(11 downto 0);
	
	signal PixelsReady			: std_logic_vector(31 downto 0);
	signal Frame_OK				: std_logic;
	signal Clear					: std_logic;
	
	signal R							: std_logic_vector(11 downto 0);
	signal G1						: std_logic_vector(11 downto 0);
	signal G2						: std_logic_vector(11 downto 0);
	signal G							: std_logic_vector(11 downto 0);
	signal B							: std_logic_vector(11 downto 0);
	signal CntPixels				: unsigned(1 downto 0);
	Signal CntBurst				: unsigned(31 downto 0);
	

	component FIFO_Entry is
		port(
			aclr	 			: in std_logic;
			clock	 			: in std_logic;
			data	 			: in std_logic_vector(11 downto 0);
			rdreq	 			: in std_logic;
			wrreq	 			: in std_logic;
			almost_full	 	: out std_logic;
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
			almost_full	 	=> almost_full_FIFO_1,
			empty	 			=> Empty_FIFO_1,
			q	 				=> q_FIFO_Entry_1
		);
		
	FIFO_Entry_2 : component FIFO_Entry 
		port map (
			aclr	 			=> Clear,
			clock	 			=> Clk,
			data	 			=> D,
			rdreq	 			=> rdreq_FIFO_Entry_2,
			wrreq	 			=> wrreq_FIFO_Entry_2,
			almost_full	 	=> almost_full_FIFO_2,
			empty	 			=> Empty_FIFO_2,
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
	process (nReset, iRegEnable)
	begin
		Clear <= not nReset;
		
		if iRegEnable = '0' then 
			Clear <= '1';
		end if;
		
	end process;
	
	
	-- Acquisition rows from Camera
	process (nReset, PIXCLK)
	begin
		if nReset = '0' then
			wrreq_FIFO_Entry_1		<= '0';
			wrreq_FIFO_Entry_2		<= '0';
			Frame_OK						<= '0';
		
		elsif rising_edge(PIXCLK) then	
			if iRegEnable = '1' then
				if FVAL = '0' then
					Frame_OK <= '1';
				elsif FVAL = '1' and LVAL = '1' and Frame_OK = '1' then
					if almost_full_FIFO_1 = '0' then
						wrreq_FIFO_Entry_1 <= '1';
						wrreq_FIFO_Entry_2 <= '0';
					else
						wrreq_FIFO_Entry_1 <= '0';
						wrreq_FIFO_Entry_2 <= '1';
					end if;
				else 
					wrreq_FIFO_Entry_1 <= '0';
					wrreq_FIFO_Entry_2 <= '0';
				end if;
				
			else
				wrreq_FIFO_Entry_1		<= '0';
				wrreq_FIFO_Entry_2		<= '0';
				Frame_OK						<= '0';
			end if;
		end if;
		
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
					
					if almost_full_FIFO_2 = '1' then
						rdreq_FIFO_Entry_1	<= '1';										
						rdreq_FIFO_Entry_2	<= '1';
						SM 						<= Read_G1_B;
					end if;
					
				when Read_G1_B =>
					wrreq_FIFO_Exit		<= '0';
					G1							<= q_FIFO_Entry_1;				
					B     					<= q_FIFO_Entry_2;
					SM 						<= Read_R_G2;
					
				when Read_R_G2 =>
					R							<= q_FIFO_Entry_1;				
					G2    					<= q_FIFO_Entry_2;
					SM 						<= Ops;
					
					rdreq_FIFO_Entry_1	<= '0';										
					rdreq_FIFO_Entry_2	<= '0';
				
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
						CntPixels 						<= (others => '0');
					end if;
					
					if Empty_FIFO_2 = '1' then
						SM 	<= Idle;
					
					else 
						rdreq_FIFO_Entry_1	<= '1';										
						rdreq_FIFO_Entry_2	<= '1';
						SM							<= Read_G1_B;
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
			SM_EXIT					<= Idle;
			
		elsif rising_edge(Clk) then
			if iRegEnable = '0' then
				SM_EXIT <= Idle;
			end if;
			
			case SM_EXIT is
				when Idle =>
					rdreq_FIFO_Exit			<= '0';
					NewPixels					<= (others => '0');
					NewData						<= '0';
					CntBurst						<= iRegBurst;
					
					if unsigned(usedw_FIFO_Exit) >= iRegBurst then
						SM_EXIT					<= SendData;
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
							SM_EXIT		<= Idle;
						end if;
					end if;
			end case;	
		end if;
	end process;


end comp;