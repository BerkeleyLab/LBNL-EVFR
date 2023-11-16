# FMC 1
# LA03_N -- G10
set_property -dict {PACKAGE_PIN L18 IOSTANDARD LVCMOS25} [get_ports {FMC1_diagnosticOut[0]}]
# LA04_N -- H11
set_property -dict {PACKAGE_PIN G20 IOSTANDARD LVCMOS25} [get_ports {FMC1_diagnosticOut[1]}]
# LA06_P -- C10
set_property -dict {PACKAGE_PIN L19 IOSTANDARD LVCMOS25 PULLUP true} [get_ports FMC1_EVIO_SCL]
# LA06_N -- C11
set_property -dict {PACKAGE_PIN L20 IOSTANDARD LVCMOS25 PULLUP true} [get_ports FMC1_EVIO_SDA]
# LA07_P -- H13
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS25} [get_ports {FMC1_fireflySelect_n[0]}]
# LA07_N -- H14
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS25} [get_ports {FMC1_fireflySelect_n[1]}]
# LA08_P -- G12
set_property -dict {PACKAGE_PIN G19 IOSTANDARD LVCMOS25 PULLUP true} [get_ports {FMC1_fireflyPresent_n[0]}]
# LA08_N -- G13
set_property -dict {PACKAGE_PIN F20 IOSTANDARD LVCMOS25 PULLUP true} [get_ports {FMC1_fireflyPresent_n[1]}]
# LA11_P -- H16
set_property -dict {PACKAGE_PIN L17 IOSTANDARD LVCMOS25} [get_ports {FMC1_fireflySelect_n[2]}]
# LA11_N -- H17
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS25} [get_ports {FMC1_sysReset_n}]
# LA12_P -- G15
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS25 PULLUP true} [get_ports {FMC1_fireflyPresent_n[2]}]
# LA12_N -- G16
set_property -dict {PACKAGE_PIN F15 IOSTANDARD LVCMOS25 PULLUP true} [get_ports {FMC1_fireflyPresent_n[3]}]
# LA15_P -- H19
set_property -dict {PACKAGE_PIN J15 IOSTANDARD LVCMOS25 PULLUP true} [get_ports FMC1_FAN1_TACH]
# LA15_N -- H20
set_property -dict {PACKAGE_PIN J16 IOSTANDARD LVCMOS25 PULLUP true} [get_ports FMC1_FAN2_TACH]
# LA16_P -- G18
set_property -dict {PACKAGE_PIN K16 IOSTANDARD LVCMOS25 PULLUP true} [get_ports {FMC1_fireflyPresent_n[4]}]
# LA16_N -- G19
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS25 PULLUP true} [get_ports {FMC1_fireflyPresent_n[5]}]
# LA19_P -- H22
set_property -dict {PACKAGE_PIN H14 IOSTANDARD LVCMOS25} [get_ports {FMC1_hwTrigger[0]}]
# LA19_N -- H23
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS25} [get_ports {FMC1_hwTrigger[1]}]
# LA21_P -- H25
set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS25} [get_ports {FMC1_hwTrigger[2]}]
# LA21_N -- H26
set_property -dict {PACKAGE_PIN D13 IOSTANDARD LVCMOS25} [get_ports {FMC1_hwTrigger[3]}]
# LA24_P -- H28
set_property -dict {PACKAGE_PIN A9 IOSTANDARD LVCMOS25} [get_ports {FMC1_hwTrigger[4]}]
# LA24_N -- H29
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS25} [get_ports {FMC1_hwTrigger[5]}]
# LA28_P -- H31
set_property -dict {PACKAGE_PIN J13 IOSTANDARD LVCMOS25} [get_ports FMC1_auxInput]
# LA28_N -- H32
set_property -dict {PACKAGE_PIN H13 IOSTANDARD LVCMOS25} [get_ports {FMC1_diagnosticIn[0]}]

# FIXME -- EVRIO constraints need to go here -- awaiting hardware.....
# FMC 2
# CLK1_M2C_P -- G2
set_property -dict {PACKAGE_PIN F22 IOSTANDARD LVDS_25 DIFF_TERM true} [get_ports EVRIO_PLL_OUT_P]
# CLK1_M2C_N -- G3
set_property -dict {PACKAGE_PIN E23 IOSTANDARD LVDS_25 DIFF_TERM true} [get_ports EVRIO_PLL_OUT_N]
# LA00_P -- G6
set_property -dict {PACKAGE_PIN Y22 IOSTANDARD LVDS_25} [get_ports EVRIO_PLL_REF_P]
# LA00_N -- G7
set_property -dict {PACKAGE_PIN AA22 IOSTANDARD LVDS_25} [get_ports EVRIO_PLL_REF_N]
# LA03_P -- G9
set_property -dict {PACKAGE_PIN AD26 IOSTANDARD LVDS_25} [get_ports {EVRIO_PATTERN_P[0]}]
# LA03_N -- G10
set_property -dict {PACKAGE_PIN AE26 IOSTANDARD LVDS_25} [get_ports {EVRIO_PATTERN_N[0]}]
# LA08_P -- G12
set_property -dict {PACKAGE_PIN AC23 IOSTANDARD LVDS_25} [get_ports {EVRIO_PATTERN_P[1]}]
# LA08_N -- G13
set_property -dict {PACKAGE_PIN AC24 IOSTANDARD LVDS_25} [get_ports {EVRIO_PATTERN_N[1]}]
# LA09_P -- D14
set_property -dict {PACKAGE_PIN U26 IOSTANDARD LVCMOS25} [get_ports EVRIO_PLL_RESET_N]
# LA12_P -- G15
set_property -dict {PACKAGE_PIN AA25 IOSTANDARD LVDS_25} [get_ports {EVRIO_PATTERN_P[2]}]
# LA12_N -- G16
set_property -dict {PACKAGE_PIN AB25 IOSTANDARD LVDS_25} [get_ports {EVRIO_PATTERN_N[2]}]
# LA16_P -- G18
set_property -dict {PACKAGE_PIN W25 IOSTANDARD LVDS_25} [get_ports {EVRIO_PATTERN_P[3]}]
# LA16_N -- G19
set_property -dict {PACKAGE_PIN W26 IOSTANDARD LVDS_25} [get_ports {EVRIO_PATTERN_N[3]}]
# LA17_P -- D20
set_property -dict {PACKAGE_PIN G22 IOSTANDARD LVCMOS25} [get_ports EVRIO_PWR_EN]
# LA17_N -- D21
set_property -dict {PACKAGE_PIN F23 IOSTANDARD LVCMOS25 PULLUP true} [get_ports EVRIO_5V1_PG]
# LA23_P -- D23
set_property -dict {PACKAGE_PIN H23 IOSTANDARD LVCMOS25 PULLUP true} [get_ports EVRIO_4V5_PG]
# LA30_N -- H35
set_property -dict {PACKAGE_PIN C26 IOSTANDARD LVCMOS25 PULLUP true} [get_ports EVRIO_SCL]
# LA32_P -- H37
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS25 PULLUP true} [get_ports EVRIO_SDA]
# LA05_N -- D12
set_property -dict {PACKAGE_PIN AC26 IOSTANDARD LVCMOS25} [get_ports EVRIO_VCXO_EN]
# LA29_N -- G31
set_property -dict {PACKAGE_PIN H26 IOSTANDARD LVCMOS25} [get_ports {EVRIO_TRIGGER[0]}]
# LA29_P -- G30
set_property -dict {PACKAGE_PIN J26 IOSTANDARD LVCMOS25} [get_ports {EVRIO_TRIGGER[1]}]
# LA25_N -- G28
set_property -dict {PACKAGE_PIN D24 IOSTANDARD LVCMOS25} [get_ports {EVRIO_TRIGGER[2]}]
# LA25_P -- G27
set_property -dict {PACKAGE_PIN D23 IOSTANDARD LVCMOS25} [get_ports {EVRIO_TRIGGER[3]}]
# LA22_N -- G25
set_property -dict {PACKAGE_PIN D25 IOSTANDARD LVCMOS25} [get_ports {EVRIO_TRIGGER[4]}]
# LA22_P -- G24
set_property -dict {PACKAGE_PIN E25 IOSTANDARD LVCMOS25} [get_ports {EVRIO_TRIGGER[5]}]
# LA20_N -- G22
set_property -dict {PACKAGE_PIN K22 IOSTANDARD LVCMOS25} [get_ports {EVRIO_TRIGGER[6]}]
# LA20_P -- G21
set_property -dict {PACKAGE_PIN L22 IOSTANDARD LVCMOS25} [get_ports {EVRIO_TRIGGER[7]}]

create_clock -period 2.000 -name evrpll_out_clk [get_ports EVRIO_PLL_OUT_P]
