// =============================================================================
// tb_multiplier.v
// Testbench for multiplier.v (32-bit output version)
//
// Module under test:
//   module multiplier #(WIN1=8, WIN2=32, WOUT=32)
//   in1  : [WIN1-1:0]        8-bit unsigned  — pixel input (0-255)
//   in2  : signed [WIN2-1:0] 32-bit signed   — weight
//   out  : signed [WOUT-1:0] 32-bit signed   — product (combinational)
//
// Tests:
//   1. Zero tests           — zero pixel or zero weight always gives 0
//   2. Basic known products — simple hand-verifiable multiplications
//   3. Real nn_rgb weights  — all 4 neurons, all 3 weights at pixel=255/128
//   4. Sign correctness     — negative weight must produce negative product
//   5. Overflow check       — worst-case products fit in 32-bit signed
// =============================================================================
`timescale 1ns/1ps

module tb_multiplier;

    // -------------------------------------------------------------------------
    // Parameters — match updated multiplier.v
    // -------------------------------------------------------------------------
    localparam WIN1 = 8;
    localparam WIN2 = 32;
    localparam WOUT = 32;     // changed from 40 to 32

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    reg              [WIN1-1:0] in1;
    reg  signed      [WIN2-1:0] in2;
    wire signed      [WOUT-1:0] out;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    multiplier #(
        .WIN1 (WIN1),
        .WIN2 (WIN2),
        .WOUT (WOUT)
    ) dut (
        .in1 (in1),
        .in2 (in2),
        .out (out)
    );

    // -------------------------------------------------------------------------
    // Pass/fail tracking
    // -------------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    // -------------------------------------------------------------------------
    // Task: drive inputs, wait for combinational settle, check output
    // -------------------------------------------------------------------------
    task check;
        input [WIN1-1:0]        pixel;
        input signed [WIN2-1:0] weight;
        input signed [WOUT-1:0] expected;
        input [255:0]            label;
        begin
            in1 = pixel;
            in2 = weight;
            #5;
            if (out === expected) begin
                $display("  PASS | %-38s | %4d * %6d = %10d",
                    label, pixel, $signed(weight), out);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | %-38s | %4d * %6d = %10d  (expected %10d)",
                    label, pixel, $signed(weight), out, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_multiplier.vcd");
        $dumpvars(0, tb_multiplier);

        in1 = 0;
        in2 = 0;
        #10;

        $display("============================================================");
        $display("  TB: multiplier (32-bit output)");
        $display("  in1 : %0d-bit unsigned  (pixel 0-255)", WIN1);
        $display("  in2 : %0d-bit signed    (weight)",      WIN2);
        $display("  out : %0d-bit signed    (product)",     WOUT);
        $display("============================================================");

        // ------------------------------------------------------------------
        // Group 1: Zero tests
        // ------------------------------------------------------------------
        $display("--- Zero tests ---");

        check(8'd0,   32'sh0000001D,  32'sh0, "pixel=0,   w=29   -> 0");
        check(8'd0,   32'shFFFFFE97,  32'sh0, "pixel=0,   w=-361 -> 0");
        check(8'd0,   32'shFFFFB86D,  32'sh0, "pixel=0,   w=-18227 -> 0");
        check(8'd128, 32'sh00000000,  32'sh0, "pixel=128, w=0    -> 0");
        check(8'd255, 32'sh00000000,  32'sh0, "pixel=255, w=0    -> 0");

        // ------------------------------------------------------------------
        // Group 2: Basic known products
        // ------------------------------------------------------------------
        $display("--- Basic known products ---");

        check(8'd1,   32'sh00000001,  32'sh00000001, "1   *    1 =       1");
        check(8'd1,   32'shFFFFFFFF,  32'shFFFFFFFF, "1   *   -1 =      -1");
        check(8'd10,  32'sh00000005,  32'sh00000032, "10  *    5 =      50");
        check(8'd10,  32'shFFFFFFFB,  32'shFFFFFFCE, "10  *   -5 =     -50");
        check(8'd255, 32'sh00000001,  32'sh000000FF, "255 *    1 =     255");
        check(8'd255, 32'shFFFFFFFF,  32'shFFFFFF01, "255 *   -1 =    -255");

        // ------------------------------------------------------------------
        // Group 3: Real weights from nn_rgb.vhd
        // ------------------------------------------------------------------

        // --- hidden0: w1=29  w2=-45  w3=-87 ---
        $display("--- hidden0: w1=29  w2=-45  w3=-87 ---");

        // 255 * 29 = 7395
        check(8'd255, 32'sh0000001D, 32'sh00001CE3, "h0 w1= 29:  255*  29 =   7395");
        // 255 * -45 = -11475
        check(8'd255, 32'shFFFFFFD3, 32'hFFFFD32D,  "h0 w2=-45:  255* -45 = -11475");
        // 255 * -87 = -22185
        check(8'd255, 32'shFFFFFFa9, 32'hFFFFA957,  "h0 w3=-87:  255* -87 = -22185");
        // 128 * 29 = 3712
        check(8'd128, 32'sh0000001D, 32'sh00000E80, "h0 w1= 29:  128*  29 =   3712");
        // 128 * -45 = -5760
        check(8'd128, 32'shFFFFFFD3, 32'hFFFFE980,  "h0 w2=-45:  128* -45 =  -5760");
        // 128 * -87 = -11136
        check(8'd128, 32'shFFFFFFa9, 32'hFFFFD480,  "h0 w3=-87:  128* -87 = -11136");

        // --- hidden1: w1=-361  w2=126  w3=371 ---
        $display("--- hidden1: w1=-361  w2=126  w3=371 ---");

        // 255 * -361 = -92055
        check(8'd255, 32'shFFFFFE97, 32'hFFFE9869,  "h1 w1=-361: 255*-361 = -92055");
        // 255 * 126 = 32130
        check(8'd255, 32'sh0000007E, 32'sh00007D82, "h1 w2= 126: 255* 126 =  32130");
        // 255 * 371 = 94605
        check(8'd255, 32'sh00000173, 32'sh0001718D, "h1 w3= 371: 255* 371 =  94605");
        // 128 * -361 = -46208
        check(8'd128, 32'shFFFFFE97, 32'hFFFF4B80,  "h1 w1=-361: 128*-361 = -46208");
        // 128 * 126 = 16128
        check(8'd128, 32'sh0000007E, 32'sh00003F00, "h1 w2= 126: 128* 126 =  16128");
        // 128 * 371 = 47488
        check(8'd128, 32'sh00000173, 32'sh0000B980, "h1 w3= 371: 128* 371 =  47488");

        // --- hidden2: w1=-313  w2=96  w3=337 ---
        $display("--- hidden2: w1=-313  w2=96  w3=337 ---");

        // 255 * -313 = -79815
        check(8'd255, 32'shFFFFFEC7, 32'hFFFEC839,  "h2 w1=-313: 255*-313 = -79815");
        // 255 * 96 = 24480
        check(8'd255, 32'sh00000060, 32'sh00005FA0, "h2 w2=  96: 255*  96 =  24480");
        // 255 * 337 = 85935
        check(8'd255, 32'sh00000151, 32'sh00014FAF, "h2 w3= 337: 255* 337 =  85935");
        // 128 * -313 = -40064
        check(8'd128, 32'shFFFFFEC7, 32'hFFFF6380,  "h2 w1=-313: 128*-313 = -40064");
        // 128 * 96 = 12288
        check(8'd128, 32'sh00000060, 32'sh00003000, "h2 w2=  96: 128*  96 =  12288");
        // 128 * 337 = 43136
        check(8'd128, 32'sh00000151, 32'sh0000A880, "h2 w3= 337: 128* 337 =  43136");

        // --- output0: w1=51  w2=-158  w3=-129 ---
        $display("--- output0: w1=51  w2=-158  w3=-129 ---");

        // 255 * 51 = 13005
        check(8'd255, 32'sh00000033, 32'sh000032CD, "o0 w1=  51: 255*  51 =  13005");
        // 255 * -158 = -40290
        check(8'd255, 32'shFFFFFF62, 32'hFFFF629E,  "o0 w2=-158: 255*-158 = -40290");
        // 255 * -129 = -32895
        check(8'd255, 32'shFFFFFF7F, 32'hFFFF7F81,  "o0 w3=-129: 255*-129 = -32895");
        // 128 * 51 = 6528
        check(8'd128, 32'sh00000033, 32'sh00001980, "o0 w1=  51: 128*  51 =   6528");
        // 128 * -158 = -20224
        check(8'd128, 32'shFFFFFF62, 32'hFFFFB100,  "o0 w2=-158: 128*-158 = -20224");
        // 128 * -129 = -16512
        check(8'd128, 32'shFFFFFF7F, 32'hFFFFBF80,  "o0 w3=-129: 128*-129 = -16512");

        // ------------------------------------------------------------------
        // Group 4: Sign correctness sweep
        // Every pixel value (1-255) times a negative weight must be negative
        // ------------------------------------------------------------------
        $display("--- Sign correctness: negative weight must give negative product ---");
        begin : sign_check
            integer i;
            integer errors;
            errors = 0;
            in2 = 32'shFFFFFE97; // weight = -361
            for (i = 1; i <= 255; i = i + 1) begin
                in1 = i[7:0];
                #5;
                if (out >= 0) begin
                    $display("  FAIL | SIGN pixel=%0d * w=-361 -> %0d (expected negative)",
                        i, out);
                    errors = errors + 1;
                end
            end
            if (errors == 0) begin
                $display("  PASS | SIGN SWEEP w=-361 | all 255 pixel values gave negative product");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL | SIGN SWEEP w=-361 | %0d sign errors found", errors);
                fail_count = fail_count + errors;
            end
        end

        // ------------------------------------------------------------------
        // Group 5: 32-bit overflow check
        // Verify worst-case products do not overflow 32-bit signed
        // Max signed 32-bit = 2,147,483,647
        // Worst case in project: 371*255 = 94,605 — well within range
        // ------------------------------------------------------------------
        $display("--- 32-bit overflow check ---");

        // Largest positive product in network: 371 * 255 = 94605
        check(8'd255, 32'sh00000173, 32'sh0001718D, "MAX POS: 255 * 371  =  94605");

        // Largest negative product in network: -361 * 255 = -92055
        check(8'd255, 32'shFFFFFE97, 32'hFFFE9869,  "MAX NEG: 255 * -361 = -92055");

        // Verify these are nowhere near 32-bit overflow
        $display("  INFO | 32-bit signed max = 2,147,483,647");
        $display("  INFO | Worst case product =     94,605  (0.004%% of max)");
        $display("  INFO | No overflow risk with 32-bit output");

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("============================================================");
        $display("  RESULTS: %0d passed,  %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  All tests PASSED.");
        else
            $display("  WARNING: %0d test(s) FAILED.", fail_count);
        $display("============================================================");
        $finish;
    end

    initial begin #500000; $display("TIMEOUT"); $finish; end

endmodule
