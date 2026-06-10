-- rocket_top_tb.vhd
-- Ahmad & Tasnim
--
-- Integrations-Testbench fuer die Pipeline frame_aligner -> trigger_logic
-- -> aquasonic_fsm. uart_rx wird hier umgangen, Bytes werden direkt in
-- frame_aligner gefuettert (spart Sim-Zeit; uart_rx hat eigene Unit-TB
-- waere aber separat noch zu ergaenzen).
--
-- Daten kommen aus telemetry_flight.csv (echte Flugdaten-Aufzeichnung).
-- Format: 34 Spalten mit Komma getrennt, erste Zeile Header.
-- Wir lesen pro Zeile die 6 Felder die unsere Pipeline braucht:
--   imu1_acc_x  (Spalte 4)
--   imu1_acc_y  (Spalte 5)
--   imu1_acc_z  (Spalte 6)
--   baro1_height(Spalte 17)
--   tank_pres   (Spalte 20)
--   chamber_pres(Spalte 26)
-- ...packen sie an die richtige Position in einem 66-byte Frame und
-- streamen ihn Byte fuer Byte rein.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;

use work.aquasonic_pkg.all;

entity rocket_top_tb is
end entity rocket_top_tb;

architecture sim of rocket_top_tb is

    constant CLK_PERIOD : time   := 10 ns;
    -- Pfad zur CSV relativ zum sim/-Verzeichnis (wo vsim gestartet wird)
    constant CSV_PATH   : string := "../data/telemetry_flight.csv";

    signal clk          : std_logic := '0';
    signal reset        : std_logic := '1';

    -- frame_aligner Eingaenge (statt von uart_rx)
    signal byte_in      : std_logic_vector(7 downto 0) := (others => '0');
    signal byte_valid   : std_logic := '0';

    -- frame_aligner Ausgaenge / Bus zur trigger_logic
    signal s_acc_x      : std_logic_vector(15 downto 0);
    signal s_acc_y      : std_logic_vector(15 downto 0);
    signal s_acc_z      : std_logic_vector(15 downto 0);
    signal s_baro_h     : std_logic_vector(15 downto 0);
    signal s_chamber_p  : std_logic_vector(15 downto 0);
    signal s_tank_p     : std_logic_vector(15 downto 0);
    signal sample_valid : std_logic;
    signal frame_drop   : std_logic;

    -- trigger_logic -> FSM
    signal s_liftoff_detected         : std_logic;
    signal s_engine_burnout_detected  : std_logic;
    signal s_apogee_detected          : std_logic;
    signal s_target_altitude_detected : std_logic;
    signal s_stable_altitude_detected : std_logic;

    -- Operator-Kommandos (manuell aus diesem TB)
    signal init_done        : std_logic := '0';
    signal start_fueling    : std_logic := '0';
    signal fueling_complete : std_logic := '0';
    signal arm_cmd          : std_logic := '0';
    signal disarm_cmd       : std_logic := '0';
    signal override_cmd     : std_logic := '0';
    signal restart_sequence : std_logic := '0';
    signal critical_fault   : std_logic := '0';

    -- FSM-Outputs
    signal state_code       : std_logic_vector(3 downto 0);
    signal fueling_active   : std_logic;
    signal system_pre_arm   : std_logic;
    signal system_armed     : std_logic;
    signal in_flight        : std_logic;
    signal deploy_drogue    : std_logic;
    signal deploy_main      : std_logic;
    signal landed_led       : std_logic;
    signal override_led     : std_logic;
    signal fault_led        : std_logic;
    signal telemetry_enable : std_logic;
    signal logging_enable   : std_logic;

    signal sim_done   : boolean := false;
    signal frames_in  : integer := 0;     -- Anzahl gesendeter Frames (Debug)

begin

    -- Pipeline: frame_aligner -> trigger_logic -> aquasonic_fsm
    U_ALIGN : entity work.frame_aligner
        port map (
            clk          => clk,
            reset        => reset,
            byte_in      => byte_in,
            byte_valid   => byte_valid,
            imu1_acc_x   => s_acc_x,
            imu1_acc_y   => s_acc_y,
            imu1_acc_z   => s_acc_z,
            baro1_height => s_baro_h,
            chamber_pres => s_chamber_p,
            tank_pres    => s_tank_p,
            sample_valid => sample_valid,
            frame_drop   => frame_drop
        );

    U_TRIG : entity work.trigger_logic
        port map (
            clk                      => clk,
            reset                    => reset,
            sample_valid             => sample_valid,
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

    -- Clock-Generator
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0'; wait for CLK_PERIOD/2;
            clk <= '1'; wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    -- State-Monitor: gibt jeden State-Wechsel als Klartext aus
    monitor : process(state_code)
    begin
        case to_integer(unsigned(state_code)) is
            when 12     => report "STATE -> INIT";
            when  1     => report "STATE -> IDLE";
            when  2     => report "STATE -> FUELING";
            when  3     => report "STATE -> PRE_ARM";
            when  5     => report "STATE -> ARMED";
            when  6     => report "STATE -> LAUNCHED";
            when  7     => report "STATE -> CRUISE";
            when  8     => report "STATE -> DROGUE";
            when  9     => report "STATE -> MAIN";
            when 11     => report "STATE -> LANDED";
            when 10     => report "STATE -> OVERRIDE";
            when  0     => report "STATE -> ERROR";
            when others => null;
        end case;
    end process;

    -- Haupt-Stimulus
    stim : process

        file     f_csv  : text;
        variable L      : line;
        variable v      : integer;
        variable c      : character;
        variable good   : boolean;
        variable fstat  : file_open_status;

        -- Die 6 Sensor-Felder pro Zeile
        variable acc_x      : integer := 0;
        variable acc_y      : integer := 0;
        variable acc_z      : integer := 0;
        variable baro_h     : integer := 0;
        variable tank_p     : integer := 0;
        variable chamber_p  : integer := 0;

        -- Frame-Puffer
        type byte_array_t is array (0 to C_FRAME_BYTES-1) of integer range 0 to 255;
        variable frame : byte_array_t := (others => 0);

        -- Ein Byte in frame_aligner schieben
        procedure send_byte(b : integer) is
        begin
            byte_in    <= std_logic_vector(to_unsigned(b mod 256, 8));
            byte_valid <= '1';
            wait for CLK_PERIOD;
            byte_valid <= '0';
            wait for CLK_PERIOD;
        end procedure;

        -- Signed-16-Bit-Wert little-endian in den Frame schreiben
        procedure put16(off : integer; val : integer) is
            variable u : integer;
        begin
            -- Negative Werte als Two's-Complement in 16 bit
            if val < 0 then
                u := val + 65536;
            else
                u := val;
            end if;
            frame(off)     := u mod 256;
            frame(off + 1) := (u / 256) mod 256;
        end procedure;

        -- Kommas in der CSV-Zeile ueberspringen
        procedure skip_comma is
        begin
            if L'length > 0 then
                read(L, c, good);
            end if;
        end procedure;

        procedure pulse(signal s : out std_logic) is
        begin
            s <= '1'; wait for 4*CLK_PERIOD;
            s <= '0'; wait for 4*CLK_PERIOD;
        end procedure;

        variable line_no : integer := 0;

    begin
        report "==== rocket_top_tb - START ====";

        ----------------------------------------------------------------
        -- 1) Reset
        ----------------------------------------------------------------
        reset <= '1'; wait for 4*CLK_PERIOD;
        reset <= '0'; wait for 4*CLK_PERIOD;

        ----------------------------------------------------------------
        -- 2) Manuelle Sequenz bis ARMED
        --    (Init/Fueling/Arm sind in der Realitaet Operator-getrieben)
        ----------------------------------------------------------------
        pulse(init_done);
        pulse(start_fueling);
        pulse(fueling_complete);
        pulse(arm_cmd);

        report "Pipeline armiert - starte CSV-Stream";

        ----------------------------------------------------------------
        -- 3) CSV oeffnen und Frames streamen
        ----------------------------------------------------------------
        file_open(fstat, f_csv, CSV_PATH, read_mode);
        if fstat /= open_ok then
            report "Konnte CSV nicht oeffnen: " & CSV_PATH severity failure;
        end if;

        -- Header-Zeile ueberspringen
        readline(f_csv, L);

        while not endfile(f_csv) loop
            readline(f_csv, L);
            line_no := line_no + 1;

            -- 34 Integer pro Zeile lesen, nur die Spalten merken die wir brauchen.
            -- Zaehlung 0-basiert: 3=acc_x, 4=acc_y, 5=acc_z, 16=baro_h,
            --                     19=tank_p, 25=chamber_p
            for i in 0 to 33 loop
                read(L, v, good);
                exit when not good;
                case i is
                    when  3 => acc_x     := v;
                    when  4 => acc_y     := v;
                    when  5 => acc_z     := v;
                    when 16 => baro_h    := v;
                    when 19 => tank_p    := v;
                    when 25 => chamber_p := v;
                    when others => null;
                end case;
                if i < 33 then
                    skip_comma;
                end if;
            end loop;

            -- Frame zusammenbauen (Bytes ausserhalb der Sensor-Felder = 0)
            frame := (others => 0);
            put16(C_OFF_IMU1_ACC_X,   acc_x);
            put16(C_OFF_IMU1_ACC_Y,   acc_y);
            put16(C_OFF_IMU1_ACC_Z,   acc_z);
            put16(C_OFF_BARO1_HEIGHT, baro_h);
            put16(C_OFF_CHAMBER_PRES, chamber_p);
            put16(C_OFF_TANK_PRES,    tank_p);

            -- 66 Bytes Back-to-Back an frame_aligner schicken.
            -- Kein Idle dazwischen -> frame_aligner pulst sample_valid bei
            -- byte 65, naechster Frame startet sofort.
            for b in 0 to C_FRAME_BYTES - 1 loop
                send_byte(frame(b));
            end loop;

            frames_in <= line_no;

            -- Optionales Frueh-Ende: sobald gelandet, koennen wir aufhoeren
            exit when state_code = C_STATE_LANDED;
        end loop;

        file_close(f_csv);

        report "CSV durchgespielt - " & integer'image(line_no) & " Frames gesendet";
        report "Letzter State-Code = " & integer'image(to_integer(unsigned(state_code)));

        wait for 100*CLK_PERIOD;

        report "==== rocket_top_tb - DONE ====";
        sim_done <= true;
        wait;
    end process stim;

end architecture sim;
