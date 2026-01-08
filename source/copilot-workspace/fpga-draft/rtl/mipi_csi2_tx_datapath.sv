// SPDX-License-Identifier: MIT
// Module: csi2_tx_datapath
// Description: Connects RAW16 input stream to CSI-2 packetizer through
//              line repetition and RAW8 packing for 4-lane transmission.

module csi2_tx_datapath #(
    parameter integer WORDS_PER_LINE = 256,
    parameter integer LINE_REPEAT    = 16,
    parameter integer BLANK_CYCLES   = 10,
    parameter [1:0]  VIRTUAL_CHANNEL = 2'd0
) (
    input  wire         clk,
    input  wire         rst_n,

    // RAW16 input (one physical line per frame)
    input  wire [15:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire         s_axis_tlast,
    input  wire         s_axis_tuser,

    // Status
    output wire         frame_start,
    output wire         frame_active,
    output wire         frame_done,

    // Byte stream output toward D-PHY TX
    output wire [7:0]   m_axis_tdata,
    output wire         m_axis_tvalid,
    input  wire         m_axis_tready,
    output wire         m_axis_tlast,
    output wire         m_axis_tuser
);

    localparam integer PAYLOAD_BYTES = WORDS_PER_LINE * 2;

    // ------------------------------------------------------------------
    // Line repetition (RAW16)
    // ------------------------------------------------------------------
    wire [15:0] repeat_tdata;
    wire        repeat_tvalid;
    wire        repeat_tready;
    wire        repeat_tlast;
    wire        repeat_tuser;
    wire        repeat_start_pulse;

    csi2_tx_line_repeater #(
        .WORDS_PER_LINE (WORDS_PER_LINE),
        .LINE_REPEAT    (LINE_REPEAT)
    ) u_line_repeater (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tuser   (s_axis_tuser),
        .m_axis_tdata   (repeat_tdata),
        .m_axis_tvalid  (repeat_tvalid),
        .m_axis_tready  (repeat_tready),
        .m_axis_tlast   (repeat_tlast),
        .m_axis_tuser   (repeat_tuser),
        .repeat_active  (frame_active),
        .repeat_start   (repeat_start_pulse),
        .repeat_done    (frame_done)
    );

    assign frame_start = repeat_start_pulse;

    // ------------------------------------------------------------------
    // RAW16 -> RAW8 packing
    // ------------------------------------------------------------------
    wire [7:0] packer_tdata;
    wire       packer_tvalid;
    wire       packer_tready;
    wire       packer_tlast;
    wire       packer_tuser;

    csi2_tx_raw16_to_raw8_packer #(
        .WORDS_PER_LINE (WORDS_PER_LINE)
    ) u_raw16_to_raw8_packer (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (repeat_tdata),
        .s_axis_tvalid  (repeat_tvalid),
        .s_axis_tready  (repeat_tready),
        .s_axis_tlast   (repeat_tlast),
        .s_axis_tuser   (repeat_tuser),
        .m_axis_tdata   (packer_tdata),
        .m_axis_tvalid  (packer_tvalid),
        .m_axis_tready  (packer_tready),
        .m_axis_tlast   (packer_tlast),
        .m_axis_tuser   (packer_tuser)
    );

    // ------------------------------------------------------------------
    // CSI-2 packet generation
    // ------------------------------------------------------------------
    csi2_tx_packetizer #(
        .LINE_COUNT     (LINE_REPEAT),
        .PAYLOAD_BYTES  (PAYLOAD_BYTES),
        .BLANK_CYCLES   (BLANK_CYCLES),
        .VIRTUAL_CHANNEL(VIRTUAL_CHANNEL)
    ) u_mipi_csi2_tx_packetizer (
        .clk                (clk),
        .rst_n              (rst_n),
        .start_frame        (repeat_start_pulse),
        .pixel_axis_tdata   (packer_tdata),
        .pixel_axis_tvalid  (packer_tvalid),
        .pixel_axis_tready  (packer_tready),
        .pixel_axis_tlast   (packer_tlast),
        .m_axis_tdata       (m_axis_tdata),
        .m_axis_tvalid      (m_axis_tvalid),
        .m_axis_tready      (m_axis_tready),
        .m_axis_tlast       (m_axis_tlast),
        .m_axis_tuser       (m_axis_tuser)
    );

endmodule
