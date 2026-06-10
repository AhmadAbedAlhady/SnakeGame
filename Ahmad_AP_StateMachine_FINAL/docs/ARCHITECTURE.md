# Architektur

Bearbeiter: Ahmad & Tasnim

Ergänzung zur README, etwas mehr Detail zu den einzelnen Modulen.

## Design-Prinzipien

- Single Source of Truth: alle Konstanten und Codes in `aquasonic_pkg.vhd`
- Keine Latches: jeder Output wird in jedem Zustand explizit getrieben
- Modul-Trennung: UART, Frame-Aufbau, Sensor-Auswertung und FSM sind getrennt
- Active-high async Reset, geht sofort in `S_INIT`
- Keine Floats / kein sqrt: Beschleunigungen quadriert vergleichen
- Self-Checking Testbenches mit `[OK]`/`[FAIL]`-Reports
- Debouncing aller Sensor-Trigger (N aufeinanderfolgende Samples)

## aquasonic_pkg

Zentrales Package mit:

1. State-Codes (12 Mission-States, 4-Bit, spec-konform) + Typ `state_type`
   + Funktion `state_to_code()`.
2. System-Parameter: `C_CLK_FREQ_HZ = 100_000_000`, `C_SAMPLE_RATE_HZ = 10`,
   `C_UART_BAUDRATE = 115_200`, `C_UART_CLKS_PER_BIT`.
3. Frame-Layout: Byte-Offsets der benutzten Felder (acc x/y/z bei 4/6/8,
   baro bei 30, chamber bei 48, tank bei 36, state bei 56).
4. Trigger-Schwellwerte (raw UInt16) + Debounce-Counter.

## uart_rx

Standard 8N1-Empfänger:
- 2-FF Synchronisierer für asynchrones `rx`
- Mid-Bit-Sampling (HALF_BIT + N × CLKS_PER_BIT)
- 4 States: IDLE → START → DATA → STOP
- `byte_valid` ist genau 1 Taktzyklus aktiv

## frame_aligner

Sammelt 66-Byte-Frames und extrahiert die FSM-relevanten Felder.

Frame-Sync per UART-Idle:
- 66 Byte bei 115200 baud dauern ~5.7 ms
- Frames kommen alle 100 ms
- → ~94 ms Stille zwischen Frames

Bei länger als `C_FRAME_IDLE_MS` (10 ms) Stille gilt das nächste Byte als
Start eines neuen Frames. Wenn dabei ein Teil-Frame verworfen wird, geht
`frame_drop` für einen Takt high.

## trigger_logic

Pro `sample_valid`:
1. `acc_sq_sum = acc_x² + acc_y² + acc_z²` (signed 32 bit)
2. `dh = baro_height − prev_height` (signed 18 bit)

Jeder Trigger hat einen Debounce-Counter und ein Latch-Flipflop. Sobald die
Bedingung N aufeinanderfolgende Samples erfüllt, wird das Latch gesetzt
und bleibt high bis zum nächsten Reset.

Sequenzielle Aktivierung: `burnout`, `apogee`, `main_alt`, `landed` sind
erst aktiv wenn der jeweils vorherige Trigger gefeuert hat — verhindert
Trigger im falschen Mission-Abschnitt.

## rocket_fsm (entity `aquasonic_fsm`)

Drei-Prozess-FSM:
- `state_reg` — D-Flipflop, async Reset → S_INIT
- `next_state_logic` — kombinatorisch, mit Default-Hold
- `state_code_enc` — registrierte 4-Bit-Telemetrie-Ausgabe

Prioritäten in `next_state_logic`:
1. `critical_fault` (aus jedem operationellen Zustand → ERROR)
2. `restart_sequence` / `override_cmd` / `disarm_cmd`
3. Reguläre Übergänge per Spec
4. Default: Zustand halten

## rocket_top

Reines Verdrahtungs-Modul. Instanziert in dieser Reihenfolge:
1. `U_UART` (uart_rx)
2. `U_ALIGN` (frame_aligner)
3. `U_TRIG` (trigger_logic)
4. `U_FSM` (aquasonic_fsm)


## Testbenches

| TB | Zweck |
|----|-------|
| `rocket_fsm_tb` | FSM-Übergänge isoliert (kein Sensor-Pfad) |
| `trigger_logic_tb` | Sensor-Werte → Trigger-Signale isoliert |

Beide TBs sind self-checking: jeder Schritt führt eine Assertion durch
und gibt `[ OK ]` / `[FAIL]` aus.

Geplant: `rocket_top_tb` der die echte `telemetry_flight.csv` Byte für
Byte ins UART-RX speist und den `state_code`-Verlauf gegen die erwartete
Flug-Phase vergleicht.





