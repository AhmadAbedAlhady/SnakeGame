"""
analyze_csv.py - Bildet trigger_logic.vhd in Python nach und laesst es ueber
                 die echte Flugdaten-CSV laufen. Gibt aus:
                  - bei welcher Zeile welcher Trigger feuert (bzw. nie)
                  - Wertebereiche von acc^2, baro_h, dh
                  - Vorschlag fuer realistische Schwellwerte

Aufruf:  python analyze_csv.py
"""

import csv
import os
import sys

# ---------------------------------------------------------------------------
# Schwellwerte aus aquasonic_pkg.vhd (identisch)
# ---------------------------------------------------------------------------
LIFTOFF_ACC_SQ_THR = 2_160_900
BURNOUT_ACC_SQ_THR = 240_100
APOGEE_DH_RAW_THR  = -20
MAIN_ALT_RAW_THR   = 7500
LANDED_DH_RAW_THR  = -1

LIFTOFF_DEBOUNCE_N  = 3
BURNOUT_DEBOUNCE_N  = 3
APOGEE_DEBOUNCE_N   = 2
MAIN_ALT_DEBOUNCE_N = 2
LANDED_DEBOUNCE_N   = 30

CSV_PATH = os.path.join(
    os.path.dirname(__file__),
    "..", "data", "telemetry_flight.csv",
)


def signed16(v: int) -> int:
    """CSV-Werte koennen bereits signed sein; UInt16 -> signed konvertieren."""
    v = v & 0xFFFF
    return v - 0x10000 if v >= 0x8000 else v


def main() -> int:
    if not os.path.exists(CSV_PATH):
        print(f"FEHLER: CSV nicht gefunden: {CSV_PATH}")
        return 1

    # State der trigger_logic
    prev_h = 0
    cnt_liftoff = cnt_burnout = cnt_apogee = cnt_main = cnt_landed = 0
    r_liftoff = r_burnout = r_apogee = r_main = r_landed = False

    # wann jeder Trigger gefeuert hat (Zeile, time_ms)
    fired = {
        "liftoff": None,
        "burnout": None,
        "apogee": None,
        "main_alt": None,
        "landed": None,
    }

    # Statistiken
    min_acc_sq, max_acc_sq = None, None
    min_baro, max_baro = None, None
    min_dh, max_dh = None, None
    peak_acc_row = 0

    with open(CSV_PATH, newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    print(f"=== CSV geladen: {len(rows)} Zeilen ===\n")

    for i, row in enumerate(rows):
        # Spalten aus dem Header (siehe CSV-Header)
        acc_x  = signed16(int(row["imu1_acc_x"]))
        acc_y  = signed16(int(row["imu1_acc_y"]))
        acc_z  = signed16(int(row["imu1_acc_z"]))
        baro_h = int(row["baro1_height"])
        t_ms   = int(row["time_ms"])

        acc_sq = acc_x * acc_x + acc_y * acc_y + acc_z * acc_z
        dh     = baro_h - prev_h
        prev_h = baro_h

        # Statistiken aktualisieren
        if max_acc_sq is None or acc_sq > max_acc_sq:
            max_acc_sq = acc_sq
            peak_acc_row = i
        if min_acc_sq is None or acc_sq < min_acc_sq:
            min_acc_sq = acc_sq
        if max_baro is None or baro_h > max_baro:
            max_baro = baro_h
        if min_baro is None or baro_h < min_baro:
            min_baro = baro_h
        if i > 0:
            if max_dh is None or dh > max_dh:
                max_dh = dh
            if min_dh is None or dh < min_dh:
                min_dh = dh

        # Trigger-Logik 1:1 wie im VHDL ----------------------------------
        # LIFTOFF
        if acc_sq > LIFTOFF_ACC_SQ_THR:
            if cnt_liftoff < LIFTOFF_DEBOUNCE_N:
                cnt_liftoff += 1
            else:
                if not r_liftoff:
                    fired["liftoff"] = (i, t_ms)
                r_liftoff = True
        else:
            cnt_liftoff = 0

        # BURNOUT (erst nach liftoff)
        if r_liftoff:
            if acc_sq < BURNOUT_ACC_SQ_THR:
                if cnt_burnout < BURNOUT_DEBOUNCE_N:
                    cnt_burnout += 1
                else:
                    if not r_burnout:
                        fired["burnout"] = (i, t_ms)
                    r_burnout = True
            else:
                cnt_burnout = 0

        # APOGEE (erst nach burnout)
        if r_burnout:
            if dh < APOGEE_DH_RAW_THR:
                if cnt_apogee < APOGEE_DEBOUNCE_N:
                    cnt_apogee += 1
                else:
                    if not r_apogee:
                        fired["apogee"] = (i, t_ms)
                    r_apogee = True
            else:
                cnt_apogee = 0

        # MAIN ALT (erst nach apogee)
        if r_apogee:
            if baro_h < MAIN_ALT_RAW_THR:
                if cnt_main < MAIN_ALT_DEBOUNCE_N:
                    cnt_main += 1
                else:
                    if not r_main:
                        fired["main_alt"] = (i, t_ms)
                    r_main = True
            else:
                cnt_main = 0

        # LANDED (erst nach main_alt)
        if r_main:
            if dh > LANDED_DH_RAW_THR:
                if cnt_landed < LANDED_DEBOUNCE_N:
                    cnt_landed += 1
                else:
                    if not r_landed:
                        fired["landed"] = (i, t_ms)
                    r_landed = True
            else:
                cnt_landed = 0

    # -------------------------------------------------------------------
    # Ergebnis-Report
    # -------------------------------------------------------------------
    print("=== Trigger-Verlauf (mit aktuellen Schwellwerten) ===")
    for name, info in fired.items():
        if info:
            row, t = info
            print(f"  {name:9s} feuert  in Zeile {row:5d}  (t = {t} ms)")
        else:
            print(f"  {name:9s} feuert  NIE")

    print()
    print("=== Wertebereiche im CSV ===")
    print(f"  acc_sq_sum : min = {min_acc_sq:>12d}   max = {max_acc_sq:>12d}"
          f"   (peak in Zeile {peak_acc_row})")
    print(f"  baro_h     : min = {min_baro:>12d}   max = {max_baro:>12d}")
    print(f"  dh (delta) : min = {min_dh:>12d}   max = {max_dh:>12d}")

    print()
    print("=== Aktuelle Schwellwerte ===")
    print(f"  LIFTOFF_ACC_SQ_THR  = {LIFTOFF_ACC_SQ_THR:>12d}")
    print(f"  BURNOUT_ACC_SQ_THR  = {BURNOUT_ACC_SQ_THR:>12d}")
    print(f"  APOGEE_DH_RAW_THR   = {APOGEE_DH_RAW_THR:>12d}")
    print(f"  MAIN_ALT_RAW_THR    = {MAIN_ALT_RAW_THR:>12d}")
    print(f"  LANDED_DH_RAW_THR   = {LANDED_DH_RAW_THR:>12d}")

    # -------------------------------------------------------------------
    # Vorschlag fuer realistische Schwellwerte basierend auf der CSV
    # -------------------------------------------------------------------
    print()
    print("=== Vorschlag aus den CSV-Daten ===")
    # Liftoff: ~25% des Peaks (so dass beim Aufstieg klar getriggert wird)
    suggest_liftoff = int(max_acc_sq * 0.25)
    suggest_burnout = int(max_acc_sq * 0.05)
    print(f"  LIFTOFF_ACC_SQ_THR  ~ {suggest_liftoff:>12d}  (25% von max acc^2)")
    print(f"  BURNOUT_ACC_SQ_THR  ~ {suggest_burnout:>12d}  ( 5% von max acc^2)")
    if min_dh is not None:
        suggest_apogee = int(min_dh * 0.5)
        print(f"  APOGEE_DH_RAW_THR   ~ {suggest_apogee:>12d}  (50% von min dh)")
    suggest_main = int(max_baro * 0.4)
    print(f"  MAIN_ALT_RAW_THR    ~ {suggest_main:>12d}  (40% von max baro_h)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
