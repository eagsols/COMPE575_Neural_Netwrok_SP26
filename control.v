`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// control.v
// Converted from control.vhd (sharp_control)
// FPGA Vision Remote Lab - Marco Winzker, H-BRS
//
// Simple shift-register delay line for vs, hs, de sync signals.
// Generic 'delay' sets the number of pipeline stages.
// In nn_rgb the delay is set to 9.
 
module control #(
    parameter DELAY = 7
)(
    input  wire clk,
    input  wire reset,
    input  wire vs_in,
    input  wire hs_in,
    input  wire de_in,
    output wire vs_out,
    output wire hs_out,
    output wire de_out
);
 
    // Shift-register arrays (1-indexed in VHDL -> index 0..DELAY-1 here)
    reg [DELAY-1:0] vs_delay;
    reg [DELAY-1:0] hs_delay;
    reg [DELAY-1:0] de_delay;
 
    always @(posedge clk) begin
        // First stage takes current input
        vs_delay[0] <= vs_in;
        hs_delay[0] <= hs_in;
        de_delay[0] <= de_in;
        // Remaining stages shift previous value
        if (DELAY > 1) begin : gen_delay
            integer i;
            for (i = 1; i < DELAY; i = i + 1) begin
                vs_delay[i] <= vs_delay[i-1];
                hs_delay[i] <= hs_delay[i-1];
                de_delay[i] <= de_delay[i-1];
            end
        end
    end
 
    // Output is the last stage
    assign vs_out = vs_delay[DELAY-1];
    assign hs_out = hs_delay[DELAY-1];
    assign de_out = de_delay[DELAY-1];
 
endmodule
