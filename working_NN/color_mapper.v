// color_mapper.v
//
// Synthesizable color mapper matching the block diagram:
//   "Block Diagram for Neural Network" (FPGA Vision / NN_RGB_FPGA project)
//
// Architecture (from diagram):
//   - 3 hidden neurons, each with bias + 3 weights (R, G, B inputs)
//   - 1 output neuron, with bias + 3 weights (hidden layer outputs)
//   - Color mapping: if output >= 0.5  --> white pixel (255,255,255)
//                   else               --> black pixel (0,0,0)
//
// In fixed-point hardware the sigmoid output is scaled to [0,255],
// so 0.5 maps to 127.  Matches FPGA_plain/nn_rgb.vhd exactly:
//   if (output > 127) result <= all-ones  else result <= all-zeros
//
// Latency: 1 clock cycle (registered outputs).
//
// -----------------------------------------------------------------------
// Ports
// -----------------------------------------------------------------------
//   CLK          - pixel clock
//   RST          - active-low asynchronous reset
//   nn_out[7:0]  - single NN output neuron, sigmoid scaled [0,255]
//   r_out        - 8-bit red   output (255 or 0)
//   g_out        - 8-bit green output (255 or 0)
//   b_out        - 8-bit blue  output (255 or 0)
// -----------------------------------------------------------------------

module color_mapper (
    input  wire       CLK,
    input  wire       RST,

    // Single neural-network output neuron (sigmoid scaled 0-255)
    input  wire [7:0] nn_out,

    // Mapped RGB output pixel
    output reg  [7:0] r_out,
    output reg  [7:0] g_out,
    output reg  [7:0] b_out
);

    // ------------------------------------------------------------------
    // Decision: output > 127 means sigmoid > ~0.5  → white
    //           output ≤ 127                        → black
    // Matches FPGA_plain/nn_rgb.vhd threshold exactly.
    // ------------------------------------------------------------------
    wire white;
    assign white = (nn_out > 8'd127);

    // ------------------------------------------------------------------
    // Output register - 1 cycle latency, asynchronous active-low reset
    // ------------------------------------------------------------------
    always @(posedge CLK or negedge RST) begin
        if (!RST) begin
            r_out <= 8'h00;
            g_out <= 8'h00;
            b_out <= 8'h00;
        end else begin
            r_out <= white ? 8'hFF : 8'h00;
            g_out <= white ? 8'hFF : 8'h00;
            b_out <= white ? 8'hFF : 8'h00;
        end
    end

endmodule