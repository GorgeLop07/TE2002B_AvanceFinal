LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

-- Genera un tick cada M ciclos de reloj
-- Para 115200 bps con clk=50 MHz: M=434, N=9
ENTITY baudrate_gen IS
    GENERIC(M : integer := 434; N : integer := 9);
    PORT(
        clk, reset : IN  std_logic;
        tick       : OUT std_logic
    );
END baudrate_gen;

ARCHITECTURE rtl OF baudrate_gen IS
    SIGNAL r_reg  : unsigned(N-1 DOWNTO 0);
    SIGNAL r_next : unsigned(N-1 DOWNTO 0);
BEGIN

    PROCESS(clk, reset)
    BEGIN
        IF reset = '1' THEN
            r_reg <= (OTHERS => '0');
        ELSIF rising_edge(clk) THEN
            r_reg <= r_next;
        END IF;
    END PROCESS;

    r_next <= (OTHERS => '0') WHEN r_reg = (M-1) ELSE r_reg + 1;
    tick   <= '1'             WHEN r_reg = (M-1) ELSE '0';

END rtl;
