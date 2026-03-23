// neuron.v
// Converted from neuron.vhd
// FPGA Vision Remote Lab - Thomas Florkowski / Marco Winzker, H-BRS
//
// One neuron: computes weighted sum + bias, maps to sigmoid ROM address,
// and outputs the 8-bit sigmoid result as an integer.
 
module neuron #(
    parameter signed [31:0] W1   = 0,
    parameter signed [31:0] W2   = 0,
    parameter signed [31:0] W3   = 0,
    parameter signed [31:0] BIAS = 0
)(
    input  wire        clk,
    input  wire signed [31:0] x1,
    input  wire signed [31:0] x2,
    input  wire signed [31:0] x3,
    output wire signed [31:0] output_val   // named output_val to avoid 'output' keyword clash
);
 
    // Internal signals
    reg  signed [31:0] sum;
    reg  [15:0]        sumAddress;
    wire [7:0]         afterActivation;
 
    // Stage 1: compute weighted sum (registered)
    always @(posedge clk) begin
        sum <= (W1 * x1) + (W2 * x2) + (W3 * x3) + BIAS;
    end
 
    // Stage 2: address clipping  (sum + 32768 mapped to 16-bit unsigned)
    always @(posedge clk) begin
        if (sum < -32768)
            sumAddress <= 16'h0000;
        else if (sum > 32767)
            sumAddress <= 16'hFFFF;
        else
            sumAddress <= sum[15:0] + 16'd32768;
    end
 
    // Sigmoid ROM - uses upper 14 bits of address (bits [15:2])
    sigmoid_IP sigmoid (
        .clock   (clk),
        .address (sumAddress[15:2]),
        .q       (afterActivation)
    );
 
    // Format conversion: std_logic_vector -> integer (unsigned)
    assign output_val = {24'b0, afterActivation};   // zero-extend to 32-bit integer
 
endmodule
 