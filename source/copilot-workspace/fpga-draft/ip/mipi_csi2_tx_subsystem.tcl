# SPDX-License-Identifier: MIT
# Vivado TCL script to configure the Xilinx MIPI CSI-2 TX Subsystem
# Target device: Xilinx Artix-7 XC7A35T-FFG484-1
# Spec:
#   - 4 data lanes + 1 clock lane
#   - RAW8 (Data Type 0x2A)
#   - D-PHY timing derived for 1.0 Gbps data rate (UI = 1 ns)
#     * tCLK-PREPARE = 70 ns  (spec range 38~95 ns)
#     * tCLK-ZERO    = 280 ns (spec range 262~300 ns)
#     * tHS-PREPARE  = 60 ns + 4*UI = 64 ns (spec range 40~85 ns + 4*UI)
#     * tHS-ZERO     = 150 ns + 10*UI = 160 ns (spec range 145~255 ns + 10*UI)
#   These values satisfy the MIPI D-PHY v1.2 window for the chosen data rate.

set part_name "xc7a35tffg484-1"
set project_name "mipi_csi2_tx"
set output_dir   "./vivado_artifacts"

if {[file exists $output_dir] == 0} {
    file mkdir $output_dir
}

create_project $project_name $output_dir -part $part_name -force

create_ip -name mipi_csi2_tx_subsystem \
          -vendor xilinx.com \
          -library ip \
          -version 5.0 \
          -module_name mipi_csi2_tx_subsystem_0

set_property -dict [list \
    CONFIG.DPHY_LANES           {4}         \
    CONFIG.PXL_FORMAT           {RAW8}      \
    CONFIG.PXL_WIDTH            {8}         \
    CONFIG.DT                   {0x2A}      \
    CONFIG.BIT_RATE             {1000.0}    \
    CONFIG.CLOCK_MODE           {HS_ONLY}   \
    CONFIG.VIRTUAL_CHANNEL      {0}         \
    CONFIG.LINE_COUNT           {16}        \
    CONFIG.WORD_COUNT           {512}       \
    CONFIG.TCLK_PREPARE         {70.0}      \
    CONFIG.TCLK_ZERO            {280.0}     \
    CONFIG.THS_PREPARE          {64.0}      \
    CONFIG.THS_ZERO             {160.0}     \
    CONFIG.ADDR_WIDTH           {13}        \
    CONFIG.AXI4S_DATA_WIDTH     {8}         \
    CONFIG.INSERT_HEADER        {true}      \
    CONFIG.CRC_OPTION           {false}     \
    CONFIG.ECC_OPTION           {false}     \
    CONFIG.DBG_EN               {false}     \
    CONFIG.CIL_STATIC_CFG       {true}      \
    CONFIG.SHUTDOWN_ENABLE      {true}      \
    CONFIG.LPDT_SUPPORT         {false}     \
    CONFIG.DPHY_RST_CTRL        {true}      \
    CONFIG.TX_PLL_REFCLK        {100.0}]    \
    [get_ips mipi_csi2_tx_subsystem_0]

# Timing sanity check outputs
tclapp::xilinx::designutils::report_property -regexp {CONFIG\.(TCLK|THS).*} \
    [get_ips mipi_csi2_tx_subsystem_0]

# Generate example XDC stub for pin planning
set xdc_path "$output_dir/mipi_csi2_tx_subsystem_0.xdc"
set fp [open $xdc_path w]
puts $fp "# Clock lane"
puts $fp "set_property PACKAGE_PIN AA12 [get_ports mipi_clk_p]"
puts $fp "set_property PACKAGE_PIN AB12 [get_ports mipi_clk_n]"
puts $fp "# Data lanes"
for {set lane 0} {$lane < 4} {incr lane} {
    puts $fp "set_property PACKAGE_PIN <DATA${lane}_P> [get_ports {mipi_data_p[$lane]}]"
    puts $fp "set_property PACKAGE_PIN <DATA${lane}_N> [get_ports {mipi_data_n[$lane]}]"
}
close $fp

# Generate output products so that HDL wrappers can reference the IP
set_property generate_synth_checkpoint false [get_files mipi_csi2_tx_subsystem_0.xci]
generate_target all [get_ips mipi_csi2_tx_subsystem_0]
export_ip_user_files -of_objects [get_ips mipi_csi2_tx_subsystem_0] -no_script -force -quiet

puts "INFO: MIPI CSI-2 TX Subsystem configured successfully."
