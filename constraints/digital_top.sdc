# SMIC 0.18um Digital Top SDC
# Target: 50 MHz (20 ns period)

create_clock -name clk -period 20 [get_ports clk]
set_clock_uncertainty 0.5 [get_clocks clk]
set_clock_transition 0.2 [get_clocks clk]

set_input_delay  -clock clk -max 2.0 [all_inputs]
set_input_delay  -clock clk -min 0.5 [all_inputs]
set_output_delay -clock clk -max 2.0 [all_outputs]
set_output_delay -clock clk -min 0.0 [all_outputs]

# False paths for static signals
set_false_path -from [get_ports rst_n]
set_false_path -to   [get_ports spi_miso]
