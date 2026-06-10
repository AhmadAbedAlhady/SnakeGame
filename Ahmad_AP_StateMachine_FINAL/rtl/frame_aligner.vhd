-- frame_aligner.vhd
-- AquaSonic Avionics - WP5 State Machine Rocket
-- Ahmad & Tasnim
--
-- Baut aus dem Byte-Stream von uart_rx 66-Byte-Telemetrie-Frames
-- zusammen und extrahiert die Sensorwerte die trigger_logic braucht.
--
-- Frame-Start-Erkennung: nach >= C_FRAME_IDLE_MS Stille gilt das naechste
-- Byte als Byte 0. Bei 115200 baud dauert ein 66-Byte-Frame ~5.7 ms,
-- naechster Frame kommt nach 100 ms, also ~94 ms Idle dazwischen.
-- 10 ms Schwelle reicht locker.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.aquasonic_pkg.all;

entity frame_aligner is
    port (
        clk          : in  std_logic;
        reset        : in  std_logic;

        byte_in      : in  std_logic_vector(7 downto 0);
        byte_valid   : in  std_logic;

        imu1_acc_x   : out std_logic_vector(15 downto 0);
        imu1_acc_y   : out std_logic_vector(15 downto 0);
        imu1_acc_z   : out std_logic_vector(15 downto 0);
        baro1_height : out std_logic_vector(15 downto 0);
        chamber_pres : out std_logic_vector(15 downto 0);
        tank_pres    : out std_logic_vector(15 downto 0);

        sample_valid : out std_logic;
        frame_drop   : out std_logic
    );
end entity frame_aligner;


architecture rtl of frame_aligner is

    constant IDLE_TICKS : integer := (C_CLK_FREQ_HZ / 1000) * C_FRAME_IDLE_MS;

    type frame_buf_t is array (0 to C_FRAME_BYTES-1) of std_logic_vector(7 downto 0);
    signal frame_buf : frame_buf_t := (others => (others => '0'));

    signal byte_cnt  : integer range 0 to C_FRAME_BYTES := 0;
    signal idle_cnt  : integer range 0 to IDLE_TICKS    := 0;

    -- Little-endian 2-Byte-Read aus dem Buffer
    function read16(buf : frame_buf_t; off : integer) return std_logic_vector is
    begin
        return buf(off + 1) & buf(off);
    end function;

begin

    process(clk, reset)
    begin
        if reset = '1' then
            byte_cnt      <= 0;
            idle_cnt      <= 0;
            sample_valid  <= '0';
            frame_drop    <= '0';
            imu1_acc_x    <= (others => '0');
            imu1_acc_y    <= (others => '0');
            imu1_acc_z    <= (others => '0');
            baro1_height  <= (others => '0');
            chamber_pres  <= (others => '0');
            tank_pres     <= (others => '0');

        elsif rising_edge(clk) then
            sample_valid <= '0';
            frame_drop   <= '0';

            -- Idle-Zaehler hochzaehlen solange kein Byte kommt
            if byte_valid = '1' then
                idle_cnt <= 0;
            elsif idle_cnt < IDLE_TICKS then
                idle_cnt <= idle_cnt + 1;
            end if;

            if byte_valid = '1' then

                -- Langer Idle gerade vorbei -> neuer Frame, alten verwerfen
                if idle_cnt = IDLE_TICKS and byte_cnt /= 0 then
                    frame_drop <= '1';
                    byte_cnt   <= 1;
                    frame_buf(0) <= byte_in;

                else
                    frame_buf(byte_cnt) <= byte_in;
                    if byte_cnt = C_FRAME_BYTES - 1 then
                        byte_cnt <= 0;
                        sample_valid <= '1';

                        imu1_acc_x   <= read16(frame_buf, C_OFF_IMU1_ACC_X);
                        imu1_acc_y   <= read16(frame_buf, C_OFF_IMU1_ACC_Y);
                        imu1_acc_z   <= read16(frame_buf, C_OFF_IMU1_ACC_Z);
                        baro1_height <= read16(frame_buf, C_OFF_BARO1_HEIGHT);
                        chamber_pres <= read16(frame_buf, C_OFF_CHAMBER_PRES);
                        tank_pres    <= read16(frame_buf, C_OFF_TANK_PRES);
                    else
                        byte_cnt <= byte_cnt + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture rtl;
