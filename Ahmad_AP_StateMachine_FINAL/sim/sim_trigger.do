# sim_trigger.do - trigger_logic Unit-Test
# Aufruf: do sim_trigger.do

do compile.do
vsim -voptargs=+acc work.trigger_logic_tb

add wave -divider "Clock & Reset"
add wave sim:/trigger_logic_tb/clk
add wave sim:/trigger_logic_tb/reset

add wave -divider "Sample"
add wave sim:/trigger_logic_tb/sample_valid
add wave -radix decimal sim:/trigger_logic_tb/acc_x
add wave -radix decimal sim:/trigger_logic_tb/acc_y
add wave -radix decimal sim:/trigger_logic_tb/acc_z
add wave -radix unsigned sim:/trigger_logic_tb/baro_h

add wave -divider "Interne"
add wave -radix decimal sim:/trigger_logic_tb/DUT/acc_sq_sum
add wave -radix decimal sim:/trigger_logic_tb/DUT/dh

add wave -divider "Trigger"
add wave sim:/trigger_logic_tb/liftoff_detected
add wave sim:/trigger_logic_tb/engine_burnout_detected
add wave sim:/trigger_logic_tb/apogee_detected
add wave sim:/trigger_logic_tb/target_altitude_detected
add wave sim:/trigger_logic_tb/stable_altitude_detected

run -all
wave zoom full
