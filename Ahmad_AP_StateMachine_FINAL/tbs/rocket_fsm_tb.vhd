-- rocket_fsm_tb.vhd
-- Ahmad & Tasnim
--
-- Self-checking Testbench fuer aquasonic_fsm.
-- 4 Tests: nominal full mission, disarm round-trip, override paths,
-- critical fault.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.aquasonic_pkg.all;

entity rocket_fsm_tb is
end entity rocket_fsm_tb;

architecture sim of rocket_fsm_tb is

    signal clk                      : std_logic := '0';
    signal reset                    : std_logic := '1';
    signal start_fueling            : std_logic := '0';
    signal fueling_complete         : std_logic := '0';
    signal arm_cmd                  : std_logic := '0';
    signal disarm_cmd               : std_logic := '0';
    signal override_cmd             : std_logic := '0';
    signal restart_sequence         : std_logic := '0';
    signal init_done                : std_logic := '0';
    signal liftoff_detected         : std_logic := '0';
    signal engine_burnout_detected  : std_logic := '0';
    signal apogee_detected          : std_logic := '0';
    signal target_altitude_detected : std_logic := '0';
    signal stable_altitude_detected : std_logic := '0';
    signal critical_fault           : std_logic := '0';

    signal state_code               : std_logic_vector(3 downto 0);
    signal fueling_active           : std_logic;
    signal system_pre_arm           : std_logic;
    signal system_armed             : std_logic;
    signal in_flight                : std_logic;
    signal deploy_drogue            : std_logic;
    signal deploy_main              : std_logic;
    signal landed_led               : std_logic;
    signal override_led             : std_logic;
    signal fault_led                : std_logic;
    signal telemetry_enable         : std_logic;
    signal logging_enable           : std_logic;

    constant CLK_PERIOD : time := 10 ns;
    signal   sim_done   : boolean := false;

begin

    DUT : entity work.aquasonic_fsm
        port map (
            clk                      => clk,
            reset                    => reset,
            start_fueling            => start_fueling,
            fueling_complete         => fueling_complete,
            arm_cmd                  => arm_cmd,
            disarm_cmd               => disarm_cmd,
            override_cmd             => override_cmd,
            restart_sequence         => restart_sequence,
            init_done                => init_done,
            liftoff_detected         => liftoff_detected,
            engine_burnout_detected  => engine_burnout_detected,
            apogee_detected          => apogee_detected,
            target_altitude_detected => target_altitude_detected,
            stable_altitude_detected => stable_altitude_detected,
            critical_fault           => critical_fault,
            state_code               => state_code,
            fueling_active           => fueling_active,
            system_pre_arm           => system_pre_arm,
            system_armed             => system_armed,
            in_flight                => in_flight,
            deploy_drogue            => deploy_drogue,
            deploy_main              => deploy_main,
            landed_led               => landed_led,
            override_led             => override_led,
            fault_led                => fault_led,
            telemetry_enable         => telemetry_enable,
            logging_enable           => logging_enable
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

        procedure pulse(signal s : out std_logic) is
        begin
            s <= '1'; wait for CLK_PERIOD;
            s <= '0'; wait for CLK_PERIOD;
        end procedure;

        procedure check_state(expected : std_logic_vector(3 downto 0);
                              msg      : string) is
        begin
            wait for CLK_PERIOD;
            assert state_code = expected
                report "[FAIL] " & msg
                     & "  expected=" & integer'image(to_integer(unsigned(expected)))
                     & "  got="      & integer'image(to_integer(unsigned(state_code)))
                severity error;
            if state_code = expected then
                report "[ OK ] " & msg severity note;
            end if;
        end procedure;

    begin
        report "==== aquasonic_fsm tb - START ====";

        reset <= '1'; wait for 4*CLK_PERIOD; reset <= '0'; wait for 2*CLK_PERIOD;
        check_state(C_STATE_INIT, "nach reset -> INIT");

        report "---- Test 1: nominal mission ----";
        pulse(init_done);                check_state(C_STATE_IDLE,    "INIT -> IDLE");
        pulse(start_fueling);            check_state(C_STATE_FUELING, "IDLE -> FUELING");
        pulse(fueling_complete);         check_state(C_STATE_PRE_ARM, "FUELING -> PRE-ARM");
        pulse(arm_cmd);                  check_state(C_STATE_ARMED,   "PRE-ARM -> ARMED");
        pulse(liftoff_detected);         check_state(C_STATE_LAUNCHED,"ARMED -> LAUNCHED");
        pulse(engine_burnout_detected);  check_state(C_STATE_CRUISE,  "LAUNCHED -> CRUISE");
        pulse(apogee_detected);          check_state(C_STATE_DROGUE,  "CRUISE -> DROGUE");
        pulse(target_altitude_detected); check_state(C_STATE_MAIN,    "DROGUE -> MAIN");
        pulse(stable_altitude_detected); check_state(C_STATE_LANDED,  "MAIN -> LANDED");

        report "---- Test 2: disarm round-trip ----";
        reset <= '1'; wait for 4*CLK_PERIOD; reset <= '0'; wait for 2*CLK_PERIOD;
        pulse(init_done);
        pulse(start_fueling);
        pulse(fueling_complete);   check_state(C_STATE_PRE_ARM, "PRE-ARM");
        pulse(arm_cmd);            check_state(C_STATE_ARMED,   "PRE-ARM -> ARMED");
        pulse(disarm_cmd);         check_state(C_STATE_PRE_ARM, "ARMED -> PRE-ARM");

        report "---- Test 3: override paths ----";
        reset <= '1'; wait for 4*CLK_PERIOD; reset <= '0'; wait for 2*CLK_PERIOD;
        pulse(init_done);
        pulse(override_cmd);       check_state(C_STATE_OVERRIDE, "IDLE -> OVERRIDE");
        pulse(restart_sequence);   check_state(C_STATE_IDLE,     "OVERRIDE -> IDLE");

        pulse(start_fueling);      check_state(C_STATE_FUELING,  "IDLE -> FUELING");
        pulse(override_cmd);       check_state(C_STATE_OVERRIDE, "FUELING -> OVERRIDE");
        pulse(restart_sequence);   check_state(C_STATE_IDLE,     "OVERRIDE -> IDLE");

        pulse(start_fueling);
        pulse(fueling_complete);   check_state(C_STATE_PRE_ARM,  "PRE-ARM");
        pulse(override_cmd);       check_state(C_STATE_OVERRIDE, "PRE-ARM -> OVERRIDE");
        pulse(restart_sequence);   check_state(C_STATE_IDLE,     "OVERRIDE -> IDLE");

        report "---- Test 4: critical fault ----";
        reset <= '1'; wait for 4*CLK_PERIOD; reset <= '0'; wait for 2*CLK_PERIOD;
        pulse(init_done);
        pulse(start_fueling);
        pulse(fueling_complete);
        pulse(arm_cmd);
        pulse(liftoff_detected);   check_state(C_STATE_LAUNCHED, "in flight");
        critical_fault <= '1'; wait for 2*CLK_PERIOD;
        check_state(C_STATE_ERROR, "fault -> ERROR");
        critical_fault <= '0'; wait for 2*CLK_PERIOD;
        check_state(C_STATE_ERROR, "ERROR terminal");

        report "==== aquasonic_fsm tb - DONE ====";
        sim_done <= true;
        wait;
    end process;

end architecture sim;
