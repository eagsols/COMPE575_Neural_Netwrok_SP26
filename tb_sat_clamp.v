// =============================================================================
// tb_sat_clamp.v
// Testbench: sat_clamp.v
//
// sat_clamp is purely combinational — output updates immediately.
//
// Verifies: addr = (sum + 32768) >> 2  for -32768 <= sum <= 32767
//           addr = 0x0000              for sum < -32768
//           addr = 0x3FFF              for sum > +32767
//
// Also tests with real neuron sum values computed from nn_rgb.vhd weights.
// =============================================================================
`timescale 1ns/1ps
`include "sat_clamp.v"

module tb_sat_clamp;

    reg clk = 0;
    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg  signed [31:0] sum_in;
    wire        [13:0] addr_out;

    sat_clamp dut (.sum_in(sum_in), .addr_out(addr_out));

    task check;
        input signed [31:0] s;
        input        [13:0] expected;
        input [255:0]        label;
        begin
            sum_in = s; #2;
            if (addr_out === expected)
                $display("  PASS | %-32s | sum=%8d -> addr=0x%04h",
                    label, $signed(s), addr_out);
            else
                $display("  FAIL | %-32s | sum=%8d -> addr=0x%04h  exp=0x%04h",
                    label, $signed(s), addr_out, expected);
        end
    endtask

    initial begin
        $dumpfile("tb_sat_clamp.vcd");
        $dumpvars(0, tb_sat_clamp);
        sum_in = 32'sh0;

        $display("============================================================");
        $display("  TB: sat_clamp (combinational)");
        $display("  addr = (sum + 32768) >> 2  [bits 15:2 of offset sum]");
        $display("  ROM range: 0x0000..0x3FFF  (16384 entries)");
        $display("============================================================");

        // --- Boundary and saturation ---
        $display("--- Boundary and saturation tests ---");

        // Zero -> (0+32768)>>2 = 8192 = 0x2000
        check(32'sd0,      14'h2000, "ZERO -> midpoint 0x2000");

        // Exact lower boundary: -32768 -> (0)>>2 = 0
        check(-32'sd32768, 14'h0000, "LOWER BOUND -32768 -> 0x0000");

        // Exact upper boundary: +32767 -> (65535)>>2 = 16383 = 0x3FFF
        check(32'sd32767,  14'h3FFF, "UPPER BOUND +32767 -> 0x3FFF");

        // Saturate low: -50000 -> 0x0000
        check(-32'sd50000, 14'h0000, "SAT LOW  -50000 -> 0x0000");

        // Saturate high: +100000 -> 0x3FFF
        check(32'sd100000, 14'h3FFF, "SAT HIGH +100000 -> 0x3FFF");

        // --- Real neuron sums from nn_rgb.vhd ---
        $display("--- Real neuron sums from nn_rgb.vhd ---");

        // hidden0 pixel(0,0,0): sum=-18227
        // (-18227+32768)>>2 = 14541>>2 = 3635 = 0x0E33
        check(-32'sd18227, 14'h0E33, "h0 pixel(0,0,0)   sum=-18227");

        // hidden0 pixel(255,0,0): sum=-10832
        // (-10832+32768)>>2 = 21936>>2 = 5484 = 0x156C
        check(-32'sd10832, 14'h156C, "h0 pixel(255,0,0) sum=-10832");

        // hidden0 pixel(0,255,0): sum=-29702  -> saturates low
        check(-32'sd29702, 14'h0000, "h0 pixel(0,255,0) sum=-29702 SAT");

        // hidden0 pixel(0,0,255): sum=-40412  -> saturates low
        check(-32'sd40412, 14'h0000, "h0 pixel(0,0,255) sum=-40412 SAT");

        // hidden1 pixel(0,0,255): sum=97450   -> saturates high
        check(32'sd97450,  14'h3FFF, "h1 pixel(0,0,255) sum=97450 SAT");

        // hidden1 pixel(0,0,0): sum=2845
        // (2845+32768)>>2 = 35613>>2 = 8903 = 0x22C7
        check(32'sd2845,   14'h22C7, "h1 pixel(0,0,0)   sum=2845");

        // output0 pixel(128,128,128): sum=11552
        // (11552+32768)>>2 = 44320>>2 = 11080 = 0x2B48
        check(32'sd11552,  14'h2B48, "o0 mid-gray       sum=11552");

        // output0 pixel(0,0,0): sum=41760  -> saturates high
        check(32'sd41760,  14'h3FFF, "o0 pixel(0,0,0)   sum=41760 SAT");

        // output0 pixel(255,255,255): sum=-18420
        // (-18420+32768)>>2 = 14348>>2 = 3587 = 0x0E03
        check(-32'sd18420, 14'h0E03, "o0 pixel(255,255,255) sum=-18420");

        $display("============================================================");
        $display("  sat_clamp TB complete.");
        $finish;
    end

    initial begin #50000; $display("TIMEOUT"); $finish; end

endmodule
