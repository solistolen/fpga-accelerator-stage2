// Stage 2a: pipelined MAC unit.
// Same job as mac.v, but the product is stored in a register (prod_r)
// before it reaches the adder. That splits the long multiply+add path
// into two short paths, so the clock can run faster.
// Cost: acc now updates ONE clock later than in mac.v (latency = 2 edges).
module mac_p #(parameter W = 8, parameter ACC_W = 32)(
    input  wire                     clk, rst, en, clr,
    input  wire signed [W-1:0]      a, b,
    output reg  signed [ACC_W-1:0]  acc
);
    // Pipeline stage 1: multiply, and remember what en/clr were for this product
    reg signed [2*W-1:0] prod_r;
    reg                  en_r, clr_r;

    always @(posedge clk) begin
        if (rst) begin
            prod_r <= 0;
            en_r   <= 0;
            clr_r  <= 0;
            acc    <= 0;
        end else begin
            // stage 1: register the product and its control bits together
            prod_r <= a * b;
            en_r   <= en;
            clr_r  <= clr;

            // stage 2: accumulate the product from the PREVIOUS clock
            if (en_r) begin
                if (clr_r)
                    acc <= prod_r;
                else
                    acc <= acc + prod_r;
            end
        end
    end
endmodule
