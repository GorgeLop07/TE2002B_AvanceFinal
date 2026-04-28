LIBRARY ieee;
USE ieee.std_logic_1164.all, ieee.numeric_std.all;

ENTITY de10lite IS
    PORT(
        CLOCK_50 : IN  std_logic;
        KEY      : IN  std_logic_vector(1 DOWNTO 0);
        SW       : IN  std_logic_vector(9 DOWNTO 0);
        LEDR     : OUT std_logic_vector(9 DOWNTO 0);
        GPIO_TX  : OUT std_logic;
        GPIO_RX  : IN  std_logic;
        HEX_BUS  : OUT std_logic_vector(6 DOWNTO 0);
        DISP_SEL : OUT std_logic_vector(1 DOWNTO 0)
    );
END de10lite;

ARCHITECTURE Structural OF de10lite IS

    COMPONENT gumnut_with_mem IS
        GENERIC(
            IMem_file_name : string  := "gasm_text.dat";
            DMem_file_name : string  := "gasm_data.dat";
            debug          : boolean := false
        );
        PORT(
            clk_i      : in  std_logic;
            rst_i      : in  std_logic;
            port_cyc_o : out std_logic;
            port_stb_o : out std_logic;
            port_we_o  : out std_logic;
            port_ack_i : in  std_logic;
            port_adr_o : out unsigned(7 downto 0);
            port_dat_o : out std_logic_vector(7 downto 0);
            port_dat_i : in  std_logic_vector(7 downto 0);
            int_req    : in  std_logic;
            int_ack    : out std_logic
        );
    END COMPONENT gumnut_with_mem;

    COMPONENT baudrate_gen IS
        GENERIC(M : integer := 434; N : integer := 9);
        PORT(
            clk, reset : IN  std_logic;
            tick       : OUT std_logic
        );
    END COMPONENT baudrate_gen;

    COMPONENT uart_tx IS
        PORT(
            clk, reset   : IN  std_logic;
            tx_start     : IN  std_logic;
            s_tick       : IN  std_logic;
            d_in         : IN  std_logic_vector(7 downto 0);
            tx_done_tick : OUT std_logic;
            tx           : OUT std_logic
        );
    END COMPONENT uart_tx;

    COMPONENT uart_rx IS
        PORT(
            clk          : IN  std_logic;
            reset        : IN  std_logic;
            s_tick       : IN  std_logic;
            rx           : IN  std_logic;
            rx_done_tick : OUT std_logic;
            d_out        : OUT std_logic_vector(7 downto 0)
        );
    END COMPONENT uart_rx;

    COMPONENT adc_ctrl IS
        PORT (
            clk      : IN  std_logic;
            reset_n  : IN  std_logic;
            ch4_data : OUT std_logic_vector(11 DOWNTO 0);
            ch5_data : OUT std_logic_vector(11 DOWNTO 0);
            valid    : OUT std_logic
        );
    END COMPONENT adc_ctrl;

    SIGNAL rst_i       : std_logic := '1';
    SIGNAL por_count   : unsigned(7 downto 0) := (others => '0');
    SIGNAL port_cyc_o  : std_logic;
    SIGNAL port_stb_o  : std_logic;
    SIGNAL port_we_o   : std_logic;
    SIGNAL port_ack_i  : std_logic;
    SIGNAL port_adr_o  : unsigned(7 downto 0);
    SIGNAL port_dat_o  : std_logic_vector(7 downto 0);
    SIGNAL port_dat_i  : std_logic_vector(7 downto 0);
    SIGNAL int_req     : std_logic;
    SIGNAL s_tick      : std_logic;
    SIGNAL s_tick_rx   : std_logic;
    SIGNAL tx_start    : std_logic;
    SIGNAL tx_data     : std_logic_vector(7 downto 0);
    SIGNAL tx_done     : std_logic;
    SIGNAL uart_ready  : std_logic;
    SIGNAL rx_done     : std_logic;
    SIGNAL rx_data     : std_logic_vector(7 downto 0);
    SIGNAL score_reg   : std_logic_vector(7 downto 0) := (others => '0');
    SIGNAL mux_cnt     : unsigned(15 downto 0) := (others => '0');
    SIGNAL rst_n       : std_logic;
    SIGNAL adc_ch4     : std_logic_vector(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL adc_ch5     : std_logic_vector(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL adc_valid   : std_logic;
    SIGNAL sw_virtual  : std_logic_vector(3 DOWNTO 0);

    -- Funcion BCD a 7 segmentos (activo bajo)
    -- segmentos: gfedcba
    FUNCTION bcd_to_7seg(bcd : std_logic_vector(3 downto 0))
             RETURN std_logic_vector IS
        VARIABLE seg : std_logic_vector(6 downto 0);
    BEGIN
        CASE bcd IS
            WHEN "0000" => seg := "0111111"; -- 0
            WHEN "0001" => seg := "0000110"; -- 1
            WHEN "0010" => seg := "1011011"; -- 2
            WHEN "0011" => seg := "1001111"; -- 3
            WHEN "0100" => seg := "1100110"; -- 4
            WHEN "0101" => seg := "1101101"; -- 5
            WHEN "0110" => seg := "1111101"; -- 6
            WHEN "0111" => seg := "0000111"; -- 7
            WHEN "1000" => seg := "1111111"; -- 8
            WHEN "1001" => seg := "1101111"; -- 9
            WHEN OTHERS => seg := "0000000"; -- apagado
        END CASE;
        RETURN seg;
    END FUNCTION;

BEGIN

    int_req <= '0';
    rst_n   <= NOT rst_i;

    PROCESS(CLOCK_50)
    BEGIN
        IF rising_edge(CLOCK_50) THEN
            IF por_count < 255 THEN
                por_count <= por_count + 1;
                rst_i     <= '1';
            ELSE
                rst_i     <= '0';
            END IF;
        END IF;
    END PROCESS;

    gumnut_inst : COMPONENT gumnut_with_mem
        PORT MAP(
            clk_i      => CLOCK_50,
            rst_i      => rst_i,
            port_cyc_o => port_cyc_o,
            port_stb_o => port_stb_o,
            port_we_o  => port_we_o,
            port_ack_i => port_ack_i,
            port_adr_o => port_adr_o,
            port_dat_o => port_dat_o,
            port_dat_i => port_dat_i,
            int_req    => int_req,
            int_ack    => open
        );

    baud_inst : COMPONENT baudrate_gen
        GENERIC MAP(M => 434, N => 9)
        PORT MAP(
            clk   => CLOCK_50,
            reset => rst_i,
            tick  => s_tick
        );

    -- baudrate 16x para uart_rx: 50MHz / (115200*16) = 27 ciclos
    baud_rx_inst : COMPONENT baudrate_gen
        GENERIC MAP(M => 27, N => 5)
        PORT MAP(
            clk   => CLOCK_50,
            reset => rst_i,
            tick  => s_tick_rx
        );

    uart_tx_inst : COMPONENT uart_tx
        PORT MAP(
            clk          => CLOCK_50,
            reset        => rst_i,
            tx_start     => tx_start,
            s_tick       => s_tick,
            d_in         => tx_data,
            tx_done_tick => tx_done,
            tx           => GPIO_TX
        );

    uart_rx_inst : COMPONENT uart_rx
        PORT MAP(
            clk          => CLOCK_50,
            reset        => rst_i,
            s_tick       => s_tick_rx,
            rx           => GPIO_RX,
            rx_done_tick => rx_done,
            d_out        => rx_data
        );

    port_ack_i <= port_cyc_o AND port_stb_o;

    -- Guardar puntaje recibido por UART RX
    PROCESS(CLOCK_50, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            score_reg <= (OTHERS => '0');
        ELSIF rising_edge(CLOCK_50) THEN
            IF rx_done = '1' THEN
                score_reg <= rx_data;
            END IF;
        END IF;
    END PROCESS;

    -- Contador para multiplexeo (~760 Hz por digito a 50 MHz)
    PROCESS(CLOCK_50)
    BEGIN
        IF rising_edge(CLOCK_50) THEN
            mux_cnt <= mux_cnt + 1;
        END IF;
    END PROCESS;

    -- Multiplexar digitos en bus compartido; transistor HIGH = encendido
    HEX_BUS  <= bcd_to_7seg(score_reg(3 DOWNTO 0)) WHEN mux_cnt(15) = '0' ELSE
                 bcd_to_7seg(score_reg(7 DOWNTO 4));
    DISP_SEL <= "01" WHEN mux_cnt(15) = '0' ELSE "10";

    adc_inst : adc_ctrl
        PORT MAP (
            clk      => CLOCK_50,
            reset_n  => rst_n,
            ch4_data => adc_ch4,
            ch5_data => adc_ch5,
            valid    => adc_valid
        );

    -- Umbral: divide rango 0-4095 en 4 cuadrantes de 1024
    -- ADC_IN4 -> SW1, SW0  |  ADC_IN5 -> SW3, SW2
    sw_virtual(1 DOWNTO 0) <= "00" WHEN unsigned(adc_ch4) >= x"600" ELSE
                               "00" WHEN unsigned(adc_ch4) >= x"010" ELSE
                               "00" WHEN unsigned(adc_ch4) >= x"100" ELSE
                               "00";
    sw_virtual(3 DOWNTO 2) <= "10" WHEN unsigned(adc_ch5) >= x"C00" ELSE
                               "10" WHEN unsigned(adc_ch5) >= x"700" ELSE
                               "00" WHEN unsigned(adc_ch5) >= x"500" ELSE
                               "01";

    PROCESS(CLOCK_50, rst_i)
    BEGIN
        IF rst_i = '1' THEN
            uart_ready <= '1';
            tx_start   <= '0';
            tx_data    <= (OTHERS => '0');
            LEDR       <= (OTHERS => '0');

        ELSIF rising_edge(CLOCK_50) THEN
            tx_start <= '0';

            IF port_cyc_o = '1' AND port_stb_o = '1' AND port_we_o = '1' THEN
                CASE to_integer(port_adr_o) IS

                    WHEN 16#00# =>
                        LEDR(7 DOWNTO 0) <= port_dat_o;
                        LEDR(9 DOWNTO 8) <= (OTHERS => '0');

                    WHEN 16#05# =>
                        tx_data    <= port_dat_o;
                        tx_start   <= '1';
                        uart_ready <= '0';

                    WHEN OTHERS => NULL;

                END CASE;
            END IF;

            IF tx_done = '1' THEN
                uart_ready <= '1';
            END IF;

        END IF;
    END PROCESS;

    PROCESS(port_cyc_o, port_stb_o, port_we_o, port_adr_o, KEY, uart_ready, sw_virtual, adc_ch4, adc_ch5)
    BEGIN
        port_dat_i <= (OTHERS => '0');

        IF port_cyc_o = '1' AND port_stb_o = '1' AND port_we_o = '0' THEN
            CASE to_integer(port_adr_o) IS

                WHEN 16#02# =>
                    port_dat_i <= "000000" & KEY(1) & KEY(0);

                WHEN 16#03# =>
                    port_dat_i <= "0000" & sw_virtual;

                WHEN 16#04# =>
                    port_dat_i <= "0000000" & uart_ready;

                WHEN 16#06# =>
                    port_dat_i <= adc_ch4(11 DOWNTO 4);

                WHEN 16#07# =>
                    port_dat_i <= adc_ch5(11 DOWNTO 4);

                WHEN OTHERS =>
                    port_dat_i <= (OTHERS => '0');

            END CASE;
        END IF;
    END PROCESS;

END Structural;
