// =============================================================================
// tb_sigmoid_rom.v
// Testbench: sigmoid_rom.v
//
// sigmoid_rom has synchronous read — output is registered on posedge clk.
// Tests use real ROM addresses produced by sat_clamp for actual neuron sums.
//
// Tests:
//   1. Reset -> q = 0
//   2. Midpoint address 0x2000 -> sigmoid(0) = 128
//   3. Min address 0x0000 -> sigmoid(-8) ~ 0
//   4. Max address 0x3FFF -> sigmoid(+8) ~ 255
//   5. Real addresses from nn_rgb neuron sums
//   6. Monotonicity sweep: output must be non-decreasing across all entries
// =============================================================================
`timescale 1ns/1ps
`include "sigmoid_rom.v"

module tb_sigmoid_rom;

    reg        clk   = 0;
    reg        rst_n = 0;
    reg  [13:0] address;
    wire [ 7:0] q;

    localparam CLK_PERIOD = 10;
    always #(CLK_PERIOD/2) clk = ~clk;

    sigmoid_rom dut (.clk(clk), .rst_n(rst_n), .address(address), .q(q));

    task check;
        input [13:0] addr;
        input [7:0]  exp_min, exp_max;
        input [255:0] label;
        begin
            address = addr;
            @(posedge clk); #1;
            if (q >= exp_min && q <= exp_max)
                $display("  PASS | %-32s | addr=0x%04h -> q=%3d [%3d..%3d]",
                    label, addr, q, exp_min, exp_max);
            else
                $display("  FAIL | %-32s | addr=0x%04h -> q=%3d [%3d..%3d]",
                    label, addr, q, exp_min, exp_max);
        end
    endtask

    integer i;
    reg [7:0] prev_val;
    integer   mono_errors;

    initial begin
        $dumpfile("tb_sigmoid_rom.vcd");
        $dumpvars(0, tb_sigmoid_rom);
        address = 14'h0000;

        $display("============================================================");
        $display("  TB: sigmoid_rom (synchronous read, 16384 entries)");
        $display("  sigmoid(x)=1/(1+e^-x), output range 0-255");
        $display("============================================================");

        // Reset
        rst_n = 0;
        repeat(3) @(posedge clk); #1;
        if (q === 8'h00)
            $display("  PASS | RESET                            | q = 0x00");
        else
            $display("  FAIL | RESET                            | q = 0x%02h", q);
        rst_n = 1;

        // --- Key address checks ---
        $display("--- Key address checks ---");
        check(14'h2000, 8'd126, 8'd130, "MIDPOINT  addr=0x2000 sigmoid(0)=128");
        check(14'h0000, 8'd0,   8'd3,   "MIN       addr=0x0000 sigmoid(-8)~0");
        check(14'h3FFF, 8'd252, 8'd255, "MAX       addr=0x3FFF sigmoid(+8)~255");
        check(14'h1000, 8'd0,   8'd5,   "QUARTER   addr=0x1000 sigmoid(-4)~2");
        check(14'h3000, 8'd250, 8'd255, "3-QUARTER addr=0x3000 sigmoid(+4)~253");

        // --- Real addresses from nn_rgb.vhd neuron sums ---
        $display("--- Real addresses from nn_rgb.vhd ---");

        // hidden0 pixel(0,0,0): addr=0x0E33 -> deep negative -> q~0
        check(14'h0E33, 8'd0,   8'd20,  "h0 pixel(0,0,0)   addr=0x0E33");

        // hidden0 pixel(255,0,0): addr=0x156C -> negative -> q low
        check(14'h156C, 8'd0,   8'd30,  "h0 pixel(255,0,0) addr=0x156C");

        // hidden1 pixel(0,0,0): addr=0x22C7 -> slightly above mid -> q>128
        check(14'h22C7, 8'd128, 8'd180, "h1 pixel(0,0,0)   addr=0x22C7");

        // output0 mid-gray: addr=0x2B48 -> positive -> q high
        check(14'h2B48, 8'd200, 8'd255, "o0 mid-gray       addr=0x2B48");

        // output0 pixel(255,255,255): addr=0x0E03 -> negative -> q low
        check(14'h0E03, 8'd0,   8'd20,  "o0 pixel(255,255,255) addr=0x0E03");

        // Saturated high addr=0x3FFF -> q~255
        check(14'h3FFF, 8'd252, 8'd255, "SAT HIGH addr=0x3FFF q~255");

        // Saturated low addr=0x0000 -> q~0
        check(14'h0000, 8'd0,   8'd3,   "SAT LOW  addr=0x0000 q~0");

        // --- Monotonicity sweep (every 128 entries) ---
        $display("--- Monotonicity sweep (every 128 addresses) ---");
        mono_errors = 0;
        prev_val    = 8'd0;
        for (i = 0; i < 16384; i = i + 128) begin
            address = i[13:0];
            @(posedge clk); #1;
            if (q < prev_val) begin
                $display("  FAIL | MONOTONICITY addr=0x%04h q=%0d < prev=%0d",
                    address, q, prev_val);
                mono_errors = mono_errors + 1;
            end
            prev_val = q;
        end
        if (mono_errors == 0)
            $display("  PASS | MONOTONICITY | all %0d samples non-decreasing", 16384/128);
        else
            $display("  FAIL | MONOTONICITY | %0d violations found", mono_errors);

        $display("============================================================");
        $display("  sigmoid_rom TB complete.");
        $finish;
    end

    initial begin #2000000; $display("TIMEOUT"); $finish; end

endmodule
