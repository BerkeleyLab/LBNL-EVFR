create_clock -period 8.000 -name rx_clk [get_ports RGMII_RX_CLK]

# 125 MHz from U20
#create_clock -period 8.000 -name ddr_ref_clk [get_ports DDR_REF_CLK_P]

# 20 MHz from Y3
#create_clock -period 50.000 -name clk20_vcxo [get_ports CLK20_VCXO]
#set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets CLK20_VCXO]

# MGTREFCLK0_115 (schematic MGT_CLK_2), U2 output 4
create_clock -period 10.000 -name gtx_ref0 [get_ports MGT_CLK_P]

# Don't check timing across clock domains
set_false_path -from [get_clocks gtx_ref0] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]]
set_false_path -from [get_clocks rx_clk] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]]
set_false_path -from [get_clocks rx_clk] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1}]]
set_false_path -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]] -to [get_clocks rx_clk]
set_false_path -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]]
set_false_path -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT1}]]
set_false_path -from [get_clocks evr/evrmgt_i/inst/evrmgt_i/gt0_evrmgt_i/gtxe2_i/RXOUTCLK] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]]
set_false_path -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *mgtRef/O}]] -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]]
set_false_path -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]] -to [get_clocks evr/evrmgt_i/inst/evrmgt_i/gt0_evrmgt_i/gtxe2_i/RXOUTCLK]
