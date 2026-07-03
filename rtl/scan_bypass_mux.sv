// DFT scan bypass mux
module scan_bypass_mux #(parameter W=8) (
    input  wire        scan_en,
    input  wire [W-1:0] scan_in,
    input  wire [W-1:0] func_in,
    output wire [W-1:0] out
);
    assign out = scan_en ? scan_in : func_in;
endmodule
