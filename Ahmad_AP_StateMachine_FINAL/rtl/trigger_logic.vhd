-- trigger_logic.vhd
-- AquaSonic Avionics - WP5 State Machine Rocket
-- Ahmad & Tasnim
--
-- Wandelt rohe Sensor-Werte (ein Frame pro sample_valid-Puls) in die
-- diskreten Trigger-Signale fuer die FSM um. Jeder Trigger hat einen
-- eigenen Debounce-Zaehler und einen Latch - sobald gefeuert bleibt er
-- high bis zum Reset. Schwellwerte stehen alle im aquasonic_pkg.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.aquasonic_pkg.all;

entity trigger_logic is
    port (
        clk                      : in  std_logic;
        reset                    : in  std_logic;

        sample_valid             : in  std_logic;

        imu1_acc_x               : in  std_logic_vector(15 downto 0);
        imu1_acc_y               : in  std_logic_vector(15 downto 0);
        imu1_acc_z               : in  std_logic_vector(15 downto 0);
        baro1_height             : in  std_logic_vector(15 downto 0);

        liftoff_detected         : out std_logic;
        engine_burnout_detected  : out std_logic;
        apogee_detected          : out std_logic;
        target_altitude_detected : out std_logic;
        stable_altitude_detected : out std_logic
    );
end entity trigger_logic;


architecture behavioral of trigger_logic is

    subtype acc_sq_t is signed(31 downto 0);
    subtype dh_t     is signed(17 downto 0);

    signal prev_height : signed(16 downto 0) := (others => '0');
    signal dh          : dh_t := (others => '0');
    signal acc_sq_sum  : acc_sq_t := (others => '0');

    signal cnt_liftoff  : integer range 0 to 1023 := 0;
    signal cnt_burnout  : integer range 0 to 1023 := 0;
    signal cnt_apogee   : integer range 0 to 1023 := 0;
    signal cnt_main_alt : integer range 0 to 1023 := 0;
    signal cnt_landed   : integer range 0 to 1023 := 0;

    signal r_liftoff   : std_logic := '0';
    signal r_burnout   : std_logic := '0';
    signal r_apogee    : std_logic := '0';
    signal r_main_alt  : std_logic := '0';
    signal r_landed    : std_logic := '0';

    -- Quadrat einer signed 16-bit Achse (1 Multiplikation -> 1 DSP)
    function sq16(x : std_logic_vector(15 downto 0)) return signed is
        variable v : signed(15 downto 0);
    begin
        v := signed(x);
        return resize(v * v, 32);
    end function;

begin

    -- |acc|^2 und dh pro frischem Sample
    process(clk, reset)
        variable h_now : signed(16 downto 0);
    begin
        if reset = '1' then
            acc_sq_sum  <= (others => '0');
            prev_height <= (others => '0');
            dh          <= (others => '0');
        elsif rising_edge(clk) then
            if sample_valid = '1' then
                acc_sq_sum <= sq16(imu1_acc_x)
                            + sq16(imu1_acc_y)
                            + sq16(imu1_acc_z);
                h_now := signed('0' & baro1_height);
                dh    <= resize(h_now - prev_height, 18);
                prev_height <= h_now;
            end if;
        end if;
    end process;

    -- Debounce + Latch pro Trigger.
    -- Sequenz: burnout erst nach liftoff, apogee erst nach burnout, etc.
    debounce_proc : process(clk, reset)
    begin
        if reset = '1' then
            cnt_liftoff  <= 0;  r_liftoff  <= '0';
            cnt_burnout  <= 0;  r_burnout  <= '0';
            cnt_apogee   <= 0;  r_apogee   <= '0';
            cnt_main_alt <= 0;  r_main_alt <= '0';
            cnt_landed   <= 0;  r_landed   <= '0';

        elsif rising_edge(clk) then
            if sample_valid = '1' then

                -- LIFTOFF
                if acc_sq_sum > to_signed(C_LIFTOFF_ACC_SQ_THR, 32) then
                    if cnt_liftoff < C_LIFTOFF_DEBOUNCE_N then
                        cnt_liftoff <= cnt_liftoff + 1;
                    else
                        r_liftoff <= '1';
                    end if;
                else
                    cnt_liftoff <= 0;
                end if;

                -- BURNOUT
                if r_liftoff = '1' then
                    if acc_sq_sum < to_signed(C_BURNOUT_ACC_SQ_THR, 32) then
                        if cnt_burnout < C_BURNOUT_DEBOUNCE_N then
                            cnt_burnout <= cnt_burnout + 1;
                        else
                            r_burnout <= '1';
                        end if;
                    else
                        cnt_burnout <= 0;
                    end if;
                end if;

                -- APOGEE
                if r_burnout = '1' then
                    if dh < to_signed(C_APOGEE_DH_RAW_THR, 18) then
                        if cnt_apogee < C_APOGEE_DEBOUNCE_N then
                            cnt_apogee <= cnt_apogee + 1;
                        else
                            r_apogee <= '1';
                        end if;
                    else
                        cnt_apogee <= 0;
                    end if;
                end if;

                -- MAIN ALT
                if r_apogee = '1' then
                    if signed('0' & baro1_height)
                       < to_signed(C_MAIN_ALT_RAW_THR, 17) then
                        if cnt_main_alt < C_MAIN_ALT_DEBOUNCE_N then
                            cnt_main_alt <= cnt_main_alt + 1;
                        else
                            r_main_alt <= '1';
                        end if;
                    else
                        cnt_main_alt <= 0;
                    end if;
                end if;

                -- LANDED
                if r_main_alt = '1' then
                    if dh > to_signed(C_LANDED_DH_RAW_THR, 18) then
                        if cnt_landed < C_LANDED_DEBOUNCE_N then
                            cnt_landed <= cnt_landed + 1;
                        else
                            r_landed <= '1';
                        end if;
                    else
                        cnt_landed <= 0;
                    end if;
                end if;

            end if;
        end if;
    end process;

    liftoff_detected         <= r_liftoff;
    engine_burnout_detected  <= r_burnout;
    apogee_detected          <= r_apogee;
    target_altitude_detected <= r_main_alt;
    stable_altitude_detected <= r_landed;

end architecture behavioral;
