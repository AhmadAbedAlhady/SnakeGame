-- rocket_fsm.vhd
-- AquaSonic Avionics - WP5 State Machine Rocket
-- Ahmad & Tasnim
--
-- Missions-FSM der Rakete. Bekommt entprellte Trigger aus trigger_logic
-- und Operator-Kommandos rein, gibt 4-Bit state_code (Telemetrie) und die
-- Aktor-/Status-Signale raus.
--
-- Drei-Prozess Pattern: state_reg, next_state_logic, state_code_enc.
-- Reset ist active-high asynchron.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.aquasonic_pkg.all;

entity aquasonic_fsm is
    port (
        clk                      : in  std_logic;
        reset                    : in  std_logic;

        -- Manuelle Operator-Kommandos
        start_fueling            : in  std_logic;
        fueling_complete         : in  std_logic;
        arm_cmd                  : in  std_logic;
        disarm_cmd               : in  std_logic;
        override_cmd             : in  std_logic;
        restart_sequence         : in  std_logic;

        -- Automatische Trigger aus trigger_logic
        init_done                : in  std_logic;
        liftoff_detected         : in  std_logic;
        engine_burnout_detected  : in  std_logic;
        apogee_detected          : in  std_logic;
        target_altitude_detected : in  std_logic;
        stable_altitude_detected : in  std_logic;

        critical_fault           : in  std_logic;

        state_code               : out std_logic_vector(3 downto 0);

        fueling_active           : out std_logic;
        system_pre_arm           : out std_logic;
        system_armed             : out std_logic;
        in_flight                : out std_logic;
        deploy_drogue            : out std_logic;
        deploy_main              : out std_logic;
        landed_led               : out std_logic;
        override_led             : out std_logic;
        fault_led                : out std_logic;
        telemetry_enable         : out std_logic;
        logging_enable           : out std_logic
    );
end entity aquasonic_fsm;


architecture behavioral of aquasonic_fsm is

    signal current_state : state_type := S_INIT;
    signal next_state    : state_type := S_INIT;

begin

    -- State Register
    state_reg : process(clk, reset)
    begin
        if reset = '1' then
            current_state <= S_INIT;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    -- Next-State Logik
    next_state_logic : process(current_state,
                               start_fueling, fueling_complete,
                               arm_cmd, disarm_cmd,
                               override_cmd, restart_sequence,
                               init_done, liftoff_detected,
                               engine_burnout_detected, apogee_detected,
                               target_altitude_detected, stable_altitude_detected,
                               critical_fault)
    begin
        next_state <= current_state;

        -- Critical-Fault hat hoechste Prioritaet (ausser INIT/ERROR selbst)
        if critical_fault = '1' and current_state /= S_ERROR
                                and current_state /= S_INIT then
            next_state <= S_ERROR;
        else
            case current_state is

                when S_INIT =>
                    if init_done = '1' then
                        next_state <= S_IDLE;
                    end if;

                when S_IDLE =>
                    if override_cmd = '1' then
                        next_state <= S_OVERRIDE;
                    elsif start_fueling = '1' then
                        next_state <= S_FUELING;
                    end if;

                when S_FUELING =>
                    if override_cmd = '1' then
                        next_state <= S_OVERRIDE;
                    elsif fueling_complete = '1' then
                        next_state <= S_PRE_ARM;
                    end if;

                when S_PRE_ARM =>
                    if override_cmd = '1' then
                        next_state <= S_OVERRIDE;
                    elsif arm_cmd = '1' then
                        next_state <= S_ARMED;
                    end if;

                when S_ARMED =>
                    if disarm_cmd = '1' then
                        next_state <= S_PRE_ARM;
                    elsif liftoff_detected = '1' then
                        next_state <= S_LAUNCHED;
                    end if;

                when S_LAUNCHED =>
                    if engine_burnout_detected = '1' then
                        next_state <= S_CRUISE;
                    end if;

                when S_CRUISE =>
                    if apogee_detected = '1' then
                        next_state <= S_DROGUE;
                    end if;

                when S_DROGUE =>
                    if target_altitude_detected = '1' then
                        next_state <= S_MAIN;
                    end if;

                when S_MAIN =>
                    if stable_altitude_detected = '1' then
                        next_state <= S_LANDED;
                    end if;

                when S_LANDED =>
                    null;

                when S_OVERRIDE =>
                    if restart_sequence = '1' then
                        next_state <= S_IDLE;
                    end if;

                when S_ERROR =>
                    null;  -- nur Reset raus

            end case;
        end if;
    end process;

    -- 4-Bit Telemetrie-Code (registriert)
    state_code_enc : process(clk, reset)
    begin
        if reset = '1' then
            state_code <= C_STATE_INIT;
        elsif rising_edge(clk) then
            state_code <= state_to_code(current_state);
        end if;
    end process;

    -- Aktor-Outputs (concurrent, jeder Output wird in jedem State getrieben)
    fueling_active <= '1' when current_state = S_FUELING  else '0';
    system_pre_arm <= '1' when current_state = S_PRE_ARM  else '0';
    system_armed   <= '1' when current_state = S_ARMED    else '0';

    in_flight <= '1' when current_state = S_LAUNCHED
                      or current_state = S_CRUISE
                      or current_state = S_DROGUE
                      or current_state = S_MAIN
                 else '0';

    deploy_drogue <= '1' when current_state = S_DROGUE   else '0';
    deploy_main   <= '1' when current_state = S_MAIN     else '0';
    landed_led    <= '1' when current_state = S_LANDED   else '0';
    override_led  <= '1' when current_state = S_OVERRIDE else '0';
    fault_led     <= '1' when current_state = S_ERROR    else '0';

    telemetry_enable <= '0' when current_state = S_INIT else '1';

    logging_enable <= '0' when current_state = S_INIT
                           or current_state = S_IDLE
                           or current_state = S_FUELING
                      else '1';

end architecture behavioral;
