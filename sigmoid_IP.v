// sigmoid_IP.v
// Converted from sigmoid_IP.vhd
// FPGA Vision Remote Lab - H-BRS
//
// Synchronous ROM: 14-bit address -> 8-bit sigmoid output.
// In synthesis: replace the placeholder logic with a proper
// ROM initialized from sigmoid_12_bit.mif (use $readmemh with a .hex file).
//
// The original VHDL uses a placeholder mapping addr_reg[13:6] -> q.
// This conversion keeps the same placeholder for behavioral equivalence.
// For real use, uncomment the $readmemh block below.
 
module sigmoid_IP (
    input  wire [13:0] address,
    input  wire        clock,
    output reg  [7:0]  q
);
 
    reg [7:0] rom [0:16383];   // 2^14 = 16384 entries
 
    initial begin
        $readmemh("sigmoid_12_bit.hex", rom);
    end
 
    always @(posedge clock) begin
        q <= rom[address];
    end
 
endmodule