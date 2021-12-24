library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity PWM_gen is
	port(
		clk 				: in std_logic;
		nReset 			: in std_logic;
		
		-- Internal interface (i.e. Avalon slave).
		address 			: in std_logic_vector(2 downto 0);
		write 			: in std_logic;
		read 				: in std_logic;
		writedata 		: in std_logic_vector(31 downto 0);
		readdata 		: out std_logic_vector(31 downto 0);
		
		-- External interface (i.e. conduit).
		ParPort 			: inout std_logic_vector(7 downto 0)
	);
	
end PWM_gen;


architecture comp of PWM_gen is

	signal iRegDir 			: std_logic_vector(7 downto 0) 	:= (others => '0');
	signal iRegPort 			: std_logic_vector(7 downto 0)	:= (others => '0');
	signal iRegPin 			: std_logic_vector(7 downto 0)	:= (others => '0');
	signal iRegPeriod 		: unsigned(26 downto 0)				:= (others => '0');
	signal iRegDuty			: unsigned(26 downto 0)				:= (others => '0');
	signal iRegPolarity		: std_logic_vector(0 downto 0)	:= (others => '0');
	signal iCounter			: unsigned(26 downto 0)				:= (others => '0');
	
begin

	-- Parallel Port output value.
	process(iRegDir, iRegPort)
	begin
		for i in 0 to 7 loop
			if iRegDir(i) = '1' then
				ParPort(i) <= iRegPort(i);
			else
				ParPort(i) <= 'Z';
			end if;
		end loop;
	end process;
	
	
	-- Parallel Port input value.
	iRegPin <= ParPort;
	
	
	-- PWM_gen
	process(clk, nReset)
	begin 
		if nReset = '0' then
			iCounter <= (others => '0');
			iRegPort <= (others => '0');
		
		elsif rising_edge(clk) then
			if (iRegPeriod > 0 and iRegDuty > 0) then
				if (iCounter = iRegPeriod - 1) then
					iCounter <= (others => '0');
				else
					iCounter <= iCounter + 1;
				end if;
			 
				if (iCounter <= iRegDuty - 1) then 
					for i in 0 to 7 loop
						iRegPort(i) <= iRegPolarity(0);
					end loop;
				else
					for i in 0 to 7 loop
						iRegPort(i) <= not(iRegPolarity(0));
					end loop;
				end if;
				
			else
				for i in 0 to 7 loop
						iRegPort(i) <= not(iRegPolarity(0));
				end loop;
			end if;
			
		end if;
	end process;
				
				
	
	
	-- Avalon slave write to registers.
	process(clk, nReset)
	begin
		if nReset = '0' then
			iRegDir <= (others => '0');
			
		elsif rising_edge(clk) then
			if write = '1' then
				case Address is
					when "000" => iRegDir 		<= writedata(7 downto 0);   							-- choose the direction input/output
					when "101" => iRegPeriod 	<= unsigned(writedata(26 downto 0));				-- sets the period of the PWM
					when "110" => iRegDuty 		<= unsigned(writedata(26 downto 0));				-- sets the Duty cycle value
					when "111" => iRegPolarity <= writedata(0 downto 0);								-- sets the polarity of each pin
					when others => null;
				end case;
			end if;
		end if;
	end process;
	
	
	-- Avalon slave read from registers.
	process(clk)
	begin
		if rising_edge(clk) then
			readdata <= (others => '0');
			if read = '1' then
				case address is
					when "000" => readdata <= std_logic_vector(resize(signed(iRegDir), readdata'length));				-- read the direction of each pin
					when "001" => readdata <= std_logic_vector(resize(signed(iRegPin), readdata'length));				-- read the value of each input pin
					when "010" => readdata <= std_logic_vector(resize(signed(iRegPort), readdata'length));				-- read the value of each output pin
					when "101" => readdata <= std_logic_vector(resize(iRegPeriod, readdata'length));														-- read the value of the period of the PWM
					when "110" => readdata <= std_logic_vector(resize(iRegDuty, readdata'length));															-- read the value of the Duty cycle
					when "111" => readdata <= std_logic_vector(resize(signed(iRegPolarity), readdata'length));		-- read the value of the Polarity of each pin
					when others => null;
				end case;
			end if;
		end if;
	end process;
	
	
end comp;