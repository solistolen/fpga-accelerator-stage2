// Self-checking testbench for the pipelined MAC (mac_p.v).
// Uses the SAME vectors.txt as Stage 1. Because mac_p has one extra cycle
// of latency, each expected value is checked one clock later.
`timescale 1ns/1ps
module tb_mac_p;
    localparam W = 8, ACC_W = 32;

    reg                     clk = 0, rst = 1, en = 0, clr = 0;
    reg  signed [W-1:0]     a = 0, b = 0;
    wire signed [ACC_W-1:0] acc;

    mac_p #(.W(W), .ACC_W(ACC_W)) dut (
        .clk(clk), .rst(rst), .en(en), .clr(clr), .a(a), .b(b), .acc(acc));

    always #5 clk = ~clk;                       // 100 MHz clock

    integer fd, n, line = 0, errors = 0;
    reg [31:0] v_en, v_clr, v_a, v_b, v_exp;
    reg [31:0] exp_prev;                        // expected value from the previous line
    reg        have_prev = 0;

    task check;                                 // compare acc against the delayed expectation
        begin
            if (have_prev && acc !== exp_prev[ACC_W-1:0]) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL vector %0d: acc=%0d expected=%0d",
                             line - 1, acc, $signed(exp_prev[ACC_W-1:0]));
            end
        end
    endtask

    initial begin
        fd = $fopen("vectors.txt", "r");
        if (fd == 0) begin $display("ERROR: vectors.txt not found"); $finish; end

        repeat (2) @(posedge clk);              // hold reset for two cycles
        #1;
        if (acc !== 0) begin $display("FAIL: acc = %0d after reset", acc); errors = errors + 1; end
        rst = 0;

        while (!$feof(fd)) begin
            n = $fscanf(fd, "%h %h %h %h %h\n", v_en, v_clr, v_a, v_b, v_exp);
            if (n == 5) begin
                @(negedge clk);
                en = v_en[0]; clr = v_clr[0]; a = v_a[W-1:0]; b = v_b[W-1:0];
                @(posedge clk); #1;
                check;                          // acc now reflects the PREVIOUS vector
                exp_prev = v_exp; have_prev = 1;
                line = line + 1;
            end
        end
        // one extra clock with en = 0 to flush the last product out of the pipeline
        @(negedge clk); en = 0; clr = 0;
        @(posedge clk); #1;
        line = line + 1;
        check;

        $fclose(fd);
        if (errors == 0) $display("PASS: %0d vectors matched the golden model (latency 2)", line - 1);
        else             $display("FAIL: %0d mismatches", errors);
        $finish;
    end
endmodule
