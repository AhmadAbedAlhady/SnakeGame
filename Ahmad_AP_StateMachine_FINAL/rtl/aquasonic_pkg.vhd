-- aquasonic_pkg.vhd
-- AquaSonic Avionics - WP5 State Machine Rocket
-- Ahmad & Tasnim
--
-- Zentrales Package fuer State-Codes, UART-Parameter, Frame-Layout und
-- alle Trigger-Schwellwerte. Alles was sich noch aendern koennte liegt
-- hier - so muss bei Spec-Aenderungen nur eine Datei angefasst werden.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package aquasonic_pkg is

    -- Mission state codes (4 bit, laut Spec Feld 27 des Telemetrie-Pakets)
    constant C_STATE_INIT     : std_logic_vector(3 downto 0) := "1100";  -- 12 = Power-on / Selbsttest
    constant C_STATE_IDLE     : std_logic_vector(3 downto 0) := "0001";  --  1 = Wartet auf Operator-Kommando
    constant C_STATE_FUELING  : std_logic_vector(3 downto 0) := "0010";  --  2 = Betankung laeuft
    constant C_STATE_PRE_ARM  : std_logic_vector(3 downto 0) := "0011";  --  3 = Betankt, wartet auf Arm-Kommando
    constant C_STATE_ARMED    : std_logic_vector(3 downto 0) := "0101";  --  5 = Scharf, wartet auf Liftoff
    constant C_STATE_LAUNCHED : std_logic_vector(3 downto 0) := "0110";  --  6 = Motor brennt
    constant C_STATE_CRUISE   : std_logic_vector(3 downto 0) := "0111";  --  7 = Freier Flug nach Burnout
    constant C_STATE_DROGUE   : std_logic_vector(3 downto 0) := "1000";  --  8 = Drogue-Schirm raus
    constant C_STATE_MAIN     : std_logic_vector(3 downto 0) := "1001";  --  9 = Hauptschirm raus
    constant C_STATE_LANDED   : std_logic_vector(3 downto 0) := "1011";  -- 11 = Auf dem Boden
    constant C_STATE_OVERRIDE : std_logic_vector(3 downto 0) := "1010";  -- 10 = Manueller Abbruch durch Operator
    constant C_STATE_ERROR    : std_logic_vector(3 downto 0) := "0000";  --  0 = Kritischer Fehler

    -- Symbolischer Aufzaehlungstyp fuer den FSM-Zustand (im RTL einfacher
    -- lesbar als rohe 4-bit Vektoren). Wird ueber state_to_code() in den
    -- Telemetrie-Code uebersetzt.
    type state_type is (
        S_INIT, S_IDLE, S_FUELING, S_PRE_ARM, S_ARMED,
        S_LAUNCHED, S_CRUISE, S_DROGUE, S_MAIN, S_LANDED,
        S_OVERRIDE, S_ERROR
    );

    function state_to_code(s : state_type) return std_logic_vector;

    -- Takt und Sample-Rate
    constant C_CLK_FREQ_HZ      : integer := 100_000_000;  -- 100 MHz System-Takt (Trenz Z7020 Default)
    constant C_SAMPLE_RATE_HZ   : integer := 10;           -- Sensor-Frame-Rate aus Spec (10 Frames/s)
    constant C_SAMPLE_PERIOD_MS : integer := 100;          -- Daraus: 100 ms zwischen zwei Frames

    -- UART (siehe AquaBrain Datasheet: UART1 = 115200 8N1)
    constant C_UART_BAUDRATE     : integer := 115_200;     -- Bits pro Sekunde auf der Leitung
    constant C_UART_DATA_BITS    : integer := 8;           -- 8 Datenbits pro Byte
    constant C_UART_STOP_BITS    : integer := 1;           -- 1 Stoppbit (-> 8N1)
    constant C_UART_CLKS_PER_BIT : integer := C_CLK_FREQ_HZ / C_UART_BAUDRATE;
                                                           -- ~868 Clocks pro UART-Bit @ 100 MHz

    -- Telemetrie-Frame Layout
    -- Feld 0: timestamp (UInt32, 4 byte) - danach 31x UInt16 (2 byte) -> 66 byte total
    constant C_FRAME_BYTES  : integer := 66;               -- Groesse eines Telemetrie-Pakets in Bytes
    constant C_FRAME_FIELDS : integer := 32;               -- 1 Timestamp + 31 Sensorfelder

    -- Byte-Offsets der Felder die wir tatsaechlich benutzen (little-endian)
    constant C_OFF_IMU1_ACC_X   : integer :=  4;           -- IMU1 Acc X (Feld 1, byte 4-5)
    constant C_OFF_IMU1_ACC_Y   : integer :=  6;           -- IMU1 Acc Y (Feld 2, byte 6-7)
    constant C_OFF_IMU1_ACC_Z   : integer :=  8;           -- IMU1 Acc Z (Feld 3, byte 8-9)
    constant C_OFF_BARO1_HEIGHT : integer := 30;           -- Barometer 1 Hoehe (Feld 14)
    constant C_OFF_CHAMBER_PRES : integer := 48;           -- Brennkammer-Druck (Feld 23)
    constant C_OFF_TANK_PRES    : integer := 36;           -- Tank-Druck (Feld 17)
    constant C_OFF_STATE        : integer := 56;           -- 4-bit State-Code zurueck in Telemetrie (Feld 27)

    -- Frame-Sync ueber UART-Idle:
    -- 66 byte @ 115200 baud -> ~5.7 ms. Naechster Frame nach 100 ms, also
    -- ~94 ms Stille dazwischen. 10 ms Idle-Schwelle reicht fuer Frame-Sync.
    constant C_FRAME_IDLE_MS : integer := 10;              -- Idle-Dauer ab der ein neuer Frame beginnt

    -- Sensor-Skalierung (raw / FACTOR = physikalischer Wert)
    constant C_SCALE_ACC       : integer := 100;           -- raw/100 = m/s^2
    constant C_SCALE_BARO_H    : integer := 10;            -- raw/10  = m
    constant C_SCALE_CHAMBER_P : integer := 1;             -- raw     = kPa
    constant C_SCALE_TANK_P    : integer := 1;             -- raw     = kPa

    -- TRIGGER-SCHWELLWERTE
    -- Werte sind alle raw UInt16, damit im RTL keine Floats oder Divisionen
    -- noetig sind. Beschleunigungen werden quadriert verglichen (kein sqrt).

    -- Liftoff (ARMED -> LAUNCHED): |acc|^2 > (1.5g)^2
    -- 1.5g = 14.7 m/s^2 -> raw = 1470 -> raw^2 = 2_160_900
    constant C_LIFTOFF_ACC_SQ_THR : integer := 2_160_900;  -- Schwelle fuer ax^2+ay^2+az^2 (raw^2)
    constant C_LIFTOFF_DEBOUNCE_N : integer := 3;          -- N Samples in Folge bevor Trigger feuert

    -- Burnout (LAUNCHED -> CRUISE): |acc|^2 < (0.5g)^2
    -- 0.5g = 4.9 m/s^2 -> raw = 490 -> raw^2 = 240_100
    constant C_BURNOUT_ACC_SQ_THR : integer := 240_100;    -- |acc|^2 darunter -> Motor aus
    constant C_BURNOUT_DEBOUNCE_N : integer := 3;          -- N Samples Bestaetigung

    -- Apogee (CRUISE -> DROGUE): dh pro Sample < -20 (=> ~ -20 m/s)
    constant C_APOGEE_DH_RAW_THR : integer := -20;         -- Hoehenaenderung pro Sample (raw)
    constant C_APOGEE_DEBOUNCE_N : integer := 2;           -- Nur 2 Samples - Apogee ist eindeutig
    constant C_HEIGHT_NOISE_RAW  : integer := 10;          -- Hoehen-Rauschschwelle (raw, ~1 m)

    -- Main Parachute (DROGUE -> MAIN): Hoehe < 750 m -> raw = 7500
    constant C_MAIN_ALT_RAW_THR    : integer := 7500;      -- Hauptschirm-Ausloesehoehe (raw)
    constant C_MAIN_ALT_DEBOUNCE_N : integer := 2;         -- N Samples Bestaetigung

    -- Landed (MAIN -> LANDED): dh > -1 (kaum Bewegung) fuer ~3 Sekunden
    constant C_LANDED_DH_RAW_THR : integer := -1;          -- Steigrate-Obergrenze "steht still"
    constant C_LANDED_DEBOUNCE_N : integer := 30;          -- 30 Samples @ 10 Hz = 3 s

    -- Tank-Schwellen (TBD - werden vom Propulsion-Team finalisiert)
    constant C_TANK_FULL_RAW_THR  : integer := 3000;       -- Druck ab dem Tank als "voll" gilt
    constant C_TANK_EMPTY_RAW_THR : integer := 200;        -- Druck ab dem Tank als "leer" gilt

end package aquasonic_pkg;


package body aquasonic_pkg is

    function state_to_code(s : state_type) return std_logic_vector is
    begin
        case s is
            when S_INIT     => return C_STATE_INIT;
            when S_IDLE     => return C_STATE_IDLE;
            when S_FUELING  => return C_STATE_FUELING;
            when S_PRE_ARM  => return C_STATE_PRE_ARM;
            when S_ARMED    => return C_STATE_ARMED;
            when S_LAUNCHED => return C_STATE_LAUNCHED;
            when S_CRUISE   => return C_STATE_CRUISE;
            when S_DROGUE   => return C_STATE_DROGUE;
            when S_MAIN     => return C_STATE_MAIN;
            when S_LANDED   => return C_STATE_LANDED;
            when S_OVERRIDE => return C_STATE_OVERRIDE;
            when S_ERROR    => return C_STATE_ERROR;
        end case;
    end function;

end package body aquasonic_pkg;
