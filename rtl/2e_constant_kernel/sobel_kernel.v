// Stage 2e: FIXED-coefficient Sobel kernel (replaces the two conv3x3 engines).
//
// conv3x3 is programmable: the 9 coefficients arrive on a port, so XST has to
// build 9 real multipliers per kernel (18 DSP48E1s for Gx + Gy), even for the
// coefficients that are 0. Sobel's coefficients never change and are only
// 0, +-1 and +-2, so here they are written straight into the arithmetic:
//
//   Gx = -1 0 +1      Gx = (p2 - p0) + 2*(p5 - p3) + (p8 - p6)
//        -2 0 +2           (right column minus left column, per row)
//        -1 0 +1
//
//   Gy = -1 -2 -1     Gy = (p6 - p0) + 2*(p7 - p1) + (p8 - p2)
//         0  0  0          (bottom row minus top row, per column)
//        +1 +2 +1
//
//   x 0  -> the term disappears (p1, p4, p7 never touch Gx; p3, p4, p5 never touch Gy)
//   x 2  -> a 1-bit left shift, which is just wiring
//   x -1 -> a subtraction
// No multipliers are left, so XST should use 0 DSPs, only LUT adders.
//
// Window numbering (same as conv3x3):
//      p0 p1 p2      <- top row    (oldest image row)
//      p3 p4 p5      <- middle row
//      p6 p7 p8      <- bottom row (newest image row)
//   p0 = win[7:0], p1 = win[15:8], ... p8 = win[71:64]
//
// Pipeline (latency 2 clocks, one less than conv3x3 because the arithmetic is small):
//   clock 1: six 9-bit differences  -> dx0..dx2, dy0..dy2
//   clock 2: weighted 3-input sum   -> gx, gy
//
// Trade-off vs conv3x3: no DSPs and fewer clocks, but it can only ever compute
// Sobel. A CNN layer needs new weights for every filter, which is why a real
// accelerator uses the programmable version.
module sobel_kernel #(parameter SUM_W = 20)(
    input  wire                     clk,
    input  wire [71:0]              win,    // 9 unsigned 8-bit pixels
    output reg  signed [SUM_W-1:0]  gx, gy
);
    // Unsigned pixels with a 0 on top, so a - b is a proper signed result
    wire signed [9:0] p0 = {2'b0, win[ 7: 0]};
    wire signed [9:0] p1 = {2'b0, win[15: 8]};
    wire signed [9:0] p2 = {2'b0, win[23:16]};
    wire signed [9:0] p3 = {2'b0, win[31:24]};
    wire signed [9:0] p5 = {2'b0, win[47:40]};
    wire signed [9:0] p6 = {2'b0, win[55:48]};
    wire signed [9:0] p7 = {2'b0, win[63:56]};
    wire signed [9:0] p8 = {2'b0, win[71:64]};
    // p4 (the centre pixel) has coefficient 0 in both kernels: not used at all

    // A difference of two pixels is -255..+255: 9 bits plus sign = 10 bits
    reg signed [9:0] dx0, dx1, dx2;     // right minus left, per row
    reg signed [9:0] dy0, dy1, dy2;     // bottom minus top, per column

    // Weighted sum: worst case 255 + 2*255 + 255 = 1020 -> 11 bits plus sign = 12
    wire signed [11:0] sx = dx0 + (dx1 <<< 1) + dx2;
    wire signed [11:0] sy = dy0 + (dy1 <<< 1) + dy2;

    always @(posedge clk) begin
        // clock 1: differences
        dx0 <= p2 - p0;   dx1 <= p5 - p3;   dx2 <= p8 - p6;
        dy0 <= p6 - p0;   dy1 <= p7 - p1;   dy2 <= p8 - p2;

        // clock 2: weighted sums, sign-extended to SUM_W bits so the rest of
        // the design (magnitude, outputs, testbench) is unchanged
        gx <= sx;
        gy <= sy;
    end
endmodule
