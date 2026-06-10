# sim_top.do - Integrations-Testbench (CSV-Stream durch die Pipeline)
# Aufruf: do sim_top.do

do compile.do
vsim -voptargs=+acc work.rocket_top_tb

add wave -divider "Clock & Reset"
add wave sim:/rocket_top_tb/clk
add wave sim:/rocket_top_tb/reset

add wave -divider "Byte-Stream in frame_aligner"
add wave -radix hex sim:/rocket_top_tb/byte_in
add wave sim:/rocket_top_tb/byte_valid
add wave -radix unsigned sim:/rocket_top_tb/frames_in

add wave -divider "Extrahierte Sensor-Werte"
add wave -radix decimal sim:/rocket_top_tb/s_acc_x
add wave -radix decimal sim:/rocket_top_tb/s_acc_y
add wave -radix decimal sim:/rocket_top_tb/s_acc_z
add wave -radix unsigned sim:/rocket_top_tb/s_baro_h
add wave -radix unsigned sim:/rocket_top_tb/s_chamber_p
add wave -radix unsigned sim:/rocket_top_tb/s_tank_p
add wave sim:/rocket_top_tb/sample_valid
add wave sim:/rocket_top_tb/frame_drop

add wave -divider "Trigger"
add wave sim:/rocket_top_tb/s_liftoff_detected
add wave sim:/rocket_top_tb/s_engine_burnout_detected
add wave sim:/rocket_top_tb/s_apogee_detected
add wave sim:/rocket_top_tb/s_target_altitude_detected
add wave sim:/rocket_top_tb/s_stable_altitude_detected

add wave -divider "FSM"
add wave -radix ascii    sim:/rocket_top_tb/U_FSM/current_state
add wave -radix unsigned sim:/rocket_top_tb/state_code

add wave -divider "Outputs"
add wave sim:/rocket_top_tb/deploy_drogue
add wave sim:/rocket_top_tb/deploy_main
add wave sim:/rocket_top_tb/landed_led
add wave sim:/rocket_top_tb/fault_led
add wave sim:/rocket_top_tb/telemetry_enable
add wave sim:/rocket_top_tb/logging_enable

run -all
wave zoom full
