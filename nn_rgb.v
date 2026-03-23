// nn_rgb.v
// Converted from nn_rgb.vhd
// FPGA Vision Remote Lab - Thomas Florkowski / Marco Winzker, H-BRS
//
// Top-level: Neural Network for RGB Traffic Sign Color Detection
// 3 hidden neurons + 1 output neuron, all weights are exact from original VHDL.
 
module nn_rgb (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [2:0]  enable_in,       // three slide switches
    // video in
    input  wire        vs_in,
    input  wire        hs_in,
    input  wire        de_in,
    input  wire [7:0]  r_in,
    input  wire [7:0]  g_in,
    input  wire [7:0]  b_in,
    // video out
    output reg         vs_out,
    output reg         hs_out,
    output reg         de_out,
    output reg  [7:0]  r_out,
    output reg  [7:0]  g_out,
    output reg  [7:0]  b_out,
    output wire        clk_o,
    output wire [2:0]  led
);
 
    // ---------- Input flip-flops ----------
    reg         reset;
    reg  [2:0]  enable;
    reg         vs_0, hs_0, de_0;
    reg  signed [31:0] r_0, g_0, b_0;
 
    // ---------- Neuron outputs (integer 0..255) ----------
    wire signed [31:0] h_0, h_1, h_2, output_val;
 
    // ---------- Control / sync pipeline ----------
    wire        vs_1, hs_1, de_1;
    reg  [7:0]  result;
 
    // =========================================================
    // Input flip-flops  (Process 1)
    // =========================================================
    always @(posedge clk) begin
        reset  <= ~reset_n;
        enable <= enable_in;
        vs_0   <= vs_in;
        hs_0   <= hs_in;
        de_0   <= de_in;
        r_0    <= {24'b0, r_in};        // unsigned 8-bit -> integer
        g_0    <= {24'b0, g_in};
        b_0    <= {24'b0, b_in};
    end
 
    // =========================================================
    // Hidden layer - exact weights from original VHDL
    // =========================================================
    neuron #(.W1(29),   .W2(-45),  .W3(-87),  .BIAS(-18227)) hidden0 (
        .clk        (clk),
        .x1         (r_0), .x2 (g_0), .x3 (b_0),
        .output_val (h_0)
    );
 
    neuron #(.W1(-361), .W2(126),  .W3(371),  .BIAS(2845))   hidden1 (
        .clk        (clk),
        .x1         (r_0), .x2 (g_0), .x3 (b_0),
        .output_val (h_1)
    );
 
    neuron #(.W1(-313), .W2(96),   .W3(337),  .BIAS(4513))   hidden2 (
        .clk        (clk),
        .x1         (r_0), .x2 (g_0), .x3 (b_0),
        .output_val (h_2)
    );
 
    // =========================================================
    // Output neuron
    // =========================================================
    neuron #(.W1(51),   .W2(-158), .W3(-129), .BIAS(41760))  output0 (
        .clk        (clk),
        .x1         (h_0), .x2 (h_1), .x3 (h_2),
        .output_val (output_val)
    );
 
    // =========================================================
    // Control: sync delay line (delay = 9 cycles, same as VHDL)
    // =========================================================
    control #(.DELAY(9)) u_control (
        .clk    (clk),
        .reset  (reset),
        .vs_in  (vs_0),  .hs_in (hs_0),  .de_in (de_0),
        .vs_out (vs_1),  .hs_out(hs_1),  .de_out(de_1)
    );
 
    // =========================================================
    // Output flip-flops  (Process 2)
    // Threshold at 127: >127 -> white (0xFF), else black (0x00)
    // =========================================================
    always @(posedge clk) begin
        if (output_val > 127)
            result <= 8'hFF;
        else
            result <= 8'h00;
 
        vs_out <= vs_1;
        hs_out <= hs_1;
        de_out <= de_1;
        r_out  <= result;
        g_out  <= result;
        b_out  <= result;
    end
 
    // Pass-through / unused
    assign clk_o = clk;
    assign led   = 3'b000;
 
endmodule