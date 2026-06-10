# sim_fsm.do - FSM-Unit-Test
# Aufruf: do sim_fsm.do

do compile.do
vsim -voptargs=+acc work.rocket_fsm_tb

add wave -divider "Clock & Reset"
add wave sim:/rocket_fsm_tb/clk
add wave sim:/rocket_fsm_tb/reset

add wave -divider "Manual cmds"
add wave sim:/rocket_fsm_tb/start_fueling
add wave sim:/rocket_fsm_tb/fueling_complete
add wave sim:/rocket_fsm_tb/arm_cmd
add wave sim:/rocket_fsm_tb/disarm_cmd
add wave sim:/rocket_fsm_tb/override_cmd
add wave sim:/rocket_fsm_tb/restart_sequence

add wave -divider "Auto triggers"
add wave sim:/rocket_fsm_tb/init_done
add wave sim:/rocket_fsm_tb/liftoff_detected
add wave sim:/rocket_fsm_tb/engine_burnout_detected
add wave sim:/rocket_fsm_tb/apogee_detected
add wave sim:/rocket_fsm_tb/target_altitude_detected
add wave sim:/rocket_fsm_tb/stable_altitude_detected
add wave sim:/rocket_fsm_tb/critical_fault

add wave -divider "FSM state"
add wave -radix ascii    sim:/rocket_fsm_tb/DUT/current_state
add wave -radix unsigned sim:/rocket_fsm_tb/state_code

add wave -divider "Outputs"
add wave sim:/rocket_fsm_tb/fueling_active
add wave sim:/rocket_fsm_tb/system_pre_arm
add wave sim:/rocket_fsm_tb/system_armed
add wave sim:/rocket_fsm_tb/in_flight
add wave sim:/rocket_fsm_tb/deploy_drogue
add wave sim:/rocket_fsm_tb/deploy_main
add wave sim:/rocket_fsm_tb/landed_led
add wave sim:/rocket_fsm_tb/override_led
add wave sim:/rocket_fsm_tb/fault_led
add wave sim:/rocket_fsm_tb/telemetry_enable
add wave sim:/rocket_fsm_tb/logging_enable

run -all
wave zoom full
