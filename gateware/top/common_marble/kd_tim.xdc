set_false_path -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *kickerDriverClockGenerator/gateDriverMMCM/inst/mmcm_adv_inst/CLKOUT0}]]

# Associate the ODELAY blocks with their IDELAYCTRL instance.
# It would be nice if this could be done where the SelectIO blocks are
# instantiated, but Xilinx provides no mechanism for doing so.
for {set d 92} {$d < 112} {incr d} {
    set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.$d.*odelaye2_bus"]
}
for {set d 112} {$d < 132} {incr d} {
    set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.$d.*odelaye2_bus"]
}
for {set d 132} {$d < 145} {incr d} {
    set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.$d.*odelaye2_bus"]
}
