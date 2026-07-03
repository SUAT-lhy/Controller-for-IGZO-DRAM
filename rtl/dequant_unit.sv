module dequant_unit (
    input  wire [3:0]  w4_in,
    input  wire [7:0]  scale,
    input  wire [1:0]  mode,
    output reg  [7:0]  w8_out
);
    reg [7:0]  w4_sext;
    reg [15:0] tmp_prod;
    always @(*) begin
        w4_sext = {{4{w4_in[3]}}, w4_in};
        if (mode == 2'b10) begin
            w8_out = w4_sext;
        end else begin
            tmp_prod = (w4_sext) * ({1'b0, scale});
            if ((tmp_prod) > 16'sd127)
                w8_out = 8'd127;
            else if ((tmp_prod) < -16'sd128)
                w8_out = 8'hFF;
            else
                w8_out = tmp_prod[7:0];
        end
    end
endmodule
