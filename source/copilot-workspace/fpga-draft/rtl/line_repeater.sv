// SPDX-License-Identifier: MIT
// Module: csi2_tx_line_repeater
// Description: Captures a single RAW16 line and replays it LINE_REPEAT times
//              to satisfy i.MX8MP minimum line-count requirements.

module csi2_tx_line_repeater #(
    parameter integer WORDS_PER_LINE = 256,
    parameter integer LINE_REPEAT    = 16
) (
    input  wire         clk,
    input  wire         rst_n,

    // Input line (RAW16 AXI4-Stream)
    input  wire [15:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire         s_axis_tlast,
    input  wire         s_axis_tuser,

    // Output repeated lines (RAW16 AXI4-Stream)
    output reg  [15:0]  m_axis_tdata,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
    output reg          m_axis_tlast,
    output reg          m_axis_tuser,

    // Status
    output wire         repeat_active,
    output reg          repeat_start,
    output reg          repeat_done
);

    typedef enum logic [1:0] {
        ST_IDLE    = 2'd0,
        ST_CAPTURE = 2'd1,
        ST_REPEAT  = 2'd2
    } state_t;

    state_t state_q, state_d;

    logic [$clog2(WORDS_PER_LINE):0] write_idx_q, write_idx_d;
    logic [$clog2(WORDS_PER_LINE):0] read_idx_q,  read_idx_d;
    logic [$clog2(LINE_REPEAT):0]    repeat_cnt_q, repeat_cnt_d;
    logic                            frame_start_flag_q, frame_start_flag_d;

    logic [15:0] line_buffer [0:WORDS_PER_LINE-1];

    assign s_axis_tready = (state_q != ST_REPEAT);
    assign repeat_active = (state_q == ST_REPEAT);

    always @(*) begin
        state_d            = state_q;
        write_idx_d        = write_idx_q;
        read_idx_d         = read_idx_q;
        repeat_cnt_d       = repeat_cnt_q;
        frame_start_flag_d = frame_start_flag_q;

        case (state_q)
            ST_IDLE: begin
                write_idx_d = '0;
                if (s_axis_tvalid && s_axis_tready) begin
                    state_d            = s_axis_tlast ? ST_REPEAT : ST_CAPTURE;
                    write_idx_d        = s_axis_tlast ? '0 : write_idx_q + 1'b1;
                    read_idx_d         = '0;
                    repeat_cnt_d       = '0;
                    frame_start_flag_d = s_axis_tuser;
                end
            end

            ST_CAPTURE: begin
                if (s_axis_tvalid && s_axis_tready) begin
                    write_idx_d = s_axis_tlast ? '0 : (write_idx_q + 1'b1);
                    if (s_axis_tlast) begin
                        state_d      = ST_REPEAT;
                        read_idx_d   = '0;
                        repeat_cnt_d = '0;
                    end
                end
            end

            ST_REPEAT: begin
                if (m_axis_tvalid && m_axis_tready) begin
                    if (read_idx_q == WORDS_PER_LINE-1) begin
                        read_idx_d = '0;
                        if (repeat_cnt_q == LINE_REPEAT-1) begin
                            state_d            = ST_IDLE;
                            repeat_cnt_d       = '0;
                            frame_start_flag_d = 1'b0;
                        end else begin
                            repeat_cnt_d = repeat_cnt_q + 1'b1;
                        end
                    end else begin
                        read_idx_d = read_idx_q + 1'b1;
                    end
                end
            end

            default: state_d = ST_IDLE;
        endcase
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q            <= ST_IDLE;
            write_idx_q        <= '0;
            read_idx_q         <= '0;
            repeat_cnt_q       <= '0;
            frame_start_flag_q <= 1'b0;
            m_axis_tdata       <= 16'd0;
            m_axis_tvalid      <= 1'b0;
            m_axis_tlast       <= 1'b0;
            m_axis_tuser       <= 1'b0;
            repeat_start       <= 1'b0;
            repeat_done        <= 1'b0;
            for (i = 0; i < WORDS_PER_LINE; i = i + 1) begin
                line_buffer[i] <= 16'd0;
            end
        end else begin
            state_q            <= state_d;
            write_idx_q        <= write_idx_d;
            read_idx_q         <= read_idx_d;
            repeat_cnt_q       <= repeat_cnt_d;
            frame_start_flag_q <= frame_start_flag_d;
            repeat_start       <= (state_q != ST_REPEAT) && (state_d == ST_REPEAT);
            repeat_done        <= (state_q == ST_REPEAT) && (state_d == ST_IDLE);

            // Capture incoming line data
            if ((state_q == ST_IDLE || state_q == ST_CAPTURE) && s_axis_tvalid && s_axis_tready) begin
                line_buffer[write_idx_q] <= s_axis_tdata;
            end

            // Output control
            if (state_q == ST_REPEAT) begin
                m_axis_tdata  <= line_buffer[read_idx_q];
                m_axis_tvalid <= 1'b1;
                m_axis_tlast  <= (read_idx_q == WORDS_PER_LINE-1);
                m_axis_tuser  <= (repeat_cnt_q == 0) && (read_idx_q == 0) && frame_start_flag_q;
            end else begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
                m_axis_tuser  <= 1'b0;
            end
        end
    end

endmodule
