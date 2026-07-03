// Reconstruct signed INT4 from two 2-bit ADC codes
// cell_hi[1:0] = upper 2 bits (MSBs), cell_lo[1:0] = lower 2 bits (LSBs)
// Output: signed 4-bit two's complement (range -8 to +7)
// IGZO 2-bit/cell: each read gives 2 bits of one weight nibble
// A single weight (INT4) is split across 2 cell reads: {hi[1:0], lo[1:0]}
module int4_rebuild (
    input  wire [1:0] cell_hi,   // MSBs from first read
    input  wire [1:0] cell_lo,   // LSBs from second read
    output wire [3:0] w4_signed  // signed INT4, two's complement
);
    assign w4_signed = {cell_hi, cell_lo};
endmodule
