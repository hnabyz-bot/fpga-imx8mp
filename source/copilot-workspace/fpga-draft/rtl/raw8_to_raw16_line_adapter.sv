// SPDX-License-Identifier: MIT
// Module: csi2_tx_raw8_to_raw16_adapter
// Description: Converts RAW8 AXI stream (frame-based TLAST) into RAW16 words with
//              explicit line boundaries for downstream line repeater logic.

module csi2_tx_raw8_to_raw16_adapter #(
    parameter integer WORDS_PER_LINE = 256,
    parameter integer LINE_COUNT     = 16
) (
    input  wire         clk,
    input  wire         rst_n,

    // RAW8 input (AXI4-Stream)
    input  wire [7:0]   s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire         s_axis_tlast,
    input  wire         s_axis_tuser,

    // RAW16 output with synthetic line TLAST
    output reg  [15:0]  m_axis_tdata,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
    output reg          m_axis_tlast,
    output reg          m_axis_tuser
);

    localparam integer WORD_CNT_WIDTH = $clog2(WORDS_PER_LINE);
    localparam integer LINE_CNT_WIDTH = $clog2(LINE_COUNT);

    reg [7:0]  byte_buffer_q;
    reg        byte_buffer_valid_q;
    reg        frame_start_pending_q;
    reg [WORD_CNT_WIDTH:0] word_cnt_q;
    reg [LINE_CNT_WIDTH:0] line_cnt_q;

    reg        m_axis_hold_q;

    assign s_axis_tready = (!m_axis_hold_q) &&
                           ( !byte_buffer_valid_q || (byte_buffer_valid_q && !m_axis_hold_q) );

    wire accept_byte = s_axis_tvalid && s_axis_tready;
    wire output_ready = m_axis_tvalid && !m_axis_tready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            byte_buffer_q        <= 8'd0;
            byte_buffer_valid_q  <= 1'b0;
            frame_start_pending_q<= 1'b0;
            word_cnt_q           <= { (WORD_CNT_WIDTH+1){1'b0} };
            line_cnt_q           <= { (LINE_CNT_WIDTH+1){1'b0} };
            m_axis_tdata         <= 16'd0;
            m_axis_tvalid        <= 1'b0;
            m_axis_tlast         <= 1'b0;
            m_axis_tuser         <= 1'b0;
            m_axis_hold_q        <= 1'b0;
        end else begin
            // Default
            if (m_axis_tvalid && m_axis_tready) begin
                m_axis_tvalid <= 1'b0;
                m_axis_hold_q <= 1'b0;
            end

            if (accept_byte) begin
                if (!byte_buffer_valid_q) begin
                    byte_buffer_q        <= s_axis_tdata;
                    byte_buffer_valid_q  <= 1'b1;
                    if (s_axis_tuser) begin
                        frame_start_pending_q <= 1'b1;
                    end
                end else if (!m_axis_hold_q) begin
                    // Form 16-bit word (LSB first)
                    m_axis_tdata  <= {s_axis_tdata, byte_buffer_q};
                    m_axis_tvalid <= 1'b1;
                    m_axis_hold_q <= 1'b1;
                    m_axis_tuser  <= frame_start_pending_q;
                    m_axis_tlast  <= (word_cnt_q == WORDS_PER_LINE-1);

                    byte_buffer_valid_q  <= 1'b0;
                    frame_start_pending_q<= 1'b0;

                    if (word_cnt_q == WORDS_PER_LINE-1) begin
                        word_cnt_q <= { (WORD_CNT_WIDTH+1){1'b0} };
                        if (line_cnt_q == LINE_COUNT-1) begin
                            line_cnt_q <= { (LINE_CNT_WIDTH+1){1'b0} };
                        end else begin
                            line_cnt_q <= line_cnt_q + 1'b1;
                        end
                    end else begin
                        word_cnt_q <= word_cnt_q + 1'b1;
                    end
                end
            end
        end
    end

endmodule
