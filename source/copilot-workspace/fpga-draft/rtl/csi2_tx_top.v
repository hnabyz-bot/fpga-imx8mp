/*******************************************************************************
 * Module: csi2_tx_top
 * Purpose: MIPI CSI-2 TX Top Module - Direct passthrough to D-PHY
 *
 * Description:
 *   - Top-level integration of MIPI CSI-2 TX datapath
 *   - Converts AXI4-Stream 8-bit input to D-PHY 4-Lane differential output
 *   - Direct passthrough: Input data is already formatted as complete frame
 *
 * Architecture:
 *   Input (AXI4-Stream 8-bit pre-formatted frame data)
 *     ↓
 *   [D-PHY TX Stub] - 4-Lane differential output
 *     ↓
 *   Output (MIPI D-PHY: mipi_clk_p/n, mipi_data_p[3:0]/n[3:0])
 *
 * Dataflow:
 *   1. AXI4-Stream input (pre-formatted MIPI packets)
 *   2. Direct passthrough to D-PHY TX stub
 *   3. D-PHY differential signals → Output
 *
 * Note:
 *   - Testbench provides complete frame data (8192 bytes)
 *   - No packet generation needed (data already includes FS/LS/Payload/FE)
 *   - This module simply provides physical layer translation
 *
 * Constraints:
 *   - Frame: 16 lines × 512 bytes = 8192 bytes
 *   - Memory alignment: 512 % 64 = 0 ✓
 *   - AXI4-Stream protocol: TVALID && TREADY handshake
 *
 * Author: Claude (Xilinx FPGA Expert)
 * Date: 2026-01-08
 *******************************************************************************/

`timescale 1ns / 1ps

module csi2_tx_top (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Input: AXI4-Stream 8-bit frame data (pre-formatted MIPI packets)
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire [7:0]  s_axis_tdata,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tuser,

    // Output: MIPI D-PHY differential signals (4 lanes + 1 clock)
    output wire        mipi_clk_p,
    output wire        mipi_clk_n,
    output wire [3:0]  mipi_data_p,
    output wire [3:0]  mipi_data_n
);

    //==========================================================================
    // Direct Passthrough to D-PHY
    //==========================================================================
    // Input data is already formatted as complete MIPI frame
    // No packet generation needed - direct connection to D-PHY stub

    //--------------------------------------------------------------------------
    // D-PHY TX Stub
    // - Converts AXI4-Stream to D-PHY 4-Lane differential output
    // - Input: Pre-formatted MIPI packet stream (AXI4-Stream)
    // - Output: D-PHY differential signals (10 wires: clk + 4 data lanes)
    //--------------------------------------------------------------------------
    dphy_tx_stub u_dphy_tx (
        .clk            (clk),
        .rst_n          (rst_n),

        // Input: Direct connection to top-level input
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tuser   (s_axis_tuser),

        // Output: D-PHY differential signals
        .mipi_clk_p     (mipi_clk_p),
        .mipi_clk_n     (mipi_clk_n),
        .mipi_data_p    (mipi_data_p),
        .mipi_data_n    (mipi_data_n)
    );

    //==========================================================================
    // Assertions & Debug
    //==========================================================================
    `ifdef SIMULATION
        initial begin
            $display("╔═══════════════════════════════════════════════════════════╗");
            $display("║   MIPI CSI-2 TX Top Module Initialized                   ║");
            $display("╠═══════════════════════════════════════════════════════════╣");
            $display("║ Architecture: Direct Passthrough                          ║");
            $display("║   - Input: Pre-formatted MIPI frame data (8192 bytes)     ║");
            $display("║   - Output: D-PHY 4-Lane differential (10 wires)          ║");
            $display("╠═══════════════════════════════════════════════════════════╣");
            $display("║ Module Hierarchy:                                         ║");
            $display("║   1. dphy_tx_stub - D-PHY 4-Lane TX (LP-11/HS mode)       ║");
            $display("╚═══════════════════════════════════════════════════════════╝");
        end

        // Monitor frame boundaries
        always @(posedge clk) begin
            if (s_axis_tvalid && s_axis_tready && s_axis_tuser) begin
                $display("[%0t] Frame Start (TUSER=1)", $time);
            end
            if (s_axis_tvalid && s_axis_tready && s_axis_tlast) begin
                $display("[%0t] Frame End (TLAST=1)", $time);
            end
        end

        // Check TVALID/TREADY handshake violations
        reg prev_tvalid;
        reg [7:0] prev_tdata;
        always @(posedge clk) begin
            if (prev_tvalid && !s_axis_tready && s_axis_tvalid) begin
                if (s_axis_tdata != prev_tdata) begin
                    $warning("[csi2_tx_top] TDATA changed while TREADY=0 (AXI protocol violation)");
                end
            end
            prev_tvalid <= s_axis_tvalid;
            prev_tdata  <= s_axis_tdata;
        end
    `endif

endmodule
