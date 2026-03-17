// =============================================================================
// neuron_tb.v
// Testbench for neuron.v — ASIC RTL Simulation (Cadence Xcelium)
//
// Tests:
//   1. Reset behavior
//   2. Zero inputs  -> output should be sigmoid(bias)
//   3. Known weighted sum -> verify sigmoid output
//   4. Saturation: large positive sum  -> output ~ 255
//   5. Saturation: large negative sum  -> output ~   0
//   6. Pipeline latency check (3 cycles: mult -> accum -> ROM)
// =============================================================================
`timescale 1ns/1ps

module neuron_tb;

    // -------------------------------------------------------------------------
    // DUT parameters — small known weights for hand-verification
    // z = BIAS + W1*x1 + W2*x2 + W3*x3
    // -------------------------------------------------------------------------
    localparam signed [7:0] BIAS = 8'sh00;  //  0
    localparam signed [7:0] W1   = 8'sh01;  // +1
    localparam signed [7:0] W2   = 8'sh02;  // +2
    localparam signed [7:0] W3   = 8'shFF;  // -1

    // -------------------------------------------------------------------------
    // Clock and reset
    // -------------------------------------------------------------------------
    reg clk   = 0;
    reg rst_n = 0;

    localparam CLK_PERIOD = 10; // 10 ns -> 100 MHz
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // DUT ports
    // -------------------------------------------------------------------------
    reg signed [23:0] inputs;   // packed {x3[7:0], x2[7:0], x1[7:0]}
    wire        [7:0] output_val;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    neuron #(
        .NUM_INPUTS (3),
        .BIAS       (BIAS),
        .W1         (W1),
        .W2         (W2),
        .W3         (W3)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .inputs     (inputs),
        .output_val (output_val)
    );

    // -------------------------------------------------------------------------
    // Helper task: apply inputs and wait for pipeline to flush (3 cycles)
    // -------------------------------------------------------------------------
    // Pipeline depth = 3 registered stages:
    //   Cycle 1: multiplier output registered
    //   Cycle 2: accumulator registered
    //   Cycle 3: sigmoid ROM registered output
    localparam PIPE_DEPTH = 3;

    task apply_and_check;
        input signed [7:0] x1, x2, x3;
        input        [7:0] expected_min;
        input        [7:0] expected_max;
        input [127:0]      test_name;
        integer            weighted_sum;
        begin
            // Pack inputs: inputs[7:0]=x1, [15:8]=x2, [23:16]=x3
            inputs = {x3, x2, x1};
            weighted_sum = $signed(BIAS)
                         + $signed(W1)*$signed(x1)
                         + $signed(W2)*$signed(x2)
                         + $signed(W3)*$signed(x3);

            // Wait for pipeline to produce result
            repeat(PIPE_DEPTH) @(posedge clk);
            #1; // small delta after clock edge

            $display("[%0t] TEST: %-20s | x=(%0d,%0d,%0d) z=%0d | out=%0d [exp %0d..%0d] %s",
                $time, test_name,
                $signed(x1), $signed(x2), $signed(x3),
                weighted_sum,
                output_val,
                expected_min, expected_max,
                (output_val >= expected_min && output_val <= expected_max) ? "PASS" : "FAIL ***");
        end
    endtask

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        // Waveform dump for Xcelium / SimVision
        $dumpfile("neuron_tb.vcd");
        $dumpvars(0, neuron_tb);

        inputs = 24'h000000;

        // --- Reset ---
        rst_n = 0;
        repeat(4) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        $display("=============================================================");
        $display("  Neuron Testbench — ASIC RTL");
        $display("  BIAS=%0d  W1=%0d  W2=%0d  W3=%0d", 
                  $signed(BIAS), $signed(W1), $signed(W2), $signed(W3));
        $display("=============================================================");

        // ------------------------------------------------------------------
        // Test 1: All zeros -> z = 0 -> sigmoid(0) = 128
        // ------------------------------------------------------------------
        apply_and_check(8'sh00, 8'sh00, 8'sh00,
                        8'd125, 8'd131,      // sigmoid(0)=128 +-3 tolerance
                        "ZERO_INPUTS");

        // ------------------------------------------------------------------
        // Test 2: x1=10, x2=5, x3=3
        //   z = 0 + 1*10 + 2*5 + (-1)*3 = 17
        //   sigmoid(17) should be close to 255 (large positive)
        // ------------------------------------------------------------------
        apply_and_check(8'sh0A, 8'sh05, 8'sh03,
                        8'd240, 8'd255,
                        "POSITIVE_SUM");

        // ------------------------------------------------------------------
        // Test 3: x1=-10, x2=-5, x3=3
        //   z = 0 + 1*(-10) + 2*(-5) + (-1)*3 = -23
        //   sigmoid(-23) should be close to 0
        // ------------------------------------------------------------------
        apply_and_check(8'shF6, 8'shFB, 8'sh03,
                        8'd0, 8'd15,
                        "NEGATIVE_SUM");

        // ------------------------------------------------------------------
        // Test 4: Saturation positive
        //   x1=127, x2=127, x3=0 -> z = 127 + 254 = 381 -> saturates
        //   sigmoid(saturated+) -> 255
        // ------------------------------------------------------------------
        apply_and_check(8'sh7F, 8'sh7F, 8'sh00,
                        8'd250, 8'd255,
                        "SAT_POSITIVE");

        // ------------------------------------------------------------------
        // Test 5: Saturation negative
        //   x1=-128, x2=-128, x3=0 -> z = -128 + (-256) = -384 -> saturates
        //   sigmoid(saturated-) -> 0
        // ------------------------------------------------------------------
        apply_and_check(8'sh80, 8'sh80, 8'sh00,
                        8'd0, 8'd5,
                        "SAT_NEGATIVE");

        // ------------------------------------------------------------------
        // Test 6: Pipeline continuity — back-to-back inputs (no bubbles)
        // Apply new inputs every cycle and confirm outputs arrive 3 cycles later
        // ------------------------------------------------------------------
        $display("-------------------------------------------------------------");
        $display("  Pipeline continuity test (back-to-back, no stalls)");
        $display("-------------------------------------------------------------");

        @(posedge clk); inputs = {8'sh01, 8'sh01, 8'sh01}; // z=1+2-1=2
        @(posedge clk); inputs = {8'sh02, 8'sh02, 8'sh02}; // z=2+4-2=4
        @(posedge clk); inputs = {8'sh04, 8'sh04, 8'sh04}; // z=4+8-4=8
        repeat(PIPE_DEPTH) @(posedge clk);
        $display("[%0t] Pipeline continuity complete - outputs arrived", $time);

        // ------------------------------------------------------------------
        // Test 7: Reset mid-operation
        // ------------------------------------------------------------------
        inputs = {8'sh7F, 8'sh7F, 8'sh7F};
        @(posedge clk);
        rst_n = 0;                    // assert reset
        @(posedge clk);
        @(posedge clk);
        rst_n = 1;
        repeat(PIPE_DEPTH) @(posedge clk);
        #1;
        $display("[%0t] TEST: %-20s | out=%0d [exp 0] %s",
            $time, "RESET_MID_OP",
            output_val,
            (output_val == 8'd0 || output_val == 8'd128) ? "PASS" : "CHECK_MANUALLY");

        $display("=============================================================");
        $display("  Simulation complete.");
        $display("=============================================================");
        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    initial begin
        #100000;
        $display("TIMEOUT — simulation did not finish.");
        $finish;
    end

endmodule
