// Stage 2b: 3x3 convolution engine.
// Multiplies a 3x3 window of pixels by a 3x3 kernel and adds the 9 products.
// Unlike the Stage 1 MAC (one multiply per clock, 9 clocks per window), this
// uses 9 multipliers IN PARALLEL so it finishes one whole window every clock.
//
// Window / kernel numbering (p = pixel, k = coefficient):
//      p0 p1 p2        k0 k1 k2      <- top row    (oldest image row)
//      p3 p4 p5        k3 k4 k5      <- middle row
//      p6 p7 p8        k6 k7 k8      <- bottom row (newest image row)
// Packed into 72-bit buses: p0 = win[7:0], p1 = win[15:8], ... p8 = win[71:64]
//
// Pipeline (latency 2 clocks), like the pipelined MAC in Stage 2a:
//   clock 1: 9 multiplies  -> m0..m8 registers
//   clock 2: add 9 products -> sum register
module conv3x3 #(parameter SUM_W = 20)(
    input  wire                     clk,
    input  wire [71:0]              win,    // 9 unsigned 8-bit pixels
    input  wire [71:0]              coef,   // 9 signed 8-bit coefficients
    output reg  signed [SUM_W-1:0]  sum
);
    // Pixels are unsigned (0..255). Add a 0 on top so they become signed
    // 9-bit numbers (still 0..255) that can be multiplied by signed coefficients.
    wire signed [8:0] p0 = {1'b0, win[ 7: 0]};
    wire signed [8:0] p1 = {1'b0, win[15: 8]};
    wire signed [8:0] p2 = {1'b0, win[23:16]};
    wire signed [8:0] p3 = {1'b0, win[31:24]};
    wire signed [8:0] p4 = {1'b0, win[39:32]};
    wire signed [8:0] p5 = {1'b0, win[47:40]};
    wire signed [8:0] p6 = {1'b0, win[55:48]};
    wire signed [8:0] p7 = {1'b0, win[63:56]};
    wire signed [8:0] p8 = {1'b0, win[71:64]};

    wire signed [7:0] k0 = coef[ 7: 0];
    wire signed [7:0] k1 = coef[15: 8];
    wire signed [7:0] k2 = coef[23:16];
    wire signed [7:0] k3 = coef[31:24];
    wire signed [7:0] k4 = coef[39:32];
    wire signed [7:0] k5 = coef[47:40];
    wire signed [7:0] k6 = coef[55:48];
    wire signed [7:0] k7 = coef[63:56];
    wire signed [7:0] k8 = coef[71:64];

    // 9-bit x 8-bit signed product needs 9 + 8 = 17 bits
    reg signed [16:0] m0, m1, m2, m3, m4, m5, m6, m7, m8;

    always @(posedge clk) begin
        // clock 1: all nine multiplies at once
        m0 <= p0 * k0;  m1 <= p1 * k1;  m2 <= p2 * k2;
        m3 <= p3 * k3;  m4 <= p4 * k4;  m5 <= p5 * k5;
        m6 <= p6 * k6;  m7 <= p7 * k7;  m8 <= p8 * k8;

        // clock 2: add them. Worst case |sum| = 9 * 255 * 128 = 293,760,
        // which fits in 20 signed bits (+/- 524,287).
        sum <= m0 + m1 + m2 + m3 + m4 + m5 + m6 + m7 + m8;
    end
endmodule
