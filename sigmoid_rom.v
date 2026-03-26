// =============================================================================
// sigmoid_rom.v
// Submodule: Sigmoid Activation Function — Synchronous ROM LUT
//
// Replaces the FPGA sigmoid_IP block for ASIC.
// Contains its own synchronous read register (the ROM output is registered
// on posedge clk), matching the sigmoid_IP behavior in neuron__1_.vhd.
// No external register.v instance is needed after this block.
//
// ROM size: 16384 entries x 8-bit output (14-bit address)
// Matches neuron__1_.vhd: address => sumAdress(15 downto 2)
//
// Address mapping:
//   Entry 0     -> sigmoid(-8)  ~   0   (fully inactive neuron)
//   Entry 8192  -> sigmoid( 0)  = 128   (midpoint)
//   Entry 16383 -> sigmoid(+8)  ~ 255   (fully active neuron)
//
// Port widths:
//   address : 14-bit unsigned — from sat_clamp (via register.v)
//   q       : 8-bit  unsigned — neuron activation output (0-255)
//
// ASIC synthesis notes:
//   - $exp / $rtoi initial block is SIMULATION ONLY
//   - For synthesis: replace with $readmemh("sigmoid_lut.hex", mem)
//     and provide the pre-generated hex file to Cadence Genus
//   - Synchronous read maps to standard-cell ROM or foundry SRAM macro
//   - Active-low synchronous reset for DFT scan insertion
// =============================================================================
module sigmoid_rom (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [13:0] address,
    output reg  [ 7:0] q
);

    reg [7:0] mem [0:16383];

    integer idx;
    real    x, sig_val;

    // -------------------------------------------------------------------------
    // ROM initialization
    // SIMULATION: uses $exp for behavioral accuracy
    // SYNTHESIS:  comment out loop, uncomment $readmemh line below
    // -------------------------------------------------------------------------
    initial begin
        // $readmemh("sigmoid_lut.hex", mem);  // <-- use for synthesis
        for (idx = 0; idx < 16384; idx = idx + 1) begin
            x        = (idx - 8192.0) / 1024.0;
            sig_val  = 1.0 / (1.0 + $exp(-x));
            mem[idx] = $rtoi(sig_val * 255.0 + 0.5);
        end
    end

    // Synchronous read — standard-cell ROM inference
    always @(posedge clk) begin
        if (!rst_n)
            q <= 8'h00;
        else
            q <= mem[address];
    end

endmodule
