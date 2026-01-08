// SPDX-License-Identifier: MIT
// Module: csi2_tx_packetizer
// Description: Generates CSI-2 short/long packets from RAW8 AXI stream for Artix-7 XC7A35T.

module csi2_tx_packetizer #(
    parameter integer LINE_COUNT       = 16,
    parameter integer PAYLOAD_BYTES    = 512,
    parameter integer BLANK_CYCLES     = 10,
    parameter [1:0]  VIRTUAL_CHANNEL   = 2'd0
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start_frame,

    // RAW8 payload stream (from packer)
    input  wire [7:0]  pixel_axis_tdata,
    input  wire        pixel_axis_tvalid,
    output wire        pixel_axis_tready,
    input  wire        pixel_axis_tlast,

    // CSI-2 byte stream toward PHY/D-PHY serializer
    output reg  [7:0]  m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg         m_axis_tlast,
    output reg         m_axis_tuser
);

    localparam [7:0] DATA_ID_FS = {VIRTUAL_CHANNEL, 6'h00};
    localparam [7:0] DATA_ID_LS = {VIRTUAL_CHANNEL, 6'h02};
    localparam [7:0] DATA_ID_FE = {VIRTUAL_CHANNEL, 6'h01};
    localparam [7:0] DATA_ID_RAW8 = {VIRTUAL_CHANNEL, 6'h2A};

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_FS,
        ST_LS,
        ST_PAYLOAD,
        ST_FE,
        ST_BLANK
    } state_t;

    state_t state_q, state_d;
    logic [1:0] header_idx_q, header_idx_d;
    logic [15:0] frame_counter_q;
    logic [15:0] line_counter_q;
    logic [9:0]  blank_cnt_q;

    // Payload bookkeeping
    logic [15:0] payload_byte_cnt_q;
    logic        payload_done;

    assign pixel_axis_tready = (state_q == ST_PAYLOAD) ? m_axis_tready : 1'b0;
    assign payload_done = (pixel_axis_tvalid && pixel_axis_tready && pixel_axis_tlast);

    // Header generation helper
    logic [7:0] header_byte;
    always @(*) begin
        header_byte = 8'h00;
        case (state_q)
            ST_FS: begin
                case (header_idx_q)
                    2'd0: header_byte = DATA_ID_FS;
                    2'd1: header_byte = frame_counter_q[7:0];
                    2'd2: header_byte = frame_counter_q[15:8];
                    default: header_byte = 8'h00; // ECC placeholder (TODO)
                endcase
            end
            ST_LS: begin
                case (header_idx_q)
                    2'd0: header_byte = DATA_ID_LS;
                    2'd1: header_byte = line_counter_q[7:0];
                    2'd2: header_byte = line_counter_q[15:8];
                    default: header_byte = 8'h00; // ECC placeholder (TODO)
                endcase
            end
            ST_FE: begin
                case (header_idx_q)
                    2'd0: header_byte = DATA_ID_FE;
                    2'd1: header_byte = frame_counter_q[7:0];
                    2'd2: header_byte = frame_counter_q[15:8];
                    default: header_byte = 8'h00; // ECC placeholder (TODO)
                endcase
            end
            default: header_byte = 8'h00;
        endcase
    end

    // State machine
    always @(*) begin
        state_d      = state_q;
        header_idx_d = header_idx_q;
        case (state_q)
            ST_IDLE: begin
                if (start_frame) begin
                    state_d      = ST_FS;
                    header_idx_d = 2'd0;
                end
            end
            ST_FS: begin
                if (m_axis_tvalid && m_axis_tready) begin
                    if (header_idx_q == 2'd3) begin
                        state_d      = ST_LS;
                        header_idx_d = 2'd0;
                    end else begin
                        header_idx_d = header_idx_q + 1'b1;
                    end
                end
            end
            ST_LS: begin
                if (m_axis_tvalid && m_axis_tready) begin
                    if (header_idx_q == 2'd3) begin
                        state_d      = ST_PAYLOAD;
                        header_idx_d = 2'd0;
                    end else begin
                        header_idx_d = header_idx_q + 1'b1;
                    end
                end
            end
            ST_PAYLOAD: begin
                if (payload_done) begin
                    if (line_counter_q + 1 < LINE_COUNT) begin
                        state_d = ST_BLANK;
                    end else begin
                        state_d = ST_FE;
                        header_idx_d = 2'd0;
                    end
                end
            end
            ST_FE: begin
                if (m_axis_tvalid && m_axis_tready) begin
                    if (header_idx_q == 2'd3) begin
                        state_d = ST_BLANK;
                    end else begin
                        header_idx_d = header_idx_q + 1'b1;
                    end
                end
            end
            ST_BLANK: begin
                if (blank_cnt_q == BLANK_CYCLES-1) begin
                    if (line_counter_q + 1 < LINE_COUNT) begin
                        state_d = ST_LS;
                        header_idx_d = 2'd0;
                    end else begin
                        state_d = ST_IDLE;
                    end
                end
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q            <= ST_IDLE;
            header_idx_q       <= 2'd0;
            frame_counter_q    <= 16'd0;
            line_counter_q     <= 16'd0;
            blank_cnt_q        <= 10'd0;
            payload_byte_cnt_q <= 16'd0;
            m_axis_tdata       <= 8'd0;
            m_axis_tvalid      <= 1'b0;
            m_axis_tlast       <= 1'b0;
            m_axis_tuser       <= 1'b0;
        end else begin
            state_q      <= state_d;
            header_idx_q <= header_idx_d;

            // Frame counter increments after FE completes
            if (state_q == ST_FE && state_d == ST_BLANK && (line_counter_q + 1 == LINE_COUNT)) begin
                frame_counter_q <= frame_counter_q + 1'b1;
            end

            // Line counter updates
            if (state_q == ST_PAYLOAD && payload_done) begin
                line_counter_q <= line_counter_q + 1'b1;
            end else if (state_q == ST_IDLE) begin
                line_counter_q <= 16'd0;
            end

            // Blanking counter
            if (state_q == ST_BLANK) begin
                if (blank_cnt_q == BLANK_CYCLES-1) begin
                    blank_cnt_q <= 10'd0;
                end else begin
                    blank_cnt_q <= blank_cnt_q + 1'b1;
                end
            end else begin
                blank_cnt_q <= 10'd0;
            end

            // Payload byte counter
            if (state_q == ST_PAYLOAD && pixel_axis_tvalid && pixel_axis_tready) begin
                payload_byte_cnt_q <= payload_byte_cnt_q + 1'b1;
            end else if (state_q != ST_PAYLOAD) begin
                payload_byte_cnt_q <= 16'd0;
            end

            // Output control
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tuser  <= 1'b0;

            if (state_q == ST_FS || state_q == ST_LS || state_q == ST_FE) begin
                m_axis_tdata  <= (header_idx_q == 2'd3) ? 8'h00 : header_byte; // ECC placeholder
                m_axis_tvalid <= 1'b1;
                if (state_q == ST_FS && header_idx_q == 2'd0) begin
                    m_axis_tuser <= 1'b1;
                end
                if (state_q == ST_FE && header_idx_q == 2'd3) begin
                    m_axis_tlast <= 1'b1;
                end
            end else if (state_q == ST_PAYLOAD) begin
                m_axis_tdata  <= pixel_axis_tdata;
                m_axis_tvalid <= pixel_axis_tvalid;
                m_axis_tuser  <= 1'b0;
                if (payload_done && (line_counter_q + 1 == LINE_COUNT)) begin
                    m_axis_tlast <= 1'b0; // FE will assert TLAST
                end
            end
        end
    end

endmodule
