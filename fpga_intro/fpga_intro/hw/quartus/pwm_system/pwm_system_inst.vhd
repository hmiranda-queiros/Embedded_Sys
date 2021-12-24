	component pwm_system is
		port (
			clk_clk                              : in    std_logic                    := 'X';             -- clk
			pwm_gen_0_external_connection_export : inout std_logic_vector(7 downto 0) := (others => 'X'); -- export
			reset_reset_n                        : in    std_logic                    := 'X'              -- reset_n
		);
	end component pwm_system;

	u0 : component pwm_system
		port map (
			clk_clk                              => CONNECTED_TO_clk_clk,                              --                           clk.clk
			pwm_gen_0_external_connection_export => CONNECTED_TO_pwm_gen_0_external_connection_export, -- pwm_gen_0_external_connection.export
			reset_reset_n                        => CONNECTED_TO_reset_reset_n                         --                         reset.reset_n
		);

