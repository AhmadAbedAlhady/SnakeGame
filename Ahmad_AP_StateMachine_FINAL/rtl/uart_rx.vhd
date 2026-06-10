-- uart_rx.vhd
-- AquaSonic Avionics - WP5 State Machine Rocket
-- Ahmad & Tasnim
--
-- Standard 8N1 UART-Empfaenger.
-- Baudrate / CLKS_PER_BIT kommen aus aquasonic_pkg.
-- Sampled in der Bit-Mitte. byte_valid ist ein 1-Takt-Puls.
-- frame_err pulst falls das Stop-Bit falsch war.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.aquasonic_pkg.all;

entity uart_rx is
    port (
        clk        : in  std_logic;
        reset      : in  std_logic;

        rx         : in  std_logic;

        byte_out   : out std_logic_vector(7 downto 0);
        byte_valid : out std_logic;
        frame_err  : out std_logic
    );
end entity uart_rx;


architecture rtl of uart_rx is

    constant CLKS_PER_BIT : integer := C_UART_CLKS_PER_BIT;
    constant HALF_BIT     : integer := CLKS_PER_BIT / 2;

    type rx_state_t is (S_IDLE, S_START, S_DATA, S_STOP);
    signal state    : rx_state_t := S_IDLE;

    signal clk_cnt  : integer range 0 to CLKS_PER_BIT-1 := 0;
    signal bit_idx  : integer range 0 to 7              := 0;
    signal shift    : std_logic_vector(7 downto 0)      := (others => '0');

    -- 2-FF Synchronisierer fuer den asynchronen RX-Eingang
    signal rx_meta  : std_logic := '1';
    signal rx_sync  : std_logic := '1';

begin

    sync_proc : process(clk, reset)
    begin
        if reset = '1' then
            rx_meta <= '1';
            rx_sync <= '1';
        elsif rising_edge(clk) then
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end if;
    end process;

    rx_proc : process(clk, reset)
    begin
        if reset = '1' then
            state      <= S_IDLE;
            clk_cnt    <= 0;
            bit_idx    <= 0;
            shift      <= (others => '0');
            byte_out   <= (others => '0');
            byte_valid <= '0';
            frame_err  <= '0';

        elsif rising_edge(clk) then
            byte_valid <= '0';
            frame_err  <= '0';

            case state is

                when S_IDLE =>
                    clk_cnt <= 0;
                    bit_idx <= 0;
                    if rx_sync = '0' then
                        state <= S_START;
                    end if;

                when S_START =>
                    -- Start-Bit in der Mitte nochmal pruefen (Glitch-Schutz)
                    if clk_cnt = HALF_BIT then
                        if rx_sync = '0' then
                            clk_cnt <= 0;
                            state   <= S_DATA;
                        else
                            state <= S_IDLE;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when S_DATA =>
                    if clk_cnt = CLKS_PER_BIT - 1 then
                        clk_cnt <= 0;
                        shift(bit_idx) <= rx_sync;
                        if bit_idx = 7 then
                            state <= S_STOP;
                        else
                            bit_idx <= bit_idx + 1;
                        end if;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

                when S_STOP =>
                    if clk_cnt = CLKS_PER_BIT - 1 then
                        clk_cnt    <= 0;
                        byte_out   <= shift;
                        byte_valid <= '1';
                        if rx_sync /= '1' then
                            frame_err <= '1';
                        end if;
                        state <= S_IDLE;
                    else
                        clk_cnt <= clk_cnt + 1;
                    end if;

            end case;
        end if;
    end process;

end architecture rtl;
