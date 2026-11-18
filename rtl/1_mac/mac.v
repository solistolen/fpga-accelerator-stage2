// Stage 1: signed 8-bit multiply-accumulate (MAC) unit
// ---------------------------------------------------------------------------
// Behavior on each rising clock edge:
//   rst = 1             -> acc <= 0                   (synchronous reset, highest priority)
//   en = 1, clr = 1     -> acc <= a * b               (start a new dot product)
//   en = 1, clr = 0     -> acc <= acc + a * b         (keep accumulating)
//   en = 0              -> acc holds its value        (clr is ignored)
//
// Your tasks are marked TODO. Read the hints, then run the testbench.
// ---------------------------------------------------------------------------
module mac #(
    parameter W     = 8,     // input width (int8)
    parameter ACC_W = 32     // accumulator width; see "bit growth" in the notes
)(
    input  wire                    clk,
    input  wire                    rst,
    input  wire                    en,
    input  wire                    clr,
    input  wire signed [W-1:0]     a,
    input  wire signed [W-1:0]     b,
    output reg  signed [ACC_W-1:0] acc
);

    // TODO 1: Declare the product of a and b.
    //   - How many bits does a signed W x W product need? (Work it out for
    //     -128 * -128 before you decide.)
    //   - It must be declared signed.
    //   - Hint: a wire with a continuous assign is enough here.
wire signed [2*W-1:0] prod = a * b;

    // TODO 2: Write the clocked accumulator described in the table above.
    //   - Use a single always @(posedge clk) block with non-blocking (<=) assignments.
    //   - Check rst first, then en, then clr.
    //   - When you add the product to acc, make sure the product is
    //     sign-extended to ACC_W bits. If either operand of an expression is
    //     unsigned, Verilog does the whole expression unsigned, and negative
    //     products turn into large positive numbers.

always @(posedge clk) begin
    if (rst)
        acc <= 0;                 // reset clears the sum
    else if (en) begin
        if (clr)
            acc <= prod;          // start a new dot product with the first term
        else
            acc <= acc + prod;    // add the next term to the running sum
    end
    // en = 0: no assignment, so acc holds its value
end
endmodule 
