# SPDX-License-Identifier: MIT
# Vivado TCL script to configure the discrete Xilinx MIPI D-PHY (TX mode)
# Target device: Xilinx Artix-7 XC7A35T-FFG484-1
# Purpose: Replace the behavioral dphy stub in rtl/csi2_tx_top.sv with a
#          production-ready IP core. Run this script inside Vivado's tcl shell
#          (vivado -mode tcl -source mipi_dphy_tx_core.tcl).

set part_name     "xc7a35tffg484-1"
set project_name  "mipi_dphy_tx"
set output_dir    "./vivado_artifacts"

if {[file exists $output_dir] == 0} {
    file mkdir $output_dir
}

create_project $project_name $output_dir -part $part_name -force

create_ip -name mipi_dphy \
          -vendor xilinx.com \
          -library ip \
          -version 4.3 \
          -module_name mipi_dphy_tx_0

# Core configuration
# NOTE: Property names follow Vivado 2023.2 documentation. Adjust if a newer
# Vivado release renames any field.
set_property -dict [list \
    CONFIG.C_DPHY_MODE          {TX}        \
    CONFIG.C_DPHY_LANES         {4}         \
    CONFIG.C_DPHY_CLK_MODE      {HS_ONLY}   \
    CONFIG.C_TX_LINE_RATE       {1000.0}    \
    CONFIG.C_TX_REFCLK_FREQ     {100.0}     \
    CONFIG.C_ENABLE_LP          {true}      \
    CONFIG.C_ENABLE_ULPS        {false}     \
    CONFIG.C_EN_HS_MIPI_CLK     {true}      \
    CONFIG.C_EN_HS_DATA_LANES   {true}      \
    CONFIG.C_ESC_CLK_PERIOD     {100.0}     \
    CONFIG.C_TX_ESC_CLK         {10.0}      \
    CONFIG.C_DPHY_PLL_SOURCE    {REFCLK}    \
    CONFIG.C_HS_TIMEOUT         {1024}      \
    CONFIG.C_LPX_PERIOD         {50.0}      \
    CONFIG.C_THS_PRE            {64.0}      \
    CONFIG.C_THS_ZERO           {160.0}     \
    CONFIG.C_TCLK_PRE           {70.0}      \
    CONFIG.C_TCLK_ZERO          {280.0}     \
    CONFIG.C_TCLK_POST          {60.0}      \
    CONFIG.C_TCLK_TRAIL         {60.0}      \
    CONFIG.C_THS_TRAIL          {70.0}      \
    CONFIG.C_ENABLE_CALIB       {true}      \
    CONFIG.C_ENABLE_DEBUG       {false}]    \
    [get_ips mipi_dphy_tx_0]

# Drop a minimal XDC template for pin planning / clock constraints
set xdc_path "$output_dir/mipi_dphy_tx_0.xdc"
set fp [open $xdc_path w]
puts $fp "# Clock lane"
puts $fp "set_property PACKAGE_PIN AA12 [get_ports mipi_tx_clk_p]"
puts $fp "set_property PACKAGE_PIN AB12 [get_ports mipi_tx_clk_n]"
puts $fp "set_property IOSTANDARD DIFF_MIPI_DPHY [get_ports {mipi_tx_clk_p mipi_tx_clk_n}]"
puts $fp ""
puts $fp "# Data lanes"
for {set lane 0} {$lane < 4} {incr lane} {
    puts $fp "set_property PACKAGE_PIN <DATA${lane}_P> [get_ports {mipi_tx_data_p[$lane]}]"
    puts $fp "set_property PACKAGE_PIN <DATA${lane}_N> [get_ports {mipi_tx_data_n[$lane]}]"
    puts $fp "set_property IOSTANDARD DIFF_MIPI_DPHY [get_ports {mipi_tx_data_p[$lane] mipi_tx_data_n[$lane]}]"
    puts $fp ""
}
close $fp

set_property generate_synth_checkpoint false [get_files mipi_dphy_tx_0.xci]
generate_target all [get_ips mipi_dphy_tx_0]
export_ip_user_files -of_objects [get_ips mipi_dphy_tx_0] -no_script -force -quiet

puts "INFO: MIPI D-PHY TX core configured successfully."
