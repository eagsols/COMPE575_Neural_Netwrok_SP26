// =============================================================================
// multiplier.v
// Submodule: Signed Multiplier (Weight x Pixel Input)
//
// Computes: out = in1 * in2  (combinational)
//
// Port widths:
//   WIN1 = 8  : in1 is 8-bit unsigned pixel input (0-255)
//   WIN2 = 32 : in2 is 32-bit signed weight
//   WOUT = 32 : out is 32-bit signed product
//
// Why 32-bit output is sufficient:
//   Worst case positive: 371  * 255 =  94,605  -> fits in 32-bit signed
//   Worst case negative: -361 * 255 = -92,055  -> fits in 32-bit signed
//   32-bit signed max  : 2,147,483,647
//   32-bit signed min  : -2,147,483,648
//
// Note on in1 sign handling:
//   in1 is declared unsigned. Since pixel values are always 0-255
//   (never negative), we zero-extend in1 to 9-bit signed before
//   multiplying to ensure correct signed arithmetic with negative weights.
//
// ASIC notes:
//   - Combinational module (no clock) — register sits in adder stage
//   - 3 instances instantiated per neuron (one per input x1/x2/x3)
//   - Synthesizes to a standard signed multiplier cell
// =============================================================================
module multiplier #(
    parameter WIN1 = 8,
    parameter WIN2 = 32,
    parameter WOUT = 32       // fixed at 32-bit — sufficient for all weights
)(
    input  wire              [WIN1-1:0] in1,   // 8-bit unsigned pixel (0-255)
    input  wire signed       [WIN2-1:0] in2,   // 32-bit signed weight
    output reg  signed       [WOUT-1:0] out    // 32-bit signed product
);

    // Zero-extend in1 to 9-bit signed so 255 stays positive
    // when multiplied against a negative weight
    wire signed [8:0] in1_signed = {1'b0, in1};

    always @(*) begin
        out = in1_signed * in2;
    end

endmodule
