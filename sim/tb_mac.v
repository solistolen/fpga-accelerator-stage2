// Self-checking testbench for the Stage 1 MAC unit.
// Reads vectors.txt (made by gen_vectors.py), drives one line per clock,
// and compares the accumulator against the Python golden model.
`timescale 1ns/1ps
module tb_mac;
    localparam W = 8, ACC_W = 32;

    reg                     clk = 0, rst = 1, en = 0, clr = 0;
    reg  signed [W-1:0]     a = 0, b = 0;
    wire signed [ACC_W-1:0] acc;

    mac #(.W(W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rst(rst), .en(en), .clr(clr), .a(a), .b(b), .acc(acc));

    always #5 clk = ~clk;                       // 100 MHz clock

    integer fd, n, line = 0, errors = 0;
    reg [31:0] v_en, v_clr, v_a, v_b, v_exp;

    initial begin
        $dumpfile("mac.vcd");                   // open in GTKWave
        $dumpvars(0, tb_mac);
        fd = $fopen("vectors.txt", "r");
        if (fd == 0) begin $display("ERROR: run gen_vectors.py first"); $finish; end

        repeat (2) @(posedge clk);              // hold reset for two cycles
        #1;
        if (acc !== 0) begin $display("FAIL: acc = %0d after reset (expected 0)", acc); errors = errors + 1; end
        rst = 0;

        while (!$feof(fd)) begin
            n = $fscanf(fd, "%h %h %h %h %h\n", v_en, v_clr, v_a, v_b, v_exp);
            if (n == 5) begin
                @(negedge clk);                 // change inputs away from the active edge
                en = v_en[0]; clr = v_clr[0]; a = v_a[W-1:0]; b = v_b[W-1:0];
                @(posedge clk); #1;             // let the register update, then check
                line = line + 1;
                if (acc !== v_exp[ACC_W-1:0]) begin
                    errors = errors + 1;
                    if (errors <= 10)
                        $display("FAIL line %0d: en=%b clr=%b a=%0d b=%0d  acc=%0d  expected=%0d",
                                 line, en, clr, a, b, acc, $signed(v_exp[ACC_W-1:0]));
                end
            end
        end
        $fclose(fd);
        if (errors == 0) $display("PASS: %0d cycles matched the golden model", line);
        else             $display("FAIL: %0d of %0d cycles wrong", errors, line);
        $finish;
    end
endmodule
