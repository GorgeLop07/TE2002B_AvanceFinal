-- =============================================================
-- UART Transmitter (8N1, no oversampling)
-- Protocol: 1 start bit (low) + 8 data bits LSB-first + 1 stop bit (high)
--
-- s_tick fires once per bit period (from baudrate_gen).
-- Each state waits for 1 tick before advancing.
--
-- tx_start: pulse high for 1 clock to begin transmission.
-- tx_done_tick: pulses high for 1 clock when frame is complete.
-- =============================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
	port(
		clk, reset   : in  std_logic;
		tx_start     : in  std_logic;
		s_tick       : in  std_logic;
		d_in         : in  std_logic_vector(7 downto 0);
		tx_done_tick : out std_logic;
		tx           : out std_logic
	);
end uart_tx;

architecture fsm of uart_tx is

	type state_type is (idle, start, data, stop);
	signal state_reg, state_next : state_type;

	signal n_reg,  n_next  : unsigned(2 downto 0);
	signal b_reg,  b_next  : std_logic_vector(7 downto 0);

begin

	process(clk, reset)
	begin
		if reset = '1' then
			state_reg <= idle;
			n_reg     <= (others => '0');
			b_reg     <= (others => '0');
		elsif rising_edge(clk) then
			state_reg <= state_next;
			n_reg     <= n_next;
			b_reg     <= b_next;
		end if;
	end process;

	process(state_reg, n_reg, b_reg, tx_start, s_tick, d_in)
	begin
		state_next   <= state_reg;
		n_next       <= n_reg;
		b_next       <= b_reg;
		tx_done_tick <= '0';
		tx           <= '1';

		case state_reg is

			when idle =>
				tx <= '1';
				if tx_start = '1' then
					state_next <= start;
					b_next     <= d_in;
				end if;

			when start =>
				tx <= '0';
				if s_tick = '1' then
					state_next <= data;
					n_next     <= (others => '0');
				end if;

			when data =>
				tx <= b_reg(0);
				if s_tick = '1' then
					b_next <= '0' & b_reg(7 downto 1);
					if n_reg = 7 then
						state_next <= stop;
					else
						n_next <= n_reg + 1;
					end if;
				end if;

			when stop =>
				tx <= '1';
				if s_tick = '1' then
					state_next   <= idle;
					tx_done_tick <= '1';
				end if;

		end case;
	end process;

end fsm;
