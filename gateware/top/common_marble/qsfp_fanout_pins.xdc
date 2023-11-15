#
# Pin assignement for fanout via QSFP 2 (testing only)
#

# QSFP2-1/12, Bank 115 MGT 1, X0Y1
set_property -dict {PACKAGE_PIN M2} [get_ports MGT_TX_1_P]
set_property -dict {PACKAGE_PIN M1} [get_ports MGT_TX_1_N]
set_property -dict {PACKAGE_PIN N4} [get_ports MGT_RX_1_P]
set_property -dict {PACKAGE_PIN N3} [get_ports MGT_RX_1_N]
# QSFP2-3/10, Bank 115 MGT 0, X0Y0
set_property -dict {PACKAGE_PIN P2} [get_ports MGT_TX_3_P]
set_property -dict {PACKAGE_PIN P1} [get_ports MGT_TX_3_N]
set_property -dict {PACKAGE_PIN R4} [get_ports MGT_RX_3_P]
set_property -dict {PACKAGE_PIN R3} [get_ports MGT_RX_3_N]
# QSFP2-4/9, Bank 115 MGT 3, X0Y3
set_property -dict {PACKAGE_PIN H2} [get_ports MGT_TX_4_P]
set_property -dict {PACKAGE_PIN H1} [get_ports MGT_TX_4_N]
set_property -dict {PACKAGE_PIN J4} [get_ports MGT_RX_4_P]
set_property -dict {PACKAGE_PIN J3} [get_ports MGT_RX_4_N]
