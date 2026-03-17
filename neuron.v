// =============================================================================
// neuron.v
// ASIC RTL Implementation of a Single Neuron
//
// Translated from neuron.vhd (FPGA Vision Remote Lab, H-BRS)
// Target: ASIC synthesis (Cadence Xcelium / Genus)
//
// Architecture (matches block diagram):
//   Stage 1: NUM_INPUTS parallel signed multipliers  (8b input x 8b weight)
//   Stage 2: Registered adder tree + bias accumulation
//   Stage 3: Saturating clamp -> 12-bit sigmoid ROM address
//   Stage 4: Registered sigmoid ROM lookup (replaces FPGA sigmoid_IP)
//   Output : 8-bit unsigned neuron activation
//
// Key ASIC changes vs FPGA original:
//   - sigmoid_IP Altera/Xilinx ROM replaced with standard Verilog ROM
//   - No use of work.CONFIG package generics; parameters used instead
//   - All memories use synchronous read (standard-cell friendly)
//   - No FPGA-specific attributes or primitives
//   - Explicit signed arithmetic throughout
//   - Reset added to all registers (required for ASIC scan insertion)
// =============================================================================

// -----------------------------------------------------------------------------
// Sub-module: multiplier
//   Computes: output_val = input_val * WEIGHT  (signed x signed)
//   Registered output (one pipeline stage)
//   Input  : 8-bit signed
//   Weight : 8-bit signed parameter
//   Output : 16-bit signed (full precision, no truncation before accumulation)
// -----------------------------------------------------------------------------
module multiplier #(
    parameter signed [7:0] WEIGHT = 8'sh01
)(
    input  wire              clk,
    input  wire              rst_n,          // active-low synchronous reset
    input  wire signed [7:0] input_val,
    output reg  signed [15:0] output_val
);
    always @(posedge clk) begin
        if (!rst_n)
            output_val <= 16'sh0000;
        else
            output_val <= input_val * WEIGHT; // synthesizes to 8x8 signed multiplier cell
    end
endmodule


// -----------------------------------------------------------------------------
// Sub-module: sigmoid_ROM
//   Replaces Altera/Xilinx sigmoid_IP for ASIC.
//   Pre-computed sigmoid LUT: 4096 entries x 8-bit output.
//
//   Address mapping (matches VHDL sumAdress[15:4]):
//     ROM address = (sum + 32768) >> 4  =>  12-bit index into 4096 entries
//     Entry 0    -> sigmoid(-8)  ~  0
//     Entry 2048 -> sigmoid( 0)  = 128
//     Entry 4095 -> sigmoid(+8)  ~ 255
//
//   For ASIC synthesis: this elaborates as a standard synchronous ROM.
//   The synthesis tool (Genus) will map it to a standard-cell ROM or SRAM macro.
//   For tape-out, replace $rtoi/$exp with a pre-generated $readmemh file.
// -----------------------------------------------------------------------------
module sigmoid_ROM (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] address,
    output reg  [ 7:0] q
);
    // 4096 x 8-bit ROM
    reg [7:0] mem [0:4095];

    integer idx;
    real    x, sig_val;

    // ROM initialization — replace with $readmemh("sigmoid_lut.hex", mem)
    // for actual synthesis/LVS flow
    initial begin
        for (idx = 0; idx < 4096; idx = idx + 1) begin
            x       = (idx - 2048.0) / 256.0;          // map to [-8, +8)
            sig_val = 1.0 / (1.0 + $exp(-x));          // sigmoid(x)
            mem[idx] = $rtoi(sig_val * 255.0 + 0.5);   // scale to [0,255]
        end
    end

    // Synchronous read — ASIC standard-cell ROM friendly
    always @(posedge clk) begin
        if (!rst_n)
            q <= 8'h00;
        else
            q <= mem[address];
    end
endmodule


// -----------------------------------------------------------------------------
// Top-level: neuron
//
// Parameters:
//   NUM_INPUTS : number of input signals (e.g. 3, matches block diagram)
//   BIAS       : signed 8-bit bias weight (theta_0)
//   W1,W2,W3   : signed 8-bit input weights (theta_1..theta_N)
//                Extend W4..WN for more inputs.
//
// Pipeline depth: 3 clock cycles (mult -> accumulate -> sigmoid ROM)
//
// Ports:
//   clk        : system clock
//   rst_n      : active-low synchronous reset
//   inputs     : NUM_INPUTS x 8-bit signed packed bus
//   output_val : 8-bit unsigned neuron output
// -----------------------------------------------------------------------------
module neuron #(
    parameter NUM_INPUTS = 3,

    // Weights (signed 8-bit). Index 0 = bias, 1..N = input weights
    // Example values — override at instantiation for trained network
    parameter signed [7:0] BIAS = 8'sh01,
    parameter signed [7:0] W1   = 8'sh01,
    parameter signed [7:0] W2   = 8'sh01,
    parameter signed [7:0] W3   = 8'sh01
)(
    input  wire                        clk,
    input  wire                        rst_n,
    input  wire signed [NUM_INPUTS*8-1:0] inputs,   // packed: {x3,x2,x1}
    output wire [7:0]                  output_val
);

    // -------------------------------------------------------------------------
    // Internal signals
    // -------------------------------------------------------------------------

    // Slice individual 8-bit inputs from packed bus
    wire signed [7:0] x [0:NUM_INPUTS-1];
    genvar gi;
    generate
        for (gi = 0; gi < NUM_INPUTS; gi = gi + 1) begin : input_slice
            assign x[gi] = inputs[gi*8 +: 8];
        end
    endgenerate

    // Stage 1: multiplier outputs (16-bit signed per input)
    wire signed [15:0] products [0:NUM_INPUTS-1];

    // Stage 2: accumulator signals
    // Max sum range: NUM_INPUTS * (127*127) + bias*127
    // 16-bit products * NUM_INPUTS -> use 32-bit accumulator for safety
    reg signed [31:0] sum_reg;          // registered accumulated sum + bias
    reg signed [31:0] sum_comb;         // combinational accumulation

    // Stage 3: clamp and address
    reg [15:0] sum_address_full;        // 16-bit clamped address (matches VHDL)
    wire [11:0] sigmoid_address;        // top 12 bits -> ROM address

    // Stage 4: sigmoid ROM output (registered inside sigmoid_ROM)
    wire [7:0]  after_activation;

    // -------------------------------------------------------------------------
    // Stage 1: Instantiate one multiplier per input
    // Matches VHDL generate loop: mult[i] = input[i] * weight[i]
    // -------------------------------------------------------------------------
    generate
        // Multiplier for input 0 (x1 in block diagram)
        multiplier #(.WEIGHT(W1)) mult0 (
            .clk        (clk),
            .rst_n      (rst_n),
            .input_val  (x[0]),
            .output_val (products[0])
        );

        // Multiplier for input 1 (x2 in block diagram)
        multiplier #(.WEIGHT(W2)) mult1 (
            .clk        (clk),
            .rst_n      (rst_n),
            .input_val  (x[1]),
            .output_val (products[1])
        );

        // Multiplier for input 2 (x3 in block diagram)
        multiplier #(.WEIGHT(W3)) mult2 (
            .clk        (clk),
            .rst_n      (rst_n),
            .input_val  (x[2]),
            .output_val (products[2])
        );
    endgenerate

    // -------------------------------------------------------------------------
    // Stage 2: Accumulate products + bias (registered)
    // Matches VHDL process: sum = sum(accumulate) + weightsIn(bias)
    // -------------------------------------------------------------------------
    integer i;
    always @(*) begin : accumulate_comb
        sum_comb = {{24{BIAS[7]}}, BIAS};   // sign-extend bias to 32 bits
        for (i = 0; i < NUM_INPUTS; i = i + 1)
            sum_comb = sum_comb + {{16{products[i][15]}}, products[i]};
    end

    always @(posedge clk) begin : accumulate_reg
        if (!rst_n)
            sum_reg <= 32'sh0;
        else
            sum_reg <= sum_comb;
    end

    // -------------------------------------------------------------------------
    // Stage 3: Saturating clamp to 16-bit signed range, then offset by +32768
    // Matches VHDL:
    //   if sum < -32768 -> address = 0x0000
    //   if sum >  32767 -> address = 0xFFFF
    //   else            -> address = sum + 32768
    // sigmoid_address = address[15:4] (top 12 bits -> 4096 ROM entries)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin : clamp_reg
        if (!rst_n) begin
            sum_address_full <= 16'h0000;
        end else begin
            if (sum_reg < -32768)
                sum_address_full <= 16'h0000;
            else if (sum_reg > 32767)
                sum_address_full <= 16'hFFFF;
            else
                sum_address_full <= sum_reg[15:0] + 16'd32768;
        end
    end

    assign sigmoid_address = sum_address_full[15:4]; // 12-bit ROM index

    // -------------------------------------------------------------------------
    // Stage 4: Sigmoid ROM lookup
    // Replaces FPGA sigmoid_IP — standard synchronous ROM for ASIC
    // -------------------------------------------------------------------------
    sigmoid_ROM sigmoid_lut (
        .clk     (clk),
        .rst_n   (rst_n),
        .address (sigmoid_address),
        .q       (after_activation)
    );

    // -------------------------------------------------------------------------
    // Output assignment
    // Matches VHDL: output <= to_integer(unsigned(afterActivation))
    // -------------------------------------------------------------------------
    assign output_val = after_activation;

endmodule
