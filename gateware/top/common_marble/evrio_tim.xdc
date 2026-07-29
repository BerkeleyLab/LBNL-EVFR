set_false_path -from evrio_pll_out_clk -to [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]]
set_false_path -from [get_clocks -of_objects [get_pins -hier -filter {NAME =~ *bd_i/clk_wiz_1/inst/mmcm_adv_inst/CLKOUT0}]] -to evrio_pll_out_clk
