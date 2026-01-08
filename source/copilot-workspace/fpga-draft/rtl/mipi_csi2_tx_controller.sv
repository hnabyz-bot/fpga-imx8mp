// SPDX-License-Identifier: MIT
// Module: csi2_tx_frame_ctrl
// Description: Gathers frame requests (TUSER pulse) and sequences RAW line capture
//              and replay pipeline so only one frame is processed at a time.

module csi2_tx_frame_ctrl (
    input  wire clk,
    input  wire rst_n,

    // Request interface
    input  wire frame_req_pulse,

    // Datapath handshake
    input  wire frame_start_pulse,
    input  wire frame_active,
    input  wire frame_done_pulse,

    // Control outputs
    output reg  capture_enable,
    output reg  frame_busy,
    output reg  frame_ack_pulse
);

    typedef enum logic [1:0] {
        ST_IDLE    = 2'd0,
        ST_CAPTURE = 2'd1,
        ST_ACTIVE  = 2'd2
    } state_t;

    state_t state_q, state_d;

    always @(*) begin
        state_d = state_q;
        case (state_q)
            ST_IDLE: begin
                if (frame_req_pulse) begin
                    state_d = ST_CAPTURE;
                end
            end
            ST_CAPTURE: begin
                if (frame_start_pulse) begin
                    state_d = ST_ACTIVE;
                end
            end
            ST_ACTIVE: begin
                if (frame_done_pulse) begin
                    state_d = ST_IDLE;
                end
            end
            default: state_d = ST_IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q        <= ST_IDLE;
            capture_enable <= 1'b0;
            frame_busy     <= 1'b0;
            frame_ack_pulse<= 1'b0;
        end else begin
            state_q        <= state_d;
            frame_ack_pulse<= 1'b0;

            case (state_d)
                ST_IDLE: begin
                    capture_enable <= 1'b0;
                    frame_busy     <= 1'b0;
                end
                ST_CAPTURE: begin
                    capture_enable <= 1'b1;
                    frame_busy     <= 1'b1;
                end
                ST_ACTIVE: begin
                    capture_enable <= 1'b0;
                    frame_busy     <= frame_active;
                    if (frame_done_pulse) begin
                        frame_ack_pulse <= 1'b1;
                    end
                end
                default: begin
                    capture_enable <= 1'b0;
                    frame_busy     <= 1'b0;
                end
            endcase
        end
    end

endmodule
