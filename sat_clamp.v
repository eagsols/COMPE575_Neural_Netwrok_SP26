// =============================================================================
// sat_clamp.v
// Submodule: Saturating Clamp + ROM Address Generator
//
// Purely COMBINATIONAL — no clock, no register.
// The register stage is handled by the separate register.v module.
//
// Translates the registered process from neuron__1_.vhd into combinational
// logic. The sat_clamp and adder share one register stage in the VHDL
// (both computed inside the same rising_edge process).
//
// Operation:
//   if   sum_in < -32768  ->  addr_out = 14'h0000   (saturate low)
//   elif sum_in >  32767  ->  addr_out = 14'h3FFF   (saturate high)
//   else                  ->  addr_out = (sum_in + 32768) >> 2
//
// The +32768 offset maps signed [-32768..+32767] to unsigned [0..65535].
// Right-shift by 2 selects bits [15:2], giving a 14-bit address for the
// 16384-entry sigmoid ROM (matches neuron__1_.vhd: sumAdress(15 downto 2)).
//
// Port widths:
//   sum_in   : 32-bit signed  (from adder output)
//   addr_out : 14-bit unsigned (sigmoid ROM address, 0..16383)
//
// ASIC notes:
//   - Synthesizes to a comparator + mux + adder + shift
//   - No flip-flops — register.v provides the pipeline register
// =============================================================================
module sat_clamp (
    input  wire signed [31:0] sum_in,
    output reg         [13:0] addr_out
);

    always @(*) begin
        if (sum_in < -32'sd32768)
            addr_out = 14'h0000;
        else if (sum_in > 32'sd32767)
            addr_out = 14'h3FFF;
        else
            addr_out = (sum_in[15:0] + 16'd32768) >> 2;
    end

endmodule
