# AquaSonic WP5 — State Machine Rocket

VHDL-Implementierung der Missions-FSM für die AquaSonic-Rakete inklusive
Sensor-Trigger-Pipeline (UART → Frame-Aligner → Trigger → FSM).

Bearbeiter: Ahmad & Tasnim

## Was das macht

Das Modul nimmt Sensor-Telemetrie über UART (115200 8N1, 66-Byte-Frames
mit 10 Hz) entgegen, extrahiert die relevanten Werte (acc x/y/z, baro
height, chamber pres, tank pres), bildet daraus die Trigger
(liftoff, burnout, apogee, main parachute, landed) und füttert sie in die
Zustandsmaschine.

Ausgegeben werden:
- 4-Bit state_code für das Telemetrie-Paket (Feld 27 laut Spec)
- Aktor-Signale: deploy_drogue, deploy_main, fault_led, override_led,
  telemetry_enable, logging_enable, ...

## Voraussetzungen

- QuestaSim 2023.4+ für Simulation (`vcom -2008`)
- Vivado 2023.x für Synthese auf Trenz Z7020 (geplant)

Entwickelt unter Windows gegen einen Linux-Server (x2go), Questa läuft
serverseitig.

## Ordnerstruktur

```
Ahmad_AP_StateMachine_FINAL/
  README.md
  rtl/
    aquasonic_pkg.vhd      - Konstanten, State-Codes, Schwellwerte
    uart_rx.vhd            - 8N1 UART-Empfaenger
    frame_aligner.vhd      - 66-Byte-Frame Assembly + Field Extraction
    trigger_logic.vhd      - Schwellwert + Debounce -> trigger
    rocket_fsm.vhd         - Zustandsautomat mit Aktor-Outputs
    rocket_top.vhd         - Top-Level-Wrapper
  tbs/
    rocket_fsm_tb.vhd      - FSM Unit-Test
    trigger_logic_tb.vhd   - Trigger-Logic Unit-Test
    rocket_top_tb.vhd      - Integrationstest mit CSV-Stream
  sim/
    compile.do             - kompiliert RTL + TBs
    sim_fsm.do             - FSM-TB starten
    sim_trigger.do         - Trigger-TB starten
    sim_top.do             - Integrations-TB mit CSV-Stream
  data/
    telemetry_flight.csv   - echte Flugdaten fuer den Integrationstest
  docs/
    ARCHITECTURE.md
    TEST_LOG.md            - Sim-Protokoll
```

## Konstanten

Alle Schwellwerte, State-Codes und Byte-Offsets stehen in
`rtl/aquasonic_pkg.vhd`. Wenn das Rocket-Team neue Werte liefert wird nur
diese Datei angepasst. Aktuell sind die Werte aus der ESP32-Referenz
übernommen (`aquacan/sw/aquacan-active/lib/aquacanconstants/`).

| Übergang | Konstante | Wert |
|----------|-----------|------|
| ARMED → LAUNCHED | `C_LIFTOFF_ACC_SQ_THR` | 2_160_900 (≈1.5 g)² |
| LAUNCHED → CRUISE | `C_BURNOUT_ACC_SQ_THR` | 240_100 (≈0.5 g)² |
| CRUISE → DROGUE | `C_APOGEE_DH_RAW_THR` | −20 raw / Sample |
| DROGUE → MAIN | `C_MAIN_ALT_RAW_THR` | 7500 (= 750 m) |
| MAIN → LANDED | `C_LANDED_DH_RAW_THR` | −1 raw |

Vergleiche laufen auf den rohen UInt16-Werten, keine Floats, kein sqrt.
Beschleunigungen werden quadriert verglichen.

## Simulation

```tcl
cd <pfad>/Ahmad_AP_StateMachine_FINAL/sim
do sim_fsm.do
do sim_trigger.do
do sim_top.do
```

Beide do-Skripte rufen intern `compile.do` auf. Erwartete Ausgabe sind
`[ OK ]`-Zeilen pro Testschritt.

## Offen

- Vivado-Synthese auf Trenz Z7020
- Echte Schwellwerte vom Rocket-Team (insb. Tank-Werte sind TBD)
- Operator-Command-Decoder definieren (mit AquaCom-Team)
- State-Code 4 und doppelter ERROR-Code (0/15) in der Spec klären
- `telemetry_tx`-Modul ergänzen

## Verweise

- Spec: `aquaarch_systemarchitektur/Main System Specifications/aquasonic_avionics_system_specifications.tex`
- UART-Parameter: `documentation/datasheet_aquabrain/aquabrain_datasheet.tex`
- Referenz-Trigger: `aquacan/sw/aquacan-active/lib/`
- Beispiel-Flugdaten: `aquaarch_systemarchitektur/data_formats/telemetry_flight.csv`
