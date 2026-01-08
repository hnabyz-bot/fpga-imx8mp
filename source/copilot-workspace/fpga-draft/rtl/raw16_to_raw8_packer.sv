// SPDX-License-Identifier: MIT
// Module: csi2_tx_raw16_to_raw8_packer
// Description: Converts 16-bit AXI4-Stream words into RAW8 byte stream for MIPI CSI-2 TX.
// Target: Xilinx Artix-7 XC7A35T (FGG484)

module csi2_tx_raw16_to_raw8_packer #(
    parameter integer WORDS_PER_LINE = 256  // 256 words -> 512 bytes per CSI-2 line
) (
    input  wire         clk,
    input  wire         rst_n,

    // 16-bit AXI4-Stream input (sensor/native domain)
    input  wire [15:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    output wire         s_axis_tready,
    input  wire         s_axis_tlast,
    input  wire         s_axis_tuser,

    // 8-bit AXI4-Stream output (RAW8 payload toward CSI-2 packetizer)
    output reg  [7:0]   m_axis_tdata,
    output reg          m_axis_tvalid,
    input  wire         m_axis_tready,
    output reg          m_axis_tlast,
    output reg          m_axis_tuser
);

    localparam integer LINE_BYTES = WORDS_PER_LINE * 2;

`ifndef SYNTHESIS
    initial begin
        if ((LINE_BYTES % 64) != 0) begin
            $error("raw16_to_raw8_packer: LINE_BYTES (%0d) must align to 64 bytes for i.MX8MP ISI requirements", LINE_BYTES);
        end
    end
`endif

    // FSM states represent which byte of the 16-bit word is being presented
    typedef enum logic [1:0] {
        WAIT_WORD = 2'b00,
        SEND_LSB  = 2'b01,
        SEND_MSB  = 2'b10
    } packer_state_t;

    packer_state_t state_d, state_q;
    logic [15:0]   word_q;
    logic          last_flag_q;

    // Ready when no word is currently being serialized
    assign s_axis_tready = (state_q == WAIT_WORD);

    // Next-state logic
    always @(*) begin
        state_d = state_q;
        case (state_q)
            WAIT_WORD: begin
                if (s_axis_tvalid && s_axis_tready) begin
                    state_d = SEND_LSB;
                end
            end
            SEND_LSB: begin
                if (m_axis_tvalid && m_axis_tready) begin
                    state_d = SEND_MSB;
                end
            end
            SEND_MSB: begin
                if (m_axis_tvalid && m_axis_tready) begin
                    state_d = WAIT_WORD;
                end
            end
            default: state_d = WAIT_WORD;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q       <= WAIT_WORD;
            word_q        <= 16'd0;
            last_flag_q   <= 1'b0;
            m_axis_tdata  <= 8'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tuser  <= 1'b0;
        end else begin
            state_q <= state_d;

            case (state_q)
                WAIT_WORD: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        word_q        <= s_axis_tdata;
                        last_flag_q   <= s_axis_tlast;
                        m_axis_tdata  <= s_axis_tdata[7:0];  // LSB first (Little Endian)
                        m_axis_tuser  <= s_axis_tuser;       // Frame start marks propagate on first byte
                        m_axis_tlast  <= 1'b0;
                        m_axis_tvalid <= 1'b1;
                    end
                end

                SEND_LSB: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        m_axis_tdata <= word_q[15:8];
                        m_axis_tuser <= 1'b0;        // Only first byte asserts TUSER
                        m_axis_tlast <= last_flag_q; // TLAST asserted on second byte
                    end
                end

                SEND_MSB: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        m_axis_tvalid <= 1'b0;
                        m_axis_tlast  <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
