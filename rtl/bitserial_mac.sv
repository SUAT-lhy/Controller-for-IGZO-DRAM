// W8xA8 signed parallel-multiply MAC, row-by-row accumulation
module bitserial_mac (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire signed [7:0] w8,
    input  wire signed [7:0] a8,
    output reg         done,
    output reg         acc_en,
    output reg  signed [25:0] product_shifted
);
    reg active;
    reg signed [15:0] full_product;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active<=0; done<=0; acc_en<=0;
            product_shifted<=0; full_product<=0;
        end else begin
            acc_en<=0; done<=0;
            if (start) begin
                full_product <= (w8) * (a8);
                active <= 1;
            end else if (active) begin
                product_shifted <= {{10{full_product[15]}}, full_product};
                acc_en  <= 1;
                done    <= 1;
                active  <= 0;
            end
        end
    end
endmodule
