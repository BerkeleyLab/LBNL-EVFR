set_false_path -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *kickerDriverClockGenerator/gateDriverMMCM/inst/mmcm_adv_inst/CLKOUT0}]]

# Associate the ODELAY blocks with their IDELAYCTRL instance.
# It would be nice if this could be done where the SelectIO blocks are
# instantiated, but Xilinx provides no mechanism for doing so.

#for {set d 92} {$d < 112} {incr d} {
#    set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.$d.*odelaye2_bus"]
#}
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.92.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.93.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.94.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.95.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.96.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.97.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.98.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.99.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.100.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.101.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.102.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.103.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.104.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.105.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.106.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.107.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.108.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.109.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.110.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_0" [get_cells -hier -regexp "gateDrivers.111.*odelaye2_bus"]

#for {set d 112} {$d < 132} {incr d} {
#    set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.$d.*odelaye2_bus"]
#}
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.112.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.113.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.114.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.115.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.116.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.117.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.118.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.119.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.120.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.121.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.122.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.123.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.124.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.125.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.126.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.127.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.128.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.129.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.130.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_1" [get_cells -hier -regexp "gateDrivers.131.*odelaye2_bus"]

#for {set d 132} {$d < 145} {incr d} {
#    set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.$d.*odelaye2_bus"]
#}
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.132.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.133.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.134.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.135.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.136.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.137.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.138.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.139.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.140.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.141.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.142.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.143.*odelaye2_bus"]
set_property IODELAY_GROUP "DLYGRP_2" [get_cells -hier -regexp "gateDrivers.144.*odelaye2_bus"]
