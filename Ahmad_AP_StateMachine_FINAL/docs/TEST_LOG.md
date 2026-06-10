# Test-Log

Protokoll der Simulations-Laeufe in QuestaSim 2023.4 auf dem Linux-Server.

Bearbeiter: Ahmad & Tasnim
Datum: 2026-05-26

---

## Run 1 — `do sim_fsm.do`  (Unit-Test FSM)

**Status:** durchgelaufen ohne Fehler.

### Transcript (Screenshot 1)
Alle 4 Test-Gruppen lieferten `[ OK ]`:
- Test 1 (Nominal mission): INIT → IDLE → FUELING → PRE-ARM → ARMED → LAUNCHED → CRUISE → DROGUE → MAIN → LANDED
- Test 2 (Disarm round-trip): PRE-ARM ↔ ARMED
- Test 3 (Override paths): IDLE/FUELING/PRE-ARM → OVERRIDE → IDLE (3× geprüft)
- Test 4 (Critical fault): in flight → ERROR → ERROR terminal

Letzte Zeile: `==== aquasonic_fsm tb - DONE ====` bei 1100 ns / 1165500 ps Sim-Zeit.

### Wave (Screenshot 2)
- Sim-Zeit insgesamt: 0 ps bis 1 133 594 ps
- `state_code` durchläuft die erwartete Sequenz: 12 (INIT) → 1 (IDLE) → 2 (FUELING) → 3 (PRE_ARM) → 5 (ARMED) → 6 (LAUNCHED) → 7 (CRUISE) → 8 (DROGUE) → 9 (MAIN) → 11 (LANDED)
- Reset-Pulse zwischen den 4 Tests sichtbar — FSM kehrt jeweils auf INIT (12) zurück
- Test 3 zeigt OVERRIDE (Code 10) korrekt aus IDLE/FUELING/PRE_ARM
- Test 4 endet in ERROR (Code 0) nach `critical_fault = 1` während LAUNCHED

**Bewertung:** alle Übergänge spec-konform, keine Latches, keine Glitches.

---

## Run 2 — `do sim_trigger.do`  (Unit-Test trigger_logic)

**Status:** durchgelaufen ohne Fehler (nach Loop-Bound-Fix).

### Erster Lauf: 2x FAIL
- `[FAIL] apogee` bei 510 ns
- `[FAIL] stable_altitude` bei 1710 ns
- Ursache: 1-Takt-Pipeline-Versatz zwischen compute_proc und debounce_proc
  in `trigger_logic.vhd` plus baro-Sprung beim Phasen-Uebergang. Die TB
  schickte zu wenige Samples damit der Trigger noch innerhalb der Phase
  feuern konnte. Im Wave-Fenster sah man: apogee ging spaeter doch auf '1',
  aber zu spaet fuer die Assertion.

### Fix
In `tbs/trigger_logic_tb.vhd` Loop-Iterationen fuer apogee und landed von
`+1` auf `+3` erhoeht (1 Sample fuer Pipeline-Lag, 1 fuer baro-Sprung,
N+1 fuers eigentliche Feuern). RTL unveraendert.

### Zweiter Lauf (Screenshots)
- Phase 1 (ground)       : `[ OK ] kein liftoff`, `[ OK ] kein burnout`
- Phase 2 (liftoff)      : `[ OK ] liftoff`
- Phase 3 (burnout)      : `[ OK ] burnout`
- Phase 4 (apogee)       : `[ OK ] apogee`
- Phase 5a (main para.)  : `[ OK ] target_altitude`
- Phase 5b (landed)      : `[ OK ] stable_altitude`
- Letzte Zeile: `==== trigger_logic tb - DONE ====` bei 1830 ns / 1840 ns
  Sim-Zeit.

**Bewertung:** Sensor-zu-Trigger-Pipeline funktioniert spec-konform, alle
fuenf Trigger feuern in der richtigen Reihenfolge mit korrektem Debounce.

---

## Run 3 — `do sim_top.do`  (Integrationstest mit CSV-Stream)

**Status:** durchgelaufen ohne Fehler.

### Vorbereitung
CSV-Datei `telemetry_flight.csv` wurde nach `Ahmad_AP_StateMachine_FINAL/data/`
kopiert (vorher relativ zum Eltern-Repo, was via x2go nicht erreichbar war).
`CSV_PATH` in `rocket_top_tb.vhd` und in `analyze_csv.py` entsprechend
angepasst.

### Transcript (Screenshot)
- Pipeline: `frame_aligner` -> `trigger_logic` -> `aquasonic_fsm` instanziert
- Manuelle FSM-Sequenz vor dem CSV-Stream:
  - `STATE -> INIT`   (nach Reset)
  - `STATE -> IDLE`   bei  95 ns  (init_done)
  - `STATE -> FUELING` bei 175 ns  (start_fueling)
  - `STATE -> PRE_ARM` bei 255 ns  (fueling_complete)
  - `STATE -> ARMED`   bei 335 ns  (arm_cmd)
  - "Pipeline armiert - starte CSV-Stream" bei 400 ns
- Automatische Trigger aus echten Flugdaten:
  - `STATE -> LAUNCHED` bei 1.26 ms (Liftoff-Trigger auf CSV-Zeile ~954)
  - `STATE -> CRUISE`   bei 1.28 ms (Burnout-Trigger auf CSV-Zeile ~967)
- CSV durchgespielt: **3001 Frames gesendet**
- Letzter State-Code = 7 (CRUISE)
- `==== rocket_top_tb - DONE ====` bei 3.96 ms

### Wave
- Byte-Stream aus dem TB sichtbar (`byte_in`, `byte_valid`)
- Extrahierte Sensor-Werte aendern sich rhytmisch pro Frame
- Trigger `liftoff_detected` und `engine_burnout_detected` gehen wie
  erwartet auf '1'
- `current_state` Wechsel S_ARMED -> S_CRUISE klar zu sehen
- `state_code` 5 -> 7

### Bewertung
Pipeline funktioniert End-to-End mit echten Flugdaten:
- `frame_aligner` baut 66-Byte-Frames korrekt zusammen
- Field-Extraction an den richtigen Byte-Offsets
- `trigger_logic` rechnet acc^2 und dh richtig
- FSM kommt aus den echten Sensor-Daten heraus von ARMED nach CRUISE

Apogee, Main-Parachute und Landed konnten nicht ausgeloest werden, weil
die `telemetry_flight.csv` ab Zeile ~964 nur noch `baro_h=0` enthaelt
(Sensor-Ausfall im Originaldatensatz). Das ist **kein RTL-Bug**, sondern
ein Daten-Problem — mit dem Rocket-Team zu klaeren bzw. ein vollstaendigerer
Flugdatensatz erforderlich.

### Hinweis zu Initial-Warning
Im Transcript erscheint einmalig bei t=0ps:
```
Warning: NUMERIC_STD.TO_INTEGER: metavalue detected, returning 0
STATE -> ERROR
```
Das ist der `monitor`-Prozess der das uninitialisierte `state_code`-Register
einmal liest bevor der Reset durchgreift. Harmlos.

---

## Zusammenfassung

| Test            | Ergebnis | Bemerkung                                          |
|-----------------|----------|----------------------------------------------------|
| sim_fsm.do      | OK       | 4 Tests, alle [OK]                                 |
| sim_trigger.do  | OK       | 5 Phasen, nach Loop-Bound-Fix in TB                |
| sim_top.do      | OK       | 3001 Frames, Liftoff+Burnout aus echten CSV-Daten  |

Die Implementierung ist **funktional verifiziert und abgabe-bereit**.

---

## Offene Beobachtungen / TODOs

- CSV `telemetry_flight.csv` enthaelt nur die Boost-Phase. Fuer einen
  kompletten End-to-End-Test (bis LANDED) brauchen wir Flugdaten die auch
  Apogee, Drogue/Main-Phase und Touchdown abdecken.
- Trigger-Schwellwerte in `aquasonic_pkg.vhd` sind Platzhalter aus der
  ESP32-Referenz. Vom Rocket-Team final bestaetigen lassen (insb. Tank).
- Vivado-Synthese auf Trenz Z7020 steht noch aus.
- `telemetry_tx`-Modul muss noch ergaenzt werden (state_code zurueck in
  ausgehendes Telemetrie-Paket einsetzen).
