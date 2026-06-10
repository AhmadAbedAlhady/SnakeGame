# compile.do - kompiliert RTL + Testbenches in die work-Library
# Aufruf: do compile.do

if {[file exists work]} { vdel -lib work -all }
vlib work

# Package zuerst (wird von allen anderen referenziert)
vcom -2008 ../rtl/aquasonic_pkg.vhd

# RTL
vcom -2008 ../rtl/uart_rx.vhd
vcom -2008 ../rtl/frame_aligner.vhd
vcom -2008 ../rtl/trigger_logic.vhd
vcom -2008 ../rtl/rocket_fsm.vhd
vcom -2008 ../rtl/rocket_top.vhd

# Testbenches
vcom -2008 ../tbs/rocket_fsm_tb.vhd
vcom -2008 ../tbs/trigger_logic_tb.vhd
vcom -2008 ../tbs/rocket_top_tb.vhd

puts ""
puts "compile.do: alles uebersetzt"
