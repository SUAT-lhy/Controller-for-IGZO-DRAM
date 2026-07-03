// 26-bit signed accumulator
module accum26 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire        acc_en,
    input  wire [15:0] product,
    output reg  [25:0] acc_out,
    output reg         overflow
);
    wire [26:0] acc_ext  = {acc_out[25], acc_out};
    wire [26:0] prod_ext = {{11{product[15]}}, product};
    wire [26:0] sum27    = acc_ext + prod_ext;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin acc_out <= 26'd0; overflow <= 1'b0; end
        else if (start) begin acc_out <= 26'd0; overflow <= 1'b0; end
        else if (acc_en) begin
            if (sum27[26] != sum27[25]) overflow <= 1'b1;
            acc_out <= sum27[25:0];
        end
    end
endmodule
