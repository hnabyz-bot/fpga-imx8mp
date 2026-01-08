/*******************************************************************************
 * Module: data_pack_16to8
 * Purpose: Convert 16-bit data to 8-bit RAW8 format (Little Endian)
 *
 * Description:
 *   - Input: 256 words × 16-bit = 512 bytes
 *   - Output: 512 bytes RAW8 (Little Endian: 0xABCD → [0xCD, 0xAB])
 *   - AXI4-Stream interface with handshake (TVALID && TREADY)
 *   - Supports backpressure and flow control
 *
 * Constraints:
 *   - Memory alignment: 512 bytes (64-byte aligned) ✓
 *   - Endian: Little Endian (LSB first)
 *   - TLAST: High at last byte (byte 511)
 *   - TUSER[0]: High at frame start (byte 0)
 *
 * Author: Claude (Xilinx FPGA Expert)
 * Date: 2026-01-07
 *******************************************************************************/

`timescale 1ns / 1ps

module data_pack_16to8 #(
    parameter DATA_WIDTH = 256,        // Number of 16-bit words
    parameter BYTE_WIDTH = 512         // Number of output bytes (DATA_WIDTH * 2)
) (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Input: 16-bit data interface
    input  wire        s_valid,
    output wire        s_ready,
    input  wire [15:0] s_data,
    input  wire        s_last,         // Last word of frame
    input  wire        s_user,         // Frame start indicator

    // Output: AXI4-Stream 8-bit RAW8
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg  [7:0]  m_axis_tdata,
    output reg         m_axis_tlast,
    output reg         m_axis_tuser
);

    //==========================================================================
    // Internal Signals
    //==========================================================================
    reg  [15:0] data_reg;              // Register to hold 16-bit data
    reg         byte_sel;              // 0: LSB, 1: MSB
    reg         frame_active;
    reg  [9:0]  byte_counter;          // 0~511
    reg         input_consumed;

    wire        handshake_in;
    wire        handshake_out;
    wire        is_first_byte;
    wire        is_last_byte;

    //==========================================================================
    // Handshake Signals
    //==========================================================================
    assign handshake_in  = s_valid && s_ready;
    assign handshake_out = m_axis_tvalid && m_axis_tready;

    assign is_first_byte = (byte_counter == 10'd0);
    assign is_last_byte  = (byte_counter == 10'd511);

    // Ready when we can accept new data (either idle or MSB byte consumed)
    assign s_ready = !frame_active || (frame_active && byte_sel && handshake_out);

    //==========================================================================
    // FSM: Data Packing (16-bit → 2 × 8-bit)
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg       <= 16'h0;
            byte_sel       <= 1'b0;
            frame_active   <= 1'b0;
            byte_counter   <= 10'd0;
            m_axis_tvalid  <= 1'b0;
            m_axis_tdata   <= 8'h0;
            m_axis_tlast   <= 1'b0;
            m_axis_tuser   <= 1'b0;
            input_consumed <= 1'b0;
        end else begin
            // Default: keep state
            input_consumed <= 1'b0;

            // State: IDLE → ACTIVE
            if (!frame_active && s_valid && s_user) begin
                frame_active  <= 1'b1;
                data_reg      <= s_data;
                byte_sel      <= 1'b0;
                byte_counter  <= 10'd0;
                m_axis_tvalid <= 1'b1;
                m_axis_tdata  <= s_data[7:0];    // Little Endian: LSB first
                m_axis_tlast  <= 1'b0;
                m_axis_tuser  <= 1'b1;           // Frame start
                input_consumed <= 1'b1;
            end
            // State: ACTIVE
            else if (frame_active) begin
                if (handshake_out) begin
                    m_axis_tuser <= 1'b0;        // Clear after first byte

                    // LSB byte sent, switch to MSB
                    if (!byte_sel) begin
                        byte_sel      <= 1'b1;
                        m_axis_tdata  <= data_reg[15:8];  // MSB
                        m_axis_tlast  <= is_last_byte;
                        byte_counter  <= byte_counter + 1'b1;
                    end
                    // MSB byte sent, fetch new 16-bit word
                    else begin
                        byte_sel      <= 1'b0;
                        byte_counter  <= byte_counter + 1'b1;

                        // Check if frame complete
                        if (is_last_byte) begin
                            frame_active  <= 1'b0;
                            m_axis_tvalid <= 1'b0;
                            m_axis_tlast  <= 1'b0;
                        end
                        // Fetch next word if available
                        else if (s_valid) begin
                            data_reg      <= s_data;
                            m_axis_tdata  <= s_data[7:0];
                            m_axis_tlast  <= 1'b0;
                            input_consumed <= 1'b1;
                        end
                        // Wait for input
                        else begin
                            m_axis_tvalid <= 1'b0;
                        end
                    end
                end
                // Backpressure: hold current state
                else begin
                    // No change
                end
            end
        end
    end

    //==========================================================================
    // Assertions (for simulation)
    //==========================================================================
    `ifdef SIMULATION
        // Check alignment: 512 % 64 = 0 ✓
        initial begin
            if (BYTE_WIDTH % 64 != 0) begin
                $error("[data_pack_16to8] Memory alignment violation: %0d %% 64 != 0", BYTE_WIDTH);
            end
            $display("[data_pack_16to8] Configuration:");
            $display("  - Input: %0d × 16-bit words", DATA_WIDTH);
            $display("  - Output: %0d bytes RAW8 (Little Endian)", BYTE_WIDTH);
            $display("  - Alignment: %0d %% 64 = 0 ✓", BYTE_WIDTH);
        end

        // Protocol check: TVALID && TREADY handshake
        always @(posedge clk) begin
            if (m_axis_tvalid && !m_axis_tready && $past(m_axis_tvalid) && $past(m_axis_tready)) begin
                $warning("[data_pack_16to8] TVALID changed during backpressure (may violate AXI)");
            end
        end
    `endif

endmodule
