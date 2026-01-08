// SPDX-License-Identifier: MIT
// Module: csi2_tx_top
// Description: Complete RAW16 → CSI-2 → 4-lane D-PHY transmitter for XC7A35T.

module csi2_tx_top #(
    parameter integer WORDS_PER_LINE = 256,
    parameter integer LINE_COUNT     = 16,
    parameter integer BLANK_CYCLES   = 10
) (
    input  wire        clk,
    input  wire        rst_n,

    // RAW8 AXI4-Stream input (frame-based TLAST, TUSER=frame start)
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire [7:0]  s_axis_tdata,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tuser,

    // Differential MIPI outputs (stubbed)
    output wire        mipi_clk_p,
    output wire        mipi_clk_n,
    output wire [3:0]  mipi_data_p,
    output wire [3:0]  mipi_data_n
);

    //======================================================================
    // Frame request detection (AXI TUSER edge)
    //======================================================================
    reg tuser_seen_q;
    wire tuser_candidate = s_axis_tuser && s_axis_tvalid;
    wire frame_req_pulse = tuser_candidate && !tuser_seen_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tuser_seen_q <= 1'b0;
        end else if (frame_start_pulse) begin
            tuser_seen_q <= 1'b0;
        end else if (tuser_candidate) begin
            tuser_seen_q <= 1'b1;
        end else begin
            tuser_seen_q <= 1'b0;
        end
    end

    //======================================================================
    // Controller orchestrating capture/stream
    //======================================================================
    wire capture_enable;
    wire frame_busy;
    wire frame_ack_pulse;
    wire frame_start_pulse;
    wire frame_active;
    wire frame_done_pulse;

    csi2_tx_frame_ctrl u_tx_ctrl (
        .clk              (clk),
        .rst_n            (rst_n),
        .frame_req_pulse  (frame_req_pulse),
        .frame_start_pulse(frame_start_pulse),
        .frame_active     (frame_active),
        .frame_done_pulse (frame_done_pulse),
        .capture_enable   (capture_enable),
        .frame_busy       (frame_busy),
        .frame_ack_pulse  (frame_ack_pulse)
    );

    //======================================================================
    // RAW8 → RAW16 line adapter (synth line TLAST)
    //======================================================================
    wire        sensor_tvalid = capture_enable ? s_axis_tvalid : 1'b0;
    wire        sensor_tready;
    assign s_axis_tready = capture_enable ? sensor_tready : 1'b0;

    wire [15:0] adapter_tdata;
    wire        adapter_tvalid;
    wire        adapter_tlast;
    wire        adapter_tuser;
    wire        adapter_tready;

    csi2_tx_raw8_to_raw16_adapter #(
        .WORDS_PER_LINE (WORDS_PER_LINE),
        .LINE_COUNT     (LINE_COUNT)
    ) u_raw8_to_raw16 (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (sensor_tvalid),
        .s_axis_tready  (sensor_tready),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tuser   (s_axis_tuser),
        .m_axis_tdata   (adapter_tdata),
        .m_axis_tvalid  (adapter_tvalid),
        .m_axis_tready  (adapter_tready),
        .m_axis_tlast   (adapter_tlast),
        .m_axis_tuser   (adapter_tuser)
    );

    // Alias adapter outputs
    wire [15:0] dp_s_axis_tdata  = adapter_tdata;
    wire        dp_s_axis_tvalid = adapter_tvalid;
    wire        dp_s_axis_tready;
    wire        dp_s_axis_tlast  = adapter_tlast;
    wire        dp_s_axis_tuser  = adapter_tuser;

    assign adapter_tready = dp_s_axis_tready;

    //======================================================================
    // Datapath: line repeat + RAW8 packing + CSI-2 packetizer
    //======================================================================
    wire [7:0]  byte_stream_tdata;
    wire        byte_stream_tvalid;
    wire        byte_stream_tready;
    wire        byte_stream_tlast;
    wire        byte_stream_tuser;

    csi2_tx_datapath #(
        .WORDS_PER_LINE (WORDS_PER_LINE),
        .LINE_REPEAT    (LINE_COUNT),
        .BLANK_CYCLES   (BLANK_CYCLES)
    ) u_mipi_csi2_tx_datapath (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (dp_s_axis_tdata),
        .s_axis_tvalid  (dp_s_axis_tvalid),
        .s_axis_tready  (dp_s_axis_tready),
        .s_axis_tlast   (dp_s_axis_tlast),
        .s_axis_tuser   (dp_s_axis_tuser),
        .frame_start    (frame_start_pulse),
        .frame_active   (frame_active),
        .frame_done     (frame_done_pulse),
        .m_axis_tdata   (byte_stream_tdata),
        .m_axis_tvalid  (byte_stream_tvalid),
        .m_axis_tready  (byte_stream_tready),
        .m_axis_tlast   (byte_stream_tlast),
        .m_axis_tuser   (byte_stream_tuser)
    );

    //======================================================================
    // Simplified D-PHY serializer
    //======================================================================
    csi2_tx_dphy_stub u_csi2_tx_dphy_stub (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (byte_stream_tdata),
        .s_axis_tvalid  (byte_stream_tvalid),
        .s_axis_tready  (byte_stream_tready),
        .s_axis_tlast   (byte_stream_tlast),
        .s_axis_tuser   (byte_stream_tuser),
        .mipi_clk_p     (mipi_clk_p),
        .mipi_clk_n     (mipi_clk_n),
        .mipi_data_p    (mipi_data_p),
        .mipi_data_n    (mipi_data_n)
    );

endmodule
