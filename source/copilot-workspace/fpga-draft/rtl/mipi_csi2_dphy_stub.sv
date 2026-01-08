// SPDX-License-Identifier: MIT
// Module: csi2_tx_dphy_stub
// Description: Simplified 4-lane serializer that maps byte stream output
//              onto differential GPIO pairs for simulation/bring-up only.

module csi2_tx_dphy_stub #(
    parameter integer LANES = 4
) (
    input  wire        clk,
    input  wire        rst_n,

    // AXI-Stream byte input
    input  wire [7:0]  s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tuser,

    // Simplified LP/HS outputs
    output wire        mipi_clk_p,
    output wire        mipi_clk_n,
    output wire [LANES-1:0] mipi_data_p,
    output wire [LANES-1:0] mipi_data_n
);

    localparam integer BITS_PER_BYTE = 8;

    reg [1:0]          lane_ptr_q;
    reg [7:0]          lane_shift   [0:LANES-1];
    reg [2:0]          lane_cnt     [0:LANES-1];
    reg                lane_active  [0:LANES-1];

    wire lane_available = (lane_active[lane_ptr_q] == 1'b0);
    assign s_axis_tready = lane_available;
    wire accept_byte = s_axis_tvalid && s_axis_tready;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lane_ptr_q <= 2'd0;
            for (i = 0; i < LANES; i = i + 1) begin
                lane_shift[i]  <= 8'hFF;
                lane_cnt[i]    <= 3'd0;
                lane_active[i] <= 1'b0;
            end
        end else begin
            if (accept_byte) begin
                lane_shift[lane_ptr_q]  <= s_axis_tdata;
                lane_cnt[lane_ptr_q]    <= BITS_PER_BYTE-1;
                lane_active[lane_ptr_q] <= 1'b1;
                lane_ptr_q              <= (lane_ptr_q == LANES-1) ? 2'd0 : lane_ptr_q + 1'b1;
            end

            for (i = 0; i < LANES; i = i + 1) begin
                if (lane_active[i]) begin
                    lane_shift[i] <= {lane_shift[i][6:0], 1'b0};
                    if (lane_cnt[i] == 3'd0) begin
                        lane_active[i] <= 1'b0;
                    end else begin
                        lane_cnt[i] <= lane_cnt[i] - 1'b1;
                    end
                end
            end
        end
    end

    reg [LANES-1:0] lane_bit_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lane_bit_q <= {LANES{1'b1}};
        end else begin
            for (i = 0; i < LANES; i = i + 1) begin
                lane_bit_q[i] <= lane_active[i] ? lane_shift[i][7] : 1'b1; // LP-11 idle
            end
        end
    end

    assign mipi_clk_p = clk;
    assign mipi_clk_n = ~clk;
    assign mipi_data_p = lane_bit_q;
    assign mipi_data_n = ~lane_bit_q;

endmodule
