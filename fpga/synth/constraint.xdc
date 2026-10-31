set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS33 } [get_ports { clk_i }];
create_clock -period 10.000 -name clk_i -waveform {0.000 5.000} [get_ports { clk_i }];

set_property -dict { PACKAGE_PIN K18 IOSTANDARD LVCMOS33 } [get_ports { rst_n_i }];

set_property -dict { PACKAGE_PIN V8  IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[0] }];
set_property -dict { PACKAGE_PIN W8  IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[1] }];
set_property -dict { PACKAGE_PIN U7  IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[2] }];
set_property -dict { PACKAGE_PIN V7  IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[3] }];
set_property -dict { PACKAGE_PIN Y7  IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[4] }];
set_property -dict { PACKAGE_PIN Y8  IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[5] }];
set_property -dict { PACKAGE_PIN V6  IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[6] }];
set_property -dict { PACKAGE_PIN W6  IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[7] }];

set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[8] }];
set_property -dict { PACKAGE_PIN W15 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[9] }];
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[10] }];
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[11] }];
set_property -dict { PACKAGE_PIN W14 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[12] }];
set_property -dict { PACKAGE_PIN Y14 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[13] }];
set_property -dict { PACKAGE_PIN T12 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[14] }];
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[15] }];

set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[16] }];
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[17] }];
set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[18] }];
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[19] }];
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[20] }];
set_property -dict { PACKAGE_PIN U15 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[21] }];
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[22] }];
set_property -dict { PACKAGE_PIN V18 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[23] }];

set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[24] }];
set_property -dict { PACKAGE_PIN W16 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[25] }];
set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[26] }];
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[27] }];
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[28] }];
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[29] }];
set_property -dict { PACKAGE_PIN T17 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[30] }];
set_property -dict { PACKAGE_PIN Y17 IOSTANDARD LVCMOS33 } [get_ports { out_accum_o[31] }];