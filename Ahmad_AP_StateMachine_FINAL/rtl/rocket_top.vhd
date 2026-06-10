-- rocket_top.vhd
-- AquaSonic Avionics - WP5 State Machine Rocket
-- Ahmad & Tasnim
--
-- Top-Level: verdrahtet uart_rx -> frame_aligner -> trigger_logic -> FSM.
-- Operator-Kommandos und critical_fault werden von aussen reingereicht.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.aquasonic_pkg.all;

entity rocket_top is
    port (
        clk                      : in  std_logic;
        reset                    : in  std_logic;

        uart_rx_line             : in  std_logic;

        start_fueling            : in  std_logic;
        fueling_complete         : in  std_logic;
        arm_cmd                  : in  std_logic;
        disarm_cmd               : in  std_logic;
        override_cmd             : in  std_logic;
        restart_sequence         : in  std_logic;
        init_done                : in  std_logic;
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
        logging_enable           : out std_logic;

        dbg_frame_drop           : out std_logic;
        dbg_uart_ferr            : out std_logic
    );
end entity rocket_top;


architecture structural of rocket_top is

    signal s_byte         : std_logic_vector(7 downto 0);
    signal s_byte_valid   : std_logic;
    signal s_uart_ferr    : std_logic;

    signal s_acc_x        : std_logic_vector(15 downto 0);
    signal s_acc_y        : std_logic_vector(15 downto 0);
    signal s_acc_z        : std_logic_vector(15 downto 0);
    signal s_baro_h       : std_logic_vector(15 downto 0);
    signal s_chamber_p    : std_logic_vector(15 downto 0);
    signal s_tank_p       : std_logic_vector(15 downto 0);
    signal s_sample_valid : std_logic;
    signal s_frame_drop   : std_logic;

    signal s_liftoff_detected         : std_logic;
    signal s_engine_burnout_detected  : std_logic;
    signal s_apogee_detected          : std_logic;
    signal s_target_altitude_detected : std_logic;
    signal s_stable_altitude_detected : std_logic;

begin

    U_UART : entity work.uart_rx
        port map (
            clk        => clk,
            reset      => reset,
            rx         => uart_rx_line,
            byte_out   => s_byte,
            byte_valid => s_byte_valid,
            frame_err  => s_uart_ferr
        );

    U_ALIGN : entity work.frame_aligner
        port map (
            clk          => clk,
            reset        => reset,
            byte_in      => s_byte,
            byte_valid   => s_byte_valid,
            imu1_acc_x   => s_acc_x,
            imu1_acc_y   => s_acc_y,
            imu1_acc_z   => s_acc_z,
            baro1_height => s_baro_h,
            chamber_pres => s_chamber_p,
            tank_pres    => s_tank_p,
            sample_valid => s_sample_valid,
            frame_drop   => s_frame_drop
        );

    U_TRIG : entity work.trigger_logic
        port map (
            clk                      => clk,
            reset                    => reset,
            sample_valid             => s_sample_valid,
            imu1_acc_x               => s_acc_x,
            imu1_acc_y               => s_acc_y,
            imu1_acc_z               => s_acc_z,
            baro1_height             => s_baro_h,
            liftoff_detected         => s_liftoff_detected,
            engine_burnout_detected  => s_engine_burnout_detected,
            apogee_detected          => s_apogee_detected,
            target_altitude_detected => s_target_altitude_detected,
            stable_altitude_detected => s_stable_altitude_detected
        );

    U_FSM : entity work.aquasonic_fsm
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
            liftoff_detected         => s_liftoff_detected,
            engine_burnout_detected  => s_engine_burnout_detected,
            apogee_detected          => s_apogee_detected,
            target_altitude_detected => s_target_altitude_detected,
            stable_altitude_detected => s_stable_altitude_detected,
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

    dbg_frame_drop <= s_frame_drop;
    dbg_uart_ferr  <= s_uart_ferr;

end architecture structural;
