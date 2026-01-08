/*******************************************************************************
 * Module: mipi_packet_gen
 * Purpose: Generate MIPI CSI-2 packets (FS, LS, Payload, FE)
 *
 * Description:
 *   - Generates Short Packets: FS (0x00), LS (0x02), FE (0x01)
 *   - Generates Long Packets: Payload (Data ID: 0x2A for RAW8)
 *   - Calculates ECC for Short Packets
 *   - Calculates CRC-16 for Long Packets
 *   - 16 lines per frame (minimum ISI requirement)
 *
 * Packet Structure:
 *   Short Packet (4 bytes): [Data ID][WC_LSB][WC_MSB][ECC]
 *   Long Packet (4+N+2): [Data ID][WC_LSB][WC_MSB][ECC][Payload...][CRC_LSB][CRC_MSB]
 *
 * Author: Claude (Xilinx FPGA Expert)
 * Date: 2026-01-07
 *******************************************************************************/

`timescale 1ns / 1ps

module mipi_packet_gen #(
    parameter PAYLOAD_SIZE = 512,      // 512 bytes per line
    parameter LINE_COUNT = 16          // 16 lines per frame
) (
    // Clock and Reset
    input  wire        clk,
    input  wire        rst_n,

    // Control
    input  wire        frame_start,    // Trigger new frame
    output reg         frame_active,
    output reg         frame_done,

    // Input: Payload data (AXI4-Stream)
    output reg         s_axis_tready,
    input  wire        s_axis_tvalid,
    input  wire [7:0]  s_axis_tdata,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tuser,

    // Output: MIPI packet stream (AXI4-Stream)
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready,
    output reg  [7:0]  m_axis_tdata,
    output reg         m_axis_tlast,
    output reg         m_axis_tuser
);

    //==========================================================================
    // FSM States
    //==========================================================================
    localparam [3:0] ST_IDLE       = 4'd0,
                     ST_FS         = 4'd1,   // Frame Start
                     ST_LS         = 4'd2,   // Line Start
                     ST_LONG_HDR   = 4'd3,   // Long Packet Header
                     ST_PAYLOAD    = 4'd4,   // Payload data
                     ST_CRC        = 4'd5,   // CRC footer
                     ST_BLANKING   = 4'd6,   // Inter-line blanking
                     ST_FE         = 4'd7;   // Frame End

    reg [3:0]  state, next_state;

    //==========================================================================
    // Packet Data
    //==========================================================================
    // Data IDs
    localparam [5:0] DI_FS     = 6'h00;  // Frame Start
    localparam [5:0] DI_FE     = 6'h01;  // Frame End
    localparam [5:0] DI_LS     = 6'h02;  // Line Start
    localparam [5:0] DI_RAW8   = 6'h2A;  // RAW8 Payload

    reg [7:0]  packet_data [0:3];        // 4-byte packet buffer
    reg [1:0]  byte_index;
    reg [15:0] word_count;
    reg [4:0]  line_number;              // 0~15
    reg [9:0]  payload_counter;          // 0~511
    reg [15:0] crc_value;
    reg [7:0]  blanking_counter;

    wire [7:0] ecc_result;
    wire       handshake_in, handshake_out;

    assign handshake_in  = s_axis_tvalid && s_axis_tready;
    assign handshake_out = m_axis_tvalid && m_axis_tready;

    //==========================================================================
    // ECC Calculation (Hamming Code for 24-bit header)
    //==========================================================================
    function [7:0] calc_ecc;
        input [23:0] data;
        reg [7:0] ecc;
        begin
            ecc[0] = data[0]  ^ data[1]  ^ data[2]  ^ data[4]  ^ data[5]  ^ data[7]  ^
                     data[10] ^ data[11] ^ data[13] ^ data[16] ^ data[20] ^ data[21] ^ data[23];
            ecc[1] = data[0]  ^ data[1]  ^ data[3]  ^ data[4]  ^ data[6]  ^ data[8]  ^
                     data[10] ^ data[12] ^ data[14] ^ data[17] ^ data[20] ^ data[22] ^ data[23];
            ecc[2] = data[0]  ^ data[2]  ^ data[3]  ^ data[5]  ^ data[6]  ^ data[9]  ^
                     data[11] ^ data[12] ^ data[15] ^ data[18] ^ data[21] ^ data[22] ^ data[23];
            ecc[3] = data[1]  ^ data[2]  ^ data[3]  ^ data[7]  ^ data[8]  ^ data[9]  ^
                     data[13] ^ data[14] ^ data[15] ^ data[19] ^ data[20] ^ data[21] ^ data[22];
            ecc[4] = data[4]  ^ data[5]  ^ data[6]  ^ data[7]  ^ data[12] ^ data[13] ^
                     data[14] ^ data[15] ^ data[16] ^ data[17] ^ data[18] ^ data[19];
            ecc[5] = data[10] ^ data[11] ^ data[12] ^ data[13] ^ data[14] ^ data[15] ^
                     data[16] ^ data[17] ^ data[18] ^ data[19] ^ data[20] ^ data[21] ^
                     data[22] ^ data[23];
            ecc[6] = 1'b0;
            ecc[7] = 1'b0;
            calc_ecc = ecc;
        end
    endfunction

    //==========================================================================
    // CRC-16 Calculation (MIPI CSI-2 CRC polynomial: 0x1021)
    //==========================================================================
    function [15:0] calc_crc16;
        input [15:0] crc;
        input [7:0]  data;
        reg [15:0] temp;
        integer i;
        begin
            temp = crc;
            for (i = 0; i < 8; i = i + 1) begin
                if (temp[15] ^ data[7-i])
                    temp = {temp[14:0], 1'b0} ^ 16'h1021;
                else
                    temp = {temp[14:0], 1'b0};
            end
            calc_crc16 = temp;
        end
    endfunction

    //==========================================================================
    // FSM: State Transition
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= ST_IDLE;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (frame_start)
                    next_state = ST_FS;
            end

            ST_FS: begin
                if (handshake_out && byte_index == 2'd3)
                    next_state = ST_LS;
            end

            ST_LS: begin
                if (handshake_out && byte_index == 2'd3)
                    next_state = ST_LONG_HDR;
            end

            ST_LONG_HDR: begin
                if (handshake_out && byte_index == 2'd3)
                    next_state = ST_PAYLOAD;
            end

            ST_PAYLOAD: begin
                if (handshake_out && payload_counter == PAYLOAD_SIZE-1)
                    next_state = ST_CRC;
            end

            ST_CRC: begin
                if (handshake_out && byte_index == 2'd1)
                    next_state = ST_BLANKING;
            end

            ST_BLANKING: begin
                if (blanking_counter >= 8'd10) begin  // 10 cycle blanking
                    if (line_number == LINE_COUNT-1)
                        next_state = ST_FE;
                    else
                        next_state = ST_LS;
                end
            end

            ST_FE: begin
                if (handshake_out && byte_index == 2'd3)
                    next_state = ST_IDLE;
            end

            default: next_state = ST_IDLE;
        endcase
    end

    //==========================================================================
    // FSM: Output Logic
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            frame_active    <= 1'b0;
            frame_done      <= 1'b0;
            s_axis_tready   <= 1'b0;
            m_axis_tvalid   <= 1'b0;
            m_axis_tdata    <= 8'h0;
            m_axis_tlast    <= 1'b0;
            m_axis_tuser    <= 1'b0;
            byte_index      <= 2'd0;
            line_number     <= 5'd0;
            payload_counter <= 10'd0;
            crc_value       <= 16'hFFFF;
            blanking_counter <= 8'd0;
        end else begin
            frame_done <= 1'b0;

            case (state)
                //--------------------------------------------------------------
                // IDLE: Wait for frame trigger
                //--------------------------------------------------------------
                ST_IDLE: begin
                    frame_active    <= 1'b0;
                    s_axis_tready   <= 1'b0;
                    m_axis_tvalid   <= 1'b0;
                    line_number     <= 5'd0;

                    if (frame_start) begin
                        frame_active <= 1'b1;
                    end
                end

                //--------------------------------------------------------------
                // FS: Frame Start Short Packet
                //--------------------------------------------------------------
                ST_FS: begin
                    if (byte_index == 2'd0) begin
                        // Prepare FS packet: [DI=0x00][Frame#=0][Frame#=0][ECC]
                        packet_data[0] <= {2'b00, DI_FS};
                        packet_data[1] <= 8'h00;
                        packet_data[2] <= 8'h00;
                        packet_data[3] <= calc_ecc({2'b00, DI_FS, 8'h00, 8'h00});

                        m_axis_tvalid <= 1'b1;
                        m_axis_tdata  <= {2'b00, DI_FS};
                        m_axis_tuser  <= 1'b1;   // SOF
                        m_axis_tlast  <= 1'b0;
                    end else if (handshake_out) begin
                        byte_index    <= byte_index + 1'b1;
                        m_axis_tdata  <= packet_data[byte_index + 1'b1];
                        m_axis_tuser  <= 1'b0;
                        m_axis_tlast  <= (byte_index == 2'd2);

                        if (byte_index == 2'd3)
                            byte_index <= 2'd0;
                    end
                end

                //--------------------------------------------------------------
                // LS: Line Start Short Packet
                //--------------------------------------------------------------
                ST_LS: begin
                    if (byte_index == 2'd0) begin
                        packet_data[0] <= {2'b00, DI_LS};
                        packet_data[1] <= {3'b000, line_number};
                        packet_data[2] <= 8'h00;
                        packet_data[3] <= calc_ecc({2'b00, DI_LS, 8'h00, 3'b000, line_number});

                        m_axis_tvalid <= 1'b1;
                        m_axis_tdata  <= {2'b00, DI_LS};
                        m_axis_tlast  <= 1'b0;
                    end else if (handshake_out) begin
                        byte_index   <= byte_index + 1'b1;
                        m_axis_tdata <= packet_data[byte_index + 1'b1];
                        m_axis_tlast <= (byte_index == 2'd2);

                        if (byte_index == 2'd3)
                            byte_index <= 2'd0;
                    end
                end

                //--------------------------------------------------------------
                // LONG_HDR: Long Packet Header (RAW8)
                //--------------------------------------------------------------
                ST_LONG_HDR: begin
                    if (byte_index == 2'd0) begin
                        word_count    <= PAYLOAD_SIZE;
                        crc_value     <= 16'hFFFF;
                        payload_counter <= 10'd0;

                        packet_data[0] <= {2'b00, DI_RAW8};
                        packet_data[1] <= PAYLOAD_SIZE[7:0];
                        packet_data[2] <= PAYLOAD_SIZE[15:8];
                        packet_data[3] <= calc_ecc({2'b00, DI_RAW8, PAYLOAD_SIZE[15:0]});

                        m_axis_tvalid <= 1'b1;
                        m_axis_tdata  <= {2'b00, DI_RAW8};
                        s_axis_tready <= 1'b0;
                    end else if (handshake_out) begin
                        byte_index   <= byte_index + 1'b1;
                        m_axis_tdata <= packet_data[byte_index + 1'b1];

                        if (byte_index == 2'd3) begin
                            byte_index    <= 2'd0;
                            s_axis_tready <= 1'b1;  // Ready for payload
                        end
                    end
                end

                //--------------------------------------------------------------
                // PAYLOAD: Transfer payload data
                //--------------------------------------------------------------
                ST_PAYLOAD: begin
                    if (handshake_in) begin
                        m_axis_tdata    <= s_axis_tdata;
                        payload_counter <= payload_counter + 1'b1;
                        crc_value       <= calc_crc16(crc_value, s_axis_tdata);

                        if (payload_counter == PAYLOAD_SIZE-1) begin
                            s_axis_tready <= 1'b0;
                        end
                    end
                end

                //--------------------------------------------------------------
                // CRC: CRC-16 Footer
                //--------------------------------------------------------------
                ST_CRC: begin
                    if (byte_index == 2'd0) begin
                        m_axis_tdata <= crc_value[7:0];
                        byte_index   <= 2'd1;
                    end else if (handshake_out) begin
                        m_axis_tdata <= crc_value[15:8];
                        m_axis_tlast <= 1'b1;
                        byte_index   <= 2'd0;
                    end
                end

                //--------------------------------------------------------------
                // BLANKING: Inter-line gap
                //--------------------------------------------------------------
                ST_BLANKING: begin
                    m_axis_tvalid    <= 1'b0;
                    m_axis_tlast     <= 1'b0;
                    blanking_counter <= blanking_counter + 1'b1;

                    if (blanking_counter >= 8'd10) begin
                        blanking_counter <= 8'd0;
                        line_number      <= line_number + 1'b1;
                    end
                end

                //--------------------------------------------------------------
                // FE: Frame End Short Packet
                //--------------------------------------------------------------
                ST_FE: begin
                    if (byte_index == 2'd0) begin
                        packet_data[0] <= {2'b00, DI_FE};
                        packet_data[1] <= 8'h00;
                        packet_data[2] <= 8'h00;
                        packet_data[3] <= calc_ecc({2'b00, DI_FE, 8'h00, 8'h00});

                        m_axis_tvalid <= 1'b1;
                        m_axis_tdata  <= {2'b00, DI_FE};
                    end else if (handshake_out) begin
                        byte_index   <= byte_index + 1'b1;
                        m_axis_tdata <= packet_data[byte_index + 1'b1];
                        m_axis_tlast <= (byte_index == 2'd2);

                        if (byte_index == 2'd3) begin
                            byte_index <= 2'd0;
                            frame_done <= 1'b1;
                        end
                    end
                end

                default: begin
                    m_axis_tvalid <= 1'b0;
                end
            endcase
        end
    end

    //==========================================================================
    // Assertions
    //==========================================================================
    `ifdef SIMULATION
        initial begin
            $display("[mipi_packet_gen] Configuration:");
            $display("  - Payload: %0d bytes/line", PAYLOAD_SIZE);
            $display("  - Lines: %0d lines/frame", LINE_COUNT);
            $display("  - Total: %0d bytes/frame", PAYLOAD_SIZE * LINE_COUNT);
        end
    `endif

endmodule
