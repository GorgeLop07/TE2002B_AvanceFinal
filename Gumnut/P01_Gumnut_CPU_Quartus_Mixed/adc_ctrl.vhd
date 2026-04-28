LIBRARY ieee;
USE ieee.std_logic_1164.all, ieee.numeric_std.all;

ENTITY adc_ctrl IS
    PORT (
        clk      : IN  std_logic;
        reset_n  : IN  std_logic;
        ch4_data : OUT std_logic_vector(11 DOWNTO 0);
        ch5_data : OUT std_logic_vector(11 DOWNTO 0);
        valid    : OUT std_logic
    );
END adc_ctrl;

ARCHITECTURE rtl OF adc_ctrl IS

    -- PLL megafunction: 50 MHz -> 10 MHz para el bloque ADC
    COMPONENT altpll IS
        GENERIC (
            clk0_divide_by         : NATURAL := 1;
            clk0_multiply_by       : NATURAL := 1;
            compensate_clock       : STRING  := "CLK0";
            inclk0_input_frequency : NATURAL := 20000;
            intended_device_family : STRING  := "MAX 10";
            lpm_type               : STRING  := "altpll";
            operation_mode         : STRING  := "NORMAL";
            port_clk0              : STRING  := "PORT_USED";
            port_inclk0            : STRING  := "PORT_USED";
            port_inclk1            : STRING  := "PORT_UNUSED";
            port_locked            : STRING  := "PORT_USED"
        );
        PORT (
            inclk  : IN  std_logic_vector(1 DOWNTO 0) := (OTHERS => '0');
            clk    : OUT std_logic_vector(4 DOWNTO 0);
            locked : OUT std_logic
        );
    END COMPONENT altpll;

    COMPONENT modular_adc_core IS
        PORT (
            clock_clk                  : IN  std_logic;
            reset_sink_reset_n         : IN  std_logic;
            adc_pll_clock_clk          : IN  std_logic;
            adc_pll_locked_export      : IN  std_logic;
            sequencer_csr_address      : IN  std_logic;
            sequencer_csr_read         : IN  std_logic;
            sequencer_csr_write        : IN  std_logic;
            sequencer_csr_writedata    : IN  std_logic_vector(31 DOWNTO 0);
            sequencer_csr_readdata     : OUT std_logic_vector(31 DOWNTO 0);
            sample_store_csr_address   : IN  std_logic_vector(6 DOWNTO 0);
            sample_store_csr_read      : IN  std_logic;
            sample_store_csr_write     : IN  std_logic;
            sample_store_csr_writedata : IN  std_logic_vector(31 DOWNTO 0);
            sample_store_csr_readdata  : OUT std_logic_vector(31 DOWNTO 0);
            sample_store_irq_irq       : OUT std_logic
        );
    END COMPONENT modular_adc_core;

    CONSTANT ADDR_SLOT0 : std_logic_vector(6 DOWNTO 0) := "0000000";
    CONSTANT ADDR_SLOT1 : std_logic_vector(6 DOWNTO 0) := "0000001";
    CONSTANT ADDR_ISR   : std_logic_vector(6 DOWNTO 0) := "1000001";

    TYPE state_t IS (INIT, RUNNING, READ0, WAIT0, READ1, WAIT1, CLEAR_IRQ);
    SIGNAL state    : state_t := INIT;
    SIGNAL wait_cnt : unsigned(1 DOWNTO 0) := (OTHERS => '0');

    SIGNAL pll_clks   : std_logic_vector(4 DOWNTO 0);
    SIGNAL pll_clk    : std_logic;
    SIGNAL pll_locked : std_logic;

    SIGNAL seq_addr      : std_logic                     := '0';
    SIGNAL seq_read      : std_logic                     := '0';
    SIGNAL seq_write     : std_logic                     := '0';
    SIGNAL seq_writedata : std_logic_vector(31 DOWNTO 0) := (OTHERS => '0');

    SIGNAL ss_addr      : std_logic_vector(6 DOWNTO 0)  := (OTHERS => '0');
    SIGNAL ss_read      : std_logic                     := '0';
    SIGNAL ss_write     : std_logic                     := '0';
    SIGNAL ss_writedata : std_logic_vector(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL ss_readdata  : std_logic_vector(31 DOWNTO 0);
    SIGNAL irq          : std_logic;

BEGIN

    -- PLL: 50 MHz / 5 = 10 MHz para adc_pll_clock_clk
    pll_inst : altpll
        GENERIC MAP (
            clk0_divide_by         => 5,
            clk0_multiply_by       => 1,
            inclk0_input_frequency => 20000,
            intended_device_family => "MAX 10",
            lpm_type               => "altpll",
            operation_mode         => "NORMAL",
            port_clk0              => "PORT_USED",
            port_inclk0            => "PORT_USED",
            port_inclk1            => "PORT_UNUSED",
            port_locked            => "PORT_USED"
        )
        PORT MAP (
            inclk(0) => clk,
            inclk(1) => '0',
            clk      => pll_clks,
            locked   => pll_locked
        );

    pll_clk <= pll_clks(0);

    adc_inst : modular_adc_core
        PORT MAP (
            clock_clk                  => clk,
            reset_sink_reset_n         => reset_n,
            adc_pll_clock_clk          => pll_clk,
            adc_pll_locked_export      => pll_locked,
            sequencer_csr_address      => seq_addr,
            sequencer_csr_read         => seq_read,
            sequencer_csr_write        => seq_write,
            sequencer_csr_writedata    => seq_writedata,
            sequencer_csr_readdata     => OPEN,
            sample_store_csr_address   => ss_addr,
            sample_store_csr_read      => ss_read,
            sample_store_csr_write     => ss_write,
            sample_store_csr_writedata => ss_writedata,
            sample_store_csr_readdata  => ss_readdata,
            sample_store_irq_irq       => irq
        );

    PROCESS(clk, reset_n)
    BEGIN
        IF reset_n = '0' THEN
            state         <= INIT;
            wait_cnt      <= (OTHERS => '0');
            seq_addr      <= '0';
            seq_read      <= '0';
            seq_write     <= '0';
            seq_writedata <= (OTHERS => '0');
            ss_addr       <= (OTHERS => '0');
            ss_read       <= '0';
            ss_write      <= '0';
            ss_writedata  <= (OTHERS => '0');
            ch4_data      <= (OTHERS => '0');
            ch5_data      <= (OTHERS => '0');
            valid         <= '0';

        ELSIF rising_edge(clk) THEN
            seq_read  <= '0';
            seq_write <= '0';
            ss_read   <= '0';
            ss_write  <= '0';
            valid     <= '0';

            CASE state IS

                WHEN INIT =>
                    seq_addr      <= '0';
                    seq_write     <= '1';
                    seq_writedata <= x"00000001"; -- RUN=1, modo continuo
                    state         <= RUNNING;

                WHEN RUNNING =>
                    IF irq = '1' THEN
                        state <= READ0;
                    END IF;

                WHEN READ0 =>
                    ss_addr  <= ADDR_SLOT0;
                    ss_read  <= '1';
                    wait_cnt <= (OTHERS => '0');
                    state    <= WAIT0;

                -- Latencia: 1 ciclo (addr_reg RAM) + 1 ciclo (readdata reg) = 2 ciclos
                WHEN WAIT0 =>
                    IF wait_cnt = 2 THEN
                        ch4_data <= ss_readdata(11 DOWNTO 0);
                        state    <= READ1;
                    ELSE
                        wait_cnt <= wait_cnt + 1;
                    END IF;

                WHEN READ1 =>
                    ss_addr  <= ADDR_SLOT1;
                    ss_read  <= '1';
                    wait_cnt <= (OTHERS => '0');
                    state    <= WAIT1;

                WHEN WAIT1 =>
                    IF wait_cnt = 2 THEN
                        ch5_data <= ss_readdata(11 DOWNTO 0);
                        state    <= CLEAR_IRQ;
                    ELSE
                        wait_cnt <= wait_cnt + 1;
                    END IF;

                WHEN CLEAR_IRQ =>
                    ss_addr      <= ADDR_ISR;
                    ss_write     <= '1';
                    ss_writedata <= x"00000001";
                    valid        <= '1';
                    state        <= RUNNING;

            END CASE;
        END IF;
    END PROCESS;

END rtl;
