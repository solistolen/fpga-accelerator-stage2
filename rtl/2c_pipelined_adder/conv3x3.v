// Stage 2c: 3x3 convolution engine with a PIPELINED adder tree.
// Multiplies a 3x3 window of pixels by a 3x3 kernel and adds the 9 products,
// one whole window per clock.
//
// Window / kernel numbering (p = pixel, k = coefficient):
//      p0 p1 p2        k0 k1 k2      <- top row    (oldest image row)
//      p3 p4 p5        k3 k4 k5      <- middle row
//      p6 p7 p8        k6 k7 k8      <- bottom row (newest image row)
// Packed into 72-bit buses: p0 = win[7:0], p1 = win[15:8], ... p8 = win[71:64]
//
// What changed from Stage 2b
//   In 2b the 9 products were summed in ONE clock. XST built that sum as a
//   chain of DSP48E1s linked by their cascade wires (PCOUT -> PCIN), so the
//   signal rippled through 7 DSP adders per clock: 13.8 ns, about 72 MHz.
//   Here the sum is split across two clocks, so no path goes through more
//   than 3 adders:
//
//   clock 1: 9 multiplies          -> m0..m8     (DSP multiplier register, MREG)
//   clock 2: add each ROW of 3     -> s0, s1, s2 (3 short chains of 3 DSPs)
//   clock 3: add the 3 row sums    -> sum
//
//   Latency goes from 2 clocks to 3. Throughput is unchanged: still one
//   window per clock, because a new window enters every clock while the
//   previous ones are further down the pipeline.
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

    // Sum of 3 products: worst case 3 * 255 * 128 = 97,920 -> 19 signed bits.
    // SUM_W (20) is used so every stage has the same width; XST trims the
    // unused top bit.
    reg signed [SUM_W-1:0] s0, s1, s2;

    always @(posedge clk) begin
        // clock 1: all nine multiplies at once
        m0 <= p0 * k0;  m1 <= p1 * k1;  m2 <= p2 * k2;
        m3 <= p3 * k3;  m4 <= p4 * k4;  m5 <= p5 * k5;
        m6 <= p6 * k6;  m7 <= p7 * k7;  m8 <= p8 * k8;

        // clock 2: add each row of the window separately
        s0 <= m0 + m1 + m2;     // top row
        s1 <= m3 + m4 + m5;     // middle row
        s2 <= m6 + m7 + m8;     // bottom row

        // clock 3: add the three row sums. Worst case |sum| = 293,760,
        // which fits in 20 signed bits (+/- 524,287).
        sum <= s0 + s1 + s2;
    end
endmodule
