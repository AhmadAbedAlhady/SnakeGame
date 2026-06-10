-- trigger_logic_tb.vhd
-- Ahmad & Tasnim
--
-- Self-checking Testbench fuer trigger_logic.
-- Faehrt 5 Phasen: ground, liftoff, burnout, apogee, main+land.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.aquasonic_pkg.all;

entity trigger_logic_tb is
end entity trigger_logic_tb;

architecture sim of trigger_logic_tb is

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';

    signal sample_valid : std_logic := '0';
    signal acc_x        : std_logic_vector(15 downto 0) := (others => '0');
    signal acc_y        : std_logic_vector(15 downto 0) := (others => '0');
    signal acc_z        : std_logic_vector(15 downto 0) := (others => '0');
    signal baro_h       : std_logic_vector(15 downto 0) := (others => '0');

    signal liftoff_detected         : std_logic;
    signal engine_burnout_detected  : std_logic;
    signal apogee_detected          : std_logic;
    signal target_altitude_detected : std_logic;
    signal stable_altitude_detected : std_logic;

    constant CLK_PERIOD : time := 10 ns;
    signal sim_done : boolean := false;

    procedure set_inputs(signal ax, ay, az, bh : out std_logic_vector(15 downto 0);
                        ix, iy, iz, ih : integer) is
    begin
        ax <= std_logic_vector(to_signed(ix, 16));
        ay <= std_logic_vector(to_signed(iy, 16));
        az <= std_logic_vector(to_signed(iz, 16));
        bh <= std_logic_vector(to_unsigned(ih, 16));
    end procedure;

begin

    DUT : entity work.trigger_logic
        port map (
            clk                      => clk,
            reset                    => reset,
            sample_valid             => sample_valid,
            imu1_acc_x               => acc_x,
            imu1_acc_y               => acc_y,
            imu1_acc_z               => acc_z,
            baro1_height             => baro_h,
            liftoff_detected         => liftoff_detected,
            engine_burnout_detected  => engine_burnout_detected,
            apogee_detected          => apogee_detected,
            target_altitude_detected => target_altitude_detected,
            stable_altitude_detected => stable_altitude_detected
        );

    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    stim : process

        procedure drive_sample(ix, iy, iz, ih : integer) is
        begin
            set_inputs(acc_x, acc_y, acc_z, baro_h, ix, iy, iz, ih);
            wait for CLK_PERIOD;
            sample_valid <= '1';
            wait for CLK_PERIOD;
            sample_valid <= '0';
            wait for CLK_PERIOD;
        end procedure;

        procedure expect_high(sig : std_logic; msg : string) is
        begin
            assert sig = '1' report "[FAIL] " & msg severity error;
            if sig = '1' then
                report "[ OK ] " & msg severity note;
            end if;
        end procedure;

        procedure expect_low(sig : std_logic; msg : string) is
        begin
            assert sig = '0' report "[FAIL] " & msg severity error;
            if sig = '0' then
                report "[ OK ] " & msg severity note;
            end if;
        end procedure;

    begin
        report "==== trigger_logic tb - START ====";

        reset <= '1'; wait for 4*CLK_PERIOD; reset <= '0'; wait for 2*CLK_PERIOD;

        report "---- Phase 1: ground ----";
        for i in 0 to 4 loop
            drive_sample(100, 0, 0, 100);
        end loop;
        expect_low(liftoff_detected,        "kein liftoff");
        expect_low(engine_burnout_detected, "kein burnout");

        report "---- Phase 2: liftoff ----";
        for i in 0 to C_LIFTOFF_DEBOUNCE_N + 1 loop
            drive_sample(2000, 0, 0, 100 + i*5);
        end loop;
        expect_high(liftoff_detected, "liftoff");

        report "---- Phase 3: burnout ----";
        for i in 0 to C_BURNOUT_DEBOUNCE_N + 1 loop
            drive_sample(200, 0, 0, 200 + i*5);
        end loop;
        expect_high(engine_burnout_detected, "burnout");

        report "---- Phase 4: apogee ----";
        -- +3 statt +1: 1 Sample fuer Pipeline-Lag, 1 fuer baro-Sprung von
        -- Phase 3 zu 4, dann N+1 fuers eigentliche Feuern.
        for i in 0 to C_APOGEE_DEBOUNCE_N + 3 loop
            drive_sample(0, 0, 0, 500 - i*30);
        end loop;
        expect_high(apogee_detected, "apogee");

        report "---- Phase 5a: main parachute ----";
        for i in 0 to C_MAIN_ALT_DEBOUNCE_N + 1 loop
            drive_sample(0, 0, 0, 7000 - i*100);
        end loop;
        expect_high(target_altitude_detected, "target_altitude");

        report "---- Phase 5b: landed ----";
        -- +3 wie bei apogee (Pipeline-Lag + baro-Sprung beim Phasen-Uebergang)
        for i in 0 to C_LANDED_DEBOUNCE_N + 3 loop
            drive_sample(0, 0, 0, 100);
        end loop;
        expect_high(stable_altitude_detected, "stable_altitude");

        report "==== trigger_logic tb - DONE ====";
        sim_done <= true;
        wait;
    end process;

end architecture sim;
