-- adc_ctrl.vhd
-- Lee canales 4 (VRY) y 5 (VRX) del ADC MAX10
-- ADC 12 bits, referencia 3.3V:
--   0.5V -> 620    (threshold bajo)
--   3.0V -> 3723   (threshold alto)
--
-- joy_out bits: 3=W  2=S  1=A  0=D
-- VRY: canal 4  -> W/S   VRX: canal 5  -> A/D

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity adc_ctrl is
    port(
        clk          : in  std_logic;
        reset        : in  std_logic;
        -- interfaz del ADC IP (Modular ADC Core)
        adc_data     : in  std_logic_vector(11 downto 0);
        adc_valid    : in  std_logic;
        adc_channel  : in  std_logic_vector(4 downto 0);
        -- salida de direcciones
        joy_out      : out std_logic_vector(3 downto 0)
    );
end adc_ctrl;

architecture rtl of adc_ctrl is

    -- Referencia interna 2.5V, ADC 12 bits
    -- 0.5V = (0.5/2.5)*4095 = 819
    -- 2.0V = (2.0/2.5)*4095 = 3276  (joystick empujado al maximo ~3.3V clipea a 4095)
    -- Joystick VCC=3.3V, ref ADC interna 2.5V
    -- Reposo: 1.97V -> ADC 3228
    -- Min:    ~0V   -> ADC 0
    -- Max:    3.34V -> ADC 4095 (clipea, > referencia)
    -- Zona muerta: 1500 < 3228 < 3700
    constant THR_LO : unsigned(11 downto 0) := to_unsigned(1500, 12);
    constant THR_HI : unsigned(11 downto 0) := to_unsigned(3700, 12);

    signal vrx_val  : unsigned(11 downto 0) := to_unsigned(2048, 12);
    signal vry_val  : unsigned(11 downto 0) := to_unsigned(2048, 12);

begin

    -- Captura el valor de cada canal cuando llega dato valido
    process(clk, reset)
    begin
        if reset = '1' then
            vrx_val <= to_unsigned(2048, 12);
            vry_val <= to_unsigned(2048, 12);
        elsif rising_edge(clk) then
            if adc_valid = '1' then
                if unsigned(adc_channel) = 5 then
                    vrx_val <= unsigned(adc_data);
                elsif unsigned(adc_channel) = 4 then
                    vry_val <= unsigned(adc_data);
                end if;
            end if;
        end if;
    end process;

    -- Comparacion con thresholds
    -- VRY canal4: < 0.5V -> W(bit3),  > 3.0V -> S(bit2)  [invertido]
    -- VRX canal5: > 3.0V -> A(bit1),  < 0.5V -> D(bit0)  [invertido]
    joy_out(3) <= '1' when vry_val < THR_LO else '0';  -- W
    joy_out(2) <= '1' when vry_val > THR_HI else '0';  -- S
    joy_out(1) <= '1' when vrx_val > THR_HI else '0';  -- A
    joy_out(0) <= '1' when vrx_val < THR_LO else '0';  -- D

end rtl;
