-- uart_rx.vhd  8N1  115200 baud
-- rx_done_tick = '1' por un ciclo cuando llega un byte completo

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is
    port(
        clk          : in  std_logic;
        reset        : in  std_logic;
        s_tick       : in  std_logic;
        rx           : in  std_logic;
        rx_done_tick : out std_logic;
        d_out        : out std_logic_vector(7 downto 0)
    );
end uart_rx;

architecture fsm of uart_rx is

    type state_type is (idle, start, data, stop);
    signal state_reg, state_next : state_type;

    signal s_reg,  s_next  : unsigned(3 downto 0);  -- contador de ticks (0-15)
    signal n_reg,  n_next  : unsigned(2 downto 0);  -- bit counter (0-7)
    signal b_reg,  b_next  : std_logic_vector(7 downto 0);

begin

    process(clk, reset)
    begin
        if reset = '1' then
            state_reg <= idle;
            s_reg     <= (others => '0');
            n_reg     <= (others => '0');
            b_reg     <= (others => '0');
        elsif rising_edge(clk) then
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
        end if;
    end process;

    process(state_reg, s_reg, n_reg, b_reg, s_tick, rx)
    begin
        state_next   <= state_reg;
        s_next       <= s_reg;
        n_next       <= n_reg;
        b_next       <= b_reg;
        rx_done_tick <= '0';

        case state_reg is

            when idle =>
                if rx = '0' then
                    state_next <= start;
                    s_next     <= (others => '0');
                end if;

            when start =>
                if s_tick = '1' then
                    if s_reg = 7 then
                        state_next <= data;
                        s_next     <= (others => '0');
                        n_next     <= (others => '0');
                    else
                        s_next <= s_reg + 1;
                    end if;
                end if;

            when data =>
                if s_tick = '1' then
                    if s_reg = 15 then
                        s_next    <= (others => '0');
                        b_next    <= rx & b_reg(7 downto 1);
                        if n_reg = 7 then
                            state_next <= stop;
                        else
                            n_next <= n_reg + 1;
                        end if;
                    else
                        s_next <= s_reg + 1;
                    end if;
                end if;

            when stop =>
                if s_tick = '1' then
                    if s_reg = 15 then
                        rx_done_tick <= '1';
                        state_next   <= idle;
                    else
                        s_next <= s_reg + 1;
                    end if;
                end if;

        end case;
    end process;

    d_out <= b_reg;

end fsm;
